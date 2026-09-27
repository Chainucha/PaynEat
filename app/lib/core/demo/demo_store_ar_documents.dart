// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------------ AR documents -----
/// เอกสารลูกหนี้: ใบเสร็จรับชำระหนี้ + ใบวางบิล — mirror ของ backend receivable.service.js
/// (ดู docs/tickets/20-b2b-credit.md, docs/DECISIONS.md #50) แยกจาก [DemoStoreReceivables] ที่คำนวณ
/// ยอดค้าง/อายุหนี้ เพื่อไม่ให้ไฟล์เดียวโตเกินที่ `docs/CODING_STANDARDS.md` หัวข้อ 2.2 แนะนำ
extension DemoStoreArDocuments on DemoStore {
  /// เลขที่เอกสาร <code><ปี พ.ศ. 2 หลัก>-<เลขรัน 6 หลัก> นับรวมใบที่ถูกยกเลิก (เหมือนใบกำกับภาษี)
  String _nextDocumentNo(String code, List<Map<String, dynamic>> rows) {
    final year = AppClock.now().year + 543;
    final prefix = '$code${year.toString().substring(2)}-';
    final count = rows
        .where((row) => (row['no'] as String).startsWith(prefix))
        .length;
    return '$prefix${(count + 1).toString().padLeft(6, '0')}';
  }

  Map<String, dynamic> _documentStore() => {
    'name': DemoNames.of(settings, key: 'storeName'),
    'taxId': settings['storeTaxId'],
    'address': settings['storeAddress'],
    'branch': settings['storeBranch'],
  };

  /// รับชำระหนี้ — ตัดบิลเก่าสุดก่อน หรือเฉพาะบิลในใบวางบิลที่ระบุ (mirror ของ createReceipt)
  Map<String, dynamic> createArReceipt(
    Map<String, dynamic> body, {
    int? actorId,
  }) {
    final customerId = body['customerId'] as int;
    final customer = findCustomer(customerId);
    final amount = (body['amount'] as num).toDouble();
    final method = body['method'] as String;
    final billingNoteId = body['billingNoteId'] as int?;

    var candidates = _openInvoices(customerId);
    if (billingNoteId != null) {
      final note = _findBillingNote(billingNoteId);
      if (note['customerId'] != customerId) {
        throw ApiException(
          message: 'receivable_error_note_other_customer'.tr,
          statusCode: 400,
        );
      }
      if (note['isVoided'] == true) {
        throw ApiException(
          message: 'receivable_error_note_voided'.tr,
          statusCode: 409,
        );
      }
      final onNote = (note['items'] as List)
          .map((line) => (line as Map)['paymentId'])
          .toSet();
      candidates = candidates
          .where((row) => onNote.contains(row['paymentId']))
          .toList();
    }

    final payable = candidates.fold<double>(
      0,
      (sum, row) => sum + (row['outstanding'] as double),
    );
    if (payable <= 0.001) {
      throw ApiException(
        message: 'receivable_error_nothing_owed'.tr,
        statusCode: 409,
      );
    }
    if (amount > payable + 0.001) {
      throw ApiException(
        message: 'receivable_error_over_payment'.trParams({
          'amount': payable.toStringAsFixed(2),
        }),
        statusCode: 400,
      );
    }
    final shift = _openShift;
    if (shift == null && method == PaymentMethod.cash) {
      throw ApiException(
        message: 'receivable_error_cash_needs_shift'.tr,
        statusCode: 409,
      );
    }

    final allocations = <Map<String, dynamic>>[];
    var remaining = amount;
    for (final row in candidates) {
      if (remaining <= 0.001) break;
      final applied = DemoStorePayments._roundMoney(
        min(remaining, row['outstanding'] as double),
      );
      allocations.add({
        'paymentId': row['paymentId'],
        'orderCode': row['orderCode'],
        'amount': applied,
        'createdAt': row['createdAt'],
        'dueDate': row['dueDate'],
      });
      remaining = DemoStorePayments._roundMoney(remaining - applied);
    }

    final receipt = {
      'id': _nextId(),
      'no': _nextDocumentNo('RC', arReceipts),
      'customerId': customerId,
      'customerName': customer['name'],
      'amount': amount,
      'method': method,
      'reference': body['reference'],
      'note': body['note'],
      'shiftId': shift?['id'],
      'receivedByName': actorId == null
          ? null
          : DemoNames.of(_findUser(actorId)),
      'receivedAt': _now(),
      'isVoided': false,
      'voidReason': null,
      'allocations': allocations,
    };
    receipt['receiptNo'] = receipt['no'];
    arReceipts.add(receipt);
    // บิลที่ใบเสร็จนี้ปิดยอดได้ครบ ลูกค้าได้แต้มสะสมตอนนี้ (DECISIONS #59)
    final points = _syncCreditPointsOf(
      allocations.map((line) => line['paymentId'] as int),
    );

    _logAudit(
      actorId: actorId,
      action: 'receivable.receipt',
      summaryArgs: {
        'amount': amount,
        'method': method,
        'customer': customer['name'],
        'receiptNo': receipt['receiptNo'],
      },
      entityType: 'ar_receipt',
      entityId: receipt['id'] as int,
      summary:
          'รับชำระหนี้ ${_jsNumber(amount)} บาท ($method) จาก "${customer['name']}" '
          'ใบเสร็จ ${receipt['receiptNo']}',
      metadata: {
        'customerId': customerId,
        'amount': amount,
        'method': method,
        'pointsEarned': points.earned,
      },
    );
    return receipt;
  }

