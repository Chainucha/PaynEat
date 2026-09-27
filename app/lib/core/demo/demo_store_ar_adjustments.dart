// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------ AR adjustments + e-mail -----
/// ดอกเบี้ยผิดนัด + ใบลดหนี้ + ส่งเอกสารทางอีเมล — mirror ของ backend late-fee.service.js,
/// credit-note.service.js และ receivable.documents.js (ดู docs/tickets/21-late-fees-credit-notes.md,
/// docs/tickets/23-document-pdf-email.md, docs/DECISIONS.md #55–#57)
///
/// โหมดสาธิตไม่มีเซิร์ฟเวอร์อีเมล การ "ส่ง" จึงเป็นการจำลอง: ตรวจกติกาเดียวกันทุกข้อ (เอกสารยกเลิก
/// ส่งไม่ได้ ต้องมีอีเมลผู้รับ) แล้วบันทึกประวัติ + audit log เหมือนส่งจริง แต่ไม่มีอีเมลออกไปไหน
extension DemoStoreArAdjustments on DemoStore {
  Iterable<Map<String, dynamic>> _activeChargeItems(int paymentId) => arCharges
      .where((charge) => charge['isVoided'] != true)
      .expand(
        (charge) => (charge['items'] as List).cast<Map<String, dynamic>>(),
      )
      .where((item) => item['paymentId'] == paymentId);

  /// ดอกเบี้ยที่คิดเพิ่มในบิลนี้แล้ว (ใบที่ยกเลิกไม่นับ)
  double _chargedOf(int paymentId) => _activeChargeItems(
    paymentId,
  ).fold<double>(0, (sum, item) => sum + (item['amount'] as num));

  /// วันสุดท้ายที่คิดดอกเบี้ยไปแล้ว — รอบถัดไปเริ่มนับวันถัดจากนี้
  String? _interestThroughOf(int paymentId) {
    String? latest;
    for (final item in _activeChargeItems(paymentId)) {
      final to = item['periodTo'] as String;
      if (latest == null || to.compareTo(latest) > 0) latest = to;
    }
    return latest;
  }

  String _addDays(String isoDay, int days) =>
      _isoDay(DateTime.parse(isoDay).add(Duration(days: days)));

  /// ดอกเบี้ยของบิลเดียว (mirror ของ late-fee.service.js#lineFor) — ดอกเบี้ยธรรมดาจากเงินต้นที่ยังค้าง
  /// เงินที่ลูกค้าจ่ายตัดดอกเบี้ยก่อน เงินต้นค้าง = min(ยอดบิลหลังลดหนี้, ยอดค้างทั้งหมด)
  Map<String, dynamic>? _lateFeeLine(
    Map<String, dynamic> row, {
    required double annualRate,
    required int graceDays,
    required String asOf,
  }) {
    final outstanding = row['outstanding'] as double;
    final dueDate = row['dueDate'] as String?;
    if (outstanding <= 0.001 || dueDate == null) return null;
    final principal = DemoStorePayments._roundMoney(
      min((row['amount'] as double) - (row['refunded'] as double), outstanding),
    );
    if (principal <= 0.001) return null;

    final firstLateDay = _addDays(dueDate, graceDays + 1);
    final through = row['interestThrough'] as String?;
    final afterLast = through == null ? null : _addDays(through, 1);
    final from = afterLast != null && afterLast.compareTo(firstLateDay) > 0
        ? afterLast
        : firstLateDay;
    if (from.compareTo(asOf) > 0) return null;

    final days =
        DateTime.parse(asOf).difference(DateTime.parse(from)).inDays + 1;
    // คิดเป็นสตางค์แล้วปัด เหมือน backend ที่เก็บเงินเป็นจำนวนเต็มสตางค์
    final amount =
        ((principal * 100) * annualRate * days / (100 * 365)).round() / 100;
    if (amount < 0.01) return null;
    return {
      'paymentId': row['paymentId'],
      'orderCode': row['orderCode'],
      'dueDate': dueDate,
      'principal': principal,
      'periodFrom': from,
      'periodTo': asOf,
      'days': days,
      'amount': amount,
    };
  }