  Map<String, dynamic> _findReceipt(int id) => arReceipts.firstWhere(
    (row) => row['id'] == id,
    orElse: () => throw ApiException(
      message: 'receivable_error_receipt_not_found'.tr,
      statusCode: 404,
    ),
  );

  Map<String, dynamic> arReceiptDocument(int id) {
    final receipt = _findReceipt(id);
    return {
      ...receipt,
      'store': _documentStore(),
      'customer': findCustomer(receipt['customerId'] as int),
      'emails': _emailsOf('receipt', id),
    };
  }

  /// ยกเลิกใบเสร็จ — เงินสดยกเลิกได้เฉพาะระหว่างกะที่รับเงินยังเปิดอยู่ (mirror ของ voidReceipt)
  Map<String, dynamic> voidArReceipt(int id, String reason, {int? actorId}) {
    final receipt = _findReceipt(id);
    if (receipt['isVoided'] == true) {
      throw ApiException(
        message: 'receivable_error_receipt_already_voided'.tr,
        statusCode: 409,
      );
    }
    if (receipt['method'] == PaymentMethod.cash) {
      final shift = shifts.firstWhere(
        (row) => row['id'] == receipt['shiftId'],
        orElse: () => const {},
      );
      if (shift['status'] != ShiftStatus.open) {
        throw ApiException(
          message: 'receivable_error_receipt_shift_closed'.tr,
          statusCode: 409,
        );
      }
    }
    receipt
      ..['isVoided'] = true
      ..['voidReason'] = reason
      ..['voidedAt'] = _now();
    // บิลกลับมาค้าง = ดึงแต้มที่ได้ตอนชำระครบคืน เท่าที่ลูกค้ายังมี (DECISIONS #59)
    final points = _syncCreditPointsOf(
      (receipt['allocations'] as List).cast<Map<String, dynamic>>().map(
        (line) => line['paymentId'] as int,
      ),
    );
    _logAudit(
      actorId: actorId,
      action: 'receivable.receipt_void',
      summaryArgs: {
        'receiptNo': receipt['receiptNo'],
        'amount': receipt['amount'],
        'customer': receipt['customerName'],
      },
      entityType: 'ar_receipt',
      entityId: id,
      summary:
          'ยกเลิกใบเสร็จรับชำระหนี้ ${receipt['receiptNo']} '
          '(${_jsNumber(receipt['amount'])} บาท) ของ "${receipt['customerName']}"',
      reason: reason,
      metadata: {
        'receiptNo': receipt['receiptNo'],
        'pointsRevoked': points.revoked,
        'pointsNotRecovered': points.shortfall,
      },
    );
    return receipt;
  }

  Map<String, dynamic> _findBillingNote(int id) => billingNotes.firstWhere(
    (row) => row['id'] == id,
    orElse: () => throw ApiException(
      message: 'receivable_error_note_not_found'.tr,
      statusCode: 404,
    ),
  );

  /// สถานะ/ยอดคงเหลือของใบวางบิลคำนวณสดจากยอดค้างของบิลในใบ ณ ตอนนี้
  Map<String, dynamic> _withNoteStatus(Map<String, dynamic> note) {
    final isVoided = note['isVoided'] == true;
    var remaining = 0.0;
    if (!isVoided) {
      for (final line in (note['items'] as List).cast<Map<String, dynamic>>()) {
        final payment = payments.firstWhere(
          (row) => row['id'] == line['paymentId'],
        );
        final outstanding = max(
          _invoiceRow(payment)['outstanding'] as double,
          0,
        );
        remaining += min(outstanding, (line['amount'] as num).toDouble());
      }
    }
    remaining = DemoStorePayments._roundMoney(remaining);
    return {
      ...note,
      'remaining': remaining,
      'status': isVoided
          ? 'void'
          : remaining > 0.001
          ? 'open'
          : 'paid',
    };
  }