  ({double rate, int grace, String asOf, List<Map<String, dynamic>> lines})
  _computeLateFees(int customerId) {
    final rate =
        (settings['lateFeeAnnualRatePercent'] as num?)?.toDouble() ?? 0;
    final grace = (settings['lateFeeGraceDays'] as num?)?.toInt() ?? 0;
    final asOf = _todayIso;
    final lines = rate <= 0
        ? <Map<String, dynamic>>[]
        : _creditInvoices(customerId)
              .map(
                (row) => _lateFeeLine(
                  row,
                  annualRate: rate,
                  graceDays: grace,
                  asOf: asOf,
                ),
              )
              .whereType<Map<String, dynamic>>()
              .toList();
    return (rate: rate, grace: grace, asOf: asOf, lines: lines);
  }

  Map<String, dynamic> lateFeePreview(int customerId) {
    findCustomer(customerId);
    final computed = _computeLateFees(customerId);
    return {
      'customerId': customerId,
      'annualRate': computed.rate,
      'graceDays': computed.grace,
      'asOf': computed.asOf,
      'items': computed.lines,
      'total': DemoStorePayments._roundMoney(
        computed.lines.fold<double>(
          0,
          (sum, row) => sum + (row['amount'] as num),
        ),
      ),
    };
  }

  /// ออกใบแจ้งดอกเบี้ยผิดนัด (mirror ของ late-fee.service.js#create)
  Map<String, dynamic> createLateFee(
    Map<String, dynamic> body, {
    int? actorId,
  }) {
    final customerId = body['customerId'] as int;
    final customer = findCustomer(customerId);
    final computed = _computeLateFees(customerId);
    if (computed.rate <= 0) {
      throw ApiException(
        message: 'receivable_error_late_fee_rate_unset'.tr,
        statusCode: 409,
      );
    }
    if (computed.lines.isEmpty) {
      throw ApiException(
        message: 'receivable_error_late_fee_nothing'.tr,
        statusCode: 409,
      );
    }
    final total = DemoStorePayments._roundMoney(
      computed.lines.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] as num),
      ),
    );
    final charge = <String, dynamic>{
      'id': _nextId(),
      'no': _nextDocumentNo('LF', arCharges),
      'customerId': customerId,
      'customerName': customer['name'],
      'total': total,
      'annualRate': computed.rate,
      'asOf': computed.asOf,
      'note': body['note'],
      'issuedByName': actorId == null ? null : DemoNames.of(_findUser(actorId)),
      'issuedAt': _now(),
      'isVoided': false,
      'voidReason': null,
      'items': computed.lines,
    };
    charge['chargeNo'] = charge['no'];
    arCharges.add(charge);
    _logAudit(
      actorId: actorId,
      action: 'receivable.late_fee',
      summaryArgs: {
        'total': total,
        'rate': computed.rate,
        'customer': customer['name'],
        'count': computed.lines.length,
        'chargeNo': charge['chargeNo'],
      },
      entityType: 'ar_charge',
      entityId: charge['id'] as int,
      summary:
          'คิดดอกเบี้ยผิดนัด ${_jsNumber(total)} บาท (${_jsNumber(computed.rate)}% ต่อปี) ให้ '
          '"${customer['name']}" ${computed.lines.length} บิล ใบแจ้ง ${charge['chargeNo']}',
      metadata: {'customerId': customerId, 'total': total},
    );
    return lateFeeDocument(charge['id'] as int);
  }

  Map<String, dynamic> _findLateFee(int id) => arCharges.firstWhere(
    (row) => row['id'] == id,
    orElse: () => throw ApiException(
      message: 'receivable_error_late_fee_not_found'.tr,
      statusCode: 404,
    ),
  );

  Map<String, dynamic> lateFeeDocument(int id) {
    final charge = _findLateFee(id);
    return {
      ...charge,
      'store': _documentStore(),
      'customer': findCustomer(charge['customerId'] as int),
      'emails': _emailsOf('late_fee', id),
    };
  }

  /// ยกเลิกใบแจ้งดอกเบี้ย = ยกเว้นดอกเบี้ย — ทำได้เฉพาะตอนดอกเบี้ยในใบยังไม่ถูกชำระ
  Map<String, dynamic> voidLateFee(int id, String reason, {int? actorId}) {
    final charge = _findLateFee(id);
    if (charge['isVoided'] == true) {
      throw ApiException(
        message: 'receivable_error_late_fee_already_voided'.tr,
        statusCode: 409,
      );
    }
    for (final item in (charge['items'] as List).cast<Map<String, dynamic>>()) {
      final payment = payments.firstWhere(
        (row) => row['id'] == item['paymentId'],
      );
      final outstanding = _invoiceRow(payment)['outstanding'] as double;
      if (outstanding + 0.001 < (item['amount'] as num)) {
        throw ApiException(
          message: 'receivable_error_late_fee_paid'.trParams({
            'code': item['orderCode'] as String,
          }),
          statusCode: 409,
        );
      }
    }
    charge
      ..['isVoided'] = true
      ..['voidReason'] = reason
      ..['voidedAt'] = _now();
    // ต้นเงินจ่ายครบแล้วเหลือแค่ดอกเบี้ยที่ยกเว้นให้ = ชำระครบ ได้แต้มตอนนี้ (DECISIONS #59)
    final points = _syncCreditPointsOf(
      (charge['items'] as List).cast<Map<String, dynamic>>().map(
        (item) => item['paymentId'] as int,
      ),
    );
    _logAudit(
      actorId: actorId,
      action: 'receivable.late_fee_void',
      summaryArgs: {
        'chargeNo': charge['chargeNo'],
        'total': charge['total'],
        'customer': charge['customerName'],
      },
      entityType: 'ar_charge',
      entityId: id,
      summary:
          'ยกเลิกใบแจ้งดอกเบี้ย ${charge['chargeNo']} (${_jsNumber(charge['total'])} บาท) '
          'ของ "${charge['customerName']}"',
      reason: reason,
      metadata: {'chargeNo': charge['chargeNo'], 'pointsEarned': points.earned},
    );
    return lateFeeDocument(id);
  }

  // ------------------------------------------------------------ ใบลดหนี้ -----

  /// ออกใบลดหนี้ให้การคืนเงินบิลขายเชื่อ — เรียกจาก [DemoStoreRefunds.refundPayment] เท่านั้น
  /// (mirror ของ credit-note.service.js#issueForRefund)
  Map<String, dynamic> _issueCreditNote({
    required Map<String, dynamic> payment,
    required Map<String, dynamic> refund,
    required double previousCredited,
    int? actorId,
  }) {
    final order = findOrder(payment['orderId'] as int);
    final amount = (refund['amount'] as num).toDouble();
    final orderTotal = (order['total'] as num).toDouble();
    final orderVat = (order['vat'] as num?)?.toDouble() ?? 0;
    // ราคาขายรวม VAT แล้ว — VAT ของผลต่างแบ่งตามสัดส่วน VAT ในบิลเดิม
    final vat = orderTotal > 0
        ? ((amount * 100) * orderVat / orderTotal).round() / 100
        : 0.0;
    final original = (payment['amount'] as num).toDouble();
    final taxInvoice = taxInvoices.firstWhere(
      (row) => row['orderId'] == order['id'] && row['voidedAt'] == null,
      orElse: () => const {},
    );
    final customer = findCustomer(order['customerId'] as int);
    final note = <String, dynamic>{
      'id': _nextId(),
      'no': _nextDocumentNo('CN', creditNotes),
      'customerId': customer['id'],
      'customerName': customer['name'],
      'paymentId': payment['id'],
      'refundId': refund['id'],
      'orderId': order['id'],
      'orderCode': order['code'],
      'originalAmount': original,
      'previousCredited': previousCredited,
      'amount': amount,
      'correctAmount': DemoStorePayments._roundMoney(
        original - previousCredited - amount,
      ),
      'vatAmount': vat,
      'baseAmount': DemoStorePayments._roundMoney(amount - vat),
      'taxInvoiceNo': taxInvoice['runningNumber'],
      'reason': refund['reason'],
      'issuedByName': actorId == null ? null : DemoNames.of(_findUser(actorId)),
      'issuedAt': _now(),
      'invoiceDate': payment['createdAt'],
    };
    note['noteNo'] = note['no'];
    creditNotes.add(note);
    refund
      ..['creditNoteId'] = note['id']
      ..['creditNoteNo'] = note['noteNo'];
    _logAudit(
      actorId: actorId,
      action: 'receivable.credit_note',
      summaryArgs: {
        'noteNo': note['noteNo'],
        'amount': amount,
        'code': order['code'],
        'customer': customer['name'],
      },
      entityType: 'credit_note',
      entityId: note['id'] as int,
      summary:
          'ออกใบลดหนี้ ${note['noteNo']} ${_jsNumber(amount)} บาท ให้บิล #${order['code']} '
          'ของ "${customer['name']}"',
      reason: refund['reason'] as String?,
      metadata: {'noteNo': note['noteNo'], 'amount': amount},
    );
    return note;
  }

  /// ลดหนี้บิลขายเชื่อ = คืนเงินบิลนั้น แล้วตอบกลับเป็นใบลดหนี้ (mirror ของ POST /credit-notes)
  Map<String, dynamic> createCreditNote(
    Map<String, dynamic> body, {
    required int actorId,
  }) {
    final paymentId = body['paymentId'] as int;
    final payment = payments.firstWhere(
      (row) => row['id'] == paymentId,
      orElse: () => throw ApiException(
        message: 'payment_error_payment_not_found'.tr,
        statusCode: 404,
      ),
    );
    if (payment['method'] != PaymentMethod.credit) {
      throw ApiException(
        message: 'receivable_error_credit_note_not_credit'.tr,
        statusCode: 400,
      );
    }
    final refund = refundPayment(
      paymentId: paymentId,
      amount: (body['amount'] as num).toDouble(),
      reason: body['reason'] as String,
      refundedById: actorId,
    );
    return creditNoteDocument(refund['creditNoteId'] as int);
  }

  Map<String, dynamic> creditNoteDocument(int id) {
    final note = creditNotes.firstWhere(
      (row) => row['id'] == id,
      orElse: () => throw ApiException(
        message: 'receivable_error_credit_note_not_found'.tr,
        statusCode: 404,
      ),
    );
    return {
      ...note,
      'store': _documentStore(),
      'customer': findCustomer(note['customerId'] as int),
      'emails': _emailsOf('credit_note', id),
    };
  }

  // ------------------------------------------------------- ส่งอีเมล (จำลอง) -----

  List<Map<String, dynamic>> _emailsOf(String kind, int documentId) =>
      documentEmails
          .where(
            (row) => row['kind'] == kind && row['documentId'] == documentId,
          )
          .toList()
          .reversed
          .toList(growable: false);

  static const Map<String, String> _documentTitles = {
    'billing_note': 'ใบวางบิล',
    'receipt': 'ใบเสร็จรับเงิน',
    'credit_note': 'ใบลดหนี้',
    'late_fee': 'ใบแจ้งดอกเบี้ยผิดนัด',
  };

  /// "ส่ง" เอกสารทางอีเมล — กติกาเดียวกับ receivable.documents.js#email แต่ไม่มีอีเมลออกจริง
  Map<String, dynamic> emailDocument(
    String kind,
    int id, {
    String? to,
    int? actorId,
  }) {
    final document = switch (kind) {
      'billing_note' => billingNoteDocument(id),
      'receipt' => arReceiptDocument(id),
      'credit_note' => creditNoteDocument(id),
      _ => lateFeeDocument(id),
    };
    final title = _documentTitles[kind]!;
    if (document['isVoided'] == true) {
      throw ApiException(
        message: 'receivable_error_email_voided'.trParams({'title': title}),
        statusCode: 409,
      );
    }
    final customer = document['customer'] as Map<String, dynamic>;
    final recipient = (to != null && to.trim().isNotEmpty)
        ? to.trim()
        : customer['email'] as String?;
    if (recipient == null || recipient.isEmpty) {
      throw ApiException(
        message: 'receivable_error_email_no_recipient'.tr,
        statusCode: 400,
      );
    }
    final number =
        (document['noteNo'] ??
                document['receiptNo'] ??
                document['chargeNo'] ??
                document['no'])
            as String;
    final subject =
        '$title $number — ${DemoNames.of(settings, key: 'storeName')}';
    documentEmails.add({
      'id': _nextId(),
      'kind': kind,
      'documentId': id,
      'to': recipient,
      'subject': subject,
      'sentByName': actorId == null ? null : DemoNames.of(_findUser(actorId)),
      'sentAt': _now(),
    });
    _logAudit(
      actorId: actorId,
      action: 'receivable.document_email',
      summaryArgs: {
        'document': kind,
        'number': number,
        'customer': customer['name'],
        'to': recipient,
        'demo': true,
      },
      entityType: kind,
      entityId: id,
      summary:
          'ส่ง$title $number ของ "${customer['name']}" ทางอีเมลถึง $recipient '
          '(โหมดสาธิต — ไม่ได้ส่งจริง)',
      metadata: {'documentNo': number, 'to': recipient},
    );
    return {...document, 'emails': _emailsOf(kind, id)};
  }
}