  /// ออกใบวางบิล — รวบบิลค้างที่ยังไม่อยู่ในใบวางบิลอื่น (mirror ของ createBillingNote)
  Map<String, dynamic> createBillingNote(
    Map<String, dynamic> body, {
    int? actorId,
  }) {
    final customerId = body['customerId'] as int;
    final customer = findCustomer(customerId);
    final open = _openInvoices(customerId);
    final paymentIds = (body['paymentIds'] as List?)?.cast<int>();

    List<Map<String, dynamic>> selected;
    if (paymentIds != null && paymentIds.isNotEmpty) {
      selected = paymentIds.map((paymentId) {
        final row = open.firstWhere(
          (candidate) => candidate['paymentId'] == paymentId,
          orElse: () => throw ApiException(
            message: 'receivable_error_invoice_not_open'.tr,
            statusCode: 400,
          ),
        );
        if (row['billingNoteNo'] != null) {
          throw ApiException(
            message: 'receivable_error_invoice_already_billed'.trParams({
              'code': row['orderCode'] as String,
              'note': row['billingNoteNo'] as String,
            }),
            statusCode: 409,
          );
        }
        return row;
      }).toList();
    } else {
      selected = open.where((row) => row['billingNoteNo'] == null).toList();
    }
    if (selected.isEmpty) {
      throw ApiException(
        message: 'receivable_error_nothing_to_bill'.tr,
        statusCode: 409,
      );
    }

    final latestDue = selected.fold<String>(
      _todayIso,
      (latest, row) => (row['dueDate'] as String).compareTo(latest) > 0
          ? row['dueDate'] as String
          : latest,
    );
    final total = DemoStorePayments._roundMoney(
      selected.fold<double>(
        0,
        (sum, row) => sum + (row['outstanding'] as double),
      ),
    );
    final note = {
      'id': _nextId(),
      'no': _nextDocumentNo('BN', billingNotes),
      'customerId': customerId,
      'customerName': customer['name'],
      'total': total,
      'dueDate': body['dueDate'] ?? latestDue,
      'note': body['note'],
      'issuedByName': actorId == null ? null : DemoNames.of(_findUser(actorId)),
      'issuedAt': _now(),
      'isVoided': false,
      'voidReason': null,
      'items': selected
          .map(
            (row) => {
              'paymentId': row['paymentId'],
              'orderCode': row['orderCode'],
              'amount': row['outstanding'],
              'createdAt': row['createdAt'],
              'dueDate': row['dueDate'],
            },
          )
          .toList(),
    };
    note['noteNo'] = note['no'];
    billingNotes.add(note);

    _logAudit(
      actorId: actorId,
      action: 'receivable.billing_note',
      summaryArgs: {
        'noteNo': note['noteNo'],
        'customer': customer['name'],
        'count': selected.length,
        'total': total,
      },
      entityType: 'billing_note',
      entityId: note['id'] as int,
      summary:
          'ออกใบวางบิล ${note['noteNo']} ให้ "${customer['name']}" '
          '${selected.length} บิล รวม ${_jsNumber(total)} บาท',
      metadata: {'customerId': customerId, 'total': total},
    );
    return billingNoteDocument(note['id'] as int);
  }

  Map<String, dynamic> billingNoteDocument(int id) {
    final note = _withNoteStatus(_findBillingNote(id));
    return {
      ...note,
      'store': _documentStore(),
      'customer': findCustomer(note['customerId'] as int),
      'emails': _emailsOf('billing_note', id),
    };
  }

  Map<String, dynamic> voidBillingNote(int id, String reason, {int? actorId}) {
    final note = _findBillingNote(id);
    if (note['isVoided'] == true) {
      throw ApiException(
        message: 'receivable_error_note_already_voided'.tr,
        statusCode: 409,
      );
    }
    note
      ..['isVoided'] = true
      ..['voidReason'] = reason
      ..['voidedAt'] = _now();
    _logAudit(
      actorId: actorId,
      action: 'receivable.billing_note_void',
      summaryArgs: {'noteNo': note['noteNo'], 'customer': note['customerName']},
      entityType: 'billing_note',
      entityId: id,
      summary: 'ยกเลิกใบวางบิล ${note['noteNo']} ของ "${note['customerName']}"',
      reason: reason,
      metadata: {'noteNo': note['noteNo']},
    );
    return _withNoteStatus(note);
  }

  /// เงินสดรับชำระหนี้ระหว่างกะ (ใบที่ยกเลิกไม่นับ) — เข้าลิ้นชักเหมือนรับค่าอาหาร
  double receivableCashDuring(int shiftId) => arReceipts
      .where(
        (row) =>
            row['shiftId'] == shiftId &&
            row['method'] == PaymentMethod.cash &&
            row['isVoided'] != true,
      )
      .fold<double>(0, (sum, row) => sum + (row['amount'] as num));

  List<Map<String, dynamic>> receivableReceiptsByShift(int shiftId) {
    final byMethod = <String, Map<String, dynamic>>{};
    for (final row in arReceipts) {
      if (row['shiftId'] != shiftId || row['isVoided'] == true) continue;
      final method = row['method'] as String;
      final entry = byMethod.putIfAbsent(
        method,
        () => {'method': method, 'count': 0, 'amount': 0.0},
      );
      entry['count'] = (entry['count'] as int) + 1;
      entry['amount'] =
          (entry['amount'] as double) + (row['amount'] as num).toDouble();
    }
    return byMethod.values.toList(growable: false);
  }
}
