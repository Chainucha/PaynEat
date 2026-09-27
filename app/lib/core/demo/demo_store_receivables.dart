// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------------------- receivables -----
/// ลูกหนี้การค้า / ขายเชื่อ / ใบวางบิล — mirror ของ backend receivable.service.js
/// (ดู docs/tickets/20-b2b-credit.md, docs/DECISIONS.md #50)
///
/// บิลขายเชื่อ = payment ที่ method เป็น credit ยอดค้างคำนวณสดทุกครั้งจากยอดบิล + ดอกเบี้ยผิดนัด − คืนเงิน
/// − ยอดที่ตัดชำระด้วยใบเสร็จที่ยังไม่ถูกยกเลิก เหมือนฝั่ง backend ไม่เก็บ "ยอดค้าง" แยกไว้
extension DemoStoreReceivables on DemoStore {
  static const _agingBuckets = [
    ('current', 0),
    ('days1to30', 30),
    ('days31to60', 60),
    ('days61to90', 90),
    ('over90', 1 << 30),
  ];

  String _isoDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String get _todayIso => _isoDay(AppClock.now());

  int _daysOverdue(String? dueDate, double outstanding) {
    if (dueDate == null || outstanding <= 0.001) return 0;
    final days = DateTime.parse(
      _todayIso,
    ).difference(DateTime.parse(dueDate)).inDays;
    return days > 0 ? days : 0;
  }

  double _settledOf(int paymentId) => arReceipts
      .where((receipt) => receipt['isVoided'] != true)
      .expand(
        (receipt) =>
            (receipt['allocations'] as List).cast<Map<String, dynamic>>(),
      )
      .where((line) => line['paymentId'] == paymentId)
      .fold<double>(0, (sum, line) => sum + (line['amount'] as num));

  String? _billingNoteNoOf(int paymentId) {
    for (final note in billingNotes) {
      if (note['isVoided'] == true) continue;
      final items = (note['items'] as List).cast<Map<String, dynamic>>();
      if (items.any((line) => line['paymentId'] == paymentId)) {
        return note['noteNo'] as String;
      }
    }
    return null;
  }

  Map<String, dynamic> _invoiceRow(Map<String, dynamic> payment) {
    final id = payment['id'] as int;
    final amount = (payment['amount'] as num).toDouble();
    final refunded = _refundedTotalByPayment(id);
    final settled = _settledOf(id);
    // ดอกเบี้ยผิดนัดบวกเข้ายอดค้างของบิลนั้นเลย (DECISIONS #55)
    final charged = _chargedOf(id);
    final order = findOrder(payment['orderId'] as int);
    return {
      'paymentId': id,
      'orderId': order['id'],
      'orderCode': order['code'],
      'customerId': order['customerId'],
      'amount': amount,
      'refunded': refunded,
      'settled': settled,
      'interest': DemoStorePayments._roundMoney(charged),
      'interestThrough': _interestThroughOf(id),
      'outstanding': DemoStorePayments._roundMoney(
        amount + charged - refunded - settled,
      ),
      'createdAt': payment['createdAt'],
      'dueDate': payment['dueDate'],
      'billingNoteNo': _billingNoteNoOf(id),
    };
  }

  /// บิลขายเชื่อทุกใบของลูกค้า เก่าสุดก่อน (ครบกำหนดก่อน → ขายก่อน) — ลำดับเดียวกับที่ใช้ตัดชำระ
  List<Map<String, dynamic>> _creditInvoices(int customerId) {
    final rows = payments
        .where((payment) => payment['method'] == PaymentMethod.credit)
        .map(_invoiceRow)
        .where((row) => row['customerId'] == customerId)
        .toList();
    rows.sort((a, b) {
      final byDue = (a['dueDate'] as String).compareTo(b['dueDate'] as String);
      if (byDue != 0) return byDue;
      return (a['paymentId'] as int).compareTo(b['paymentId'] as int);
    });
    return rows;
  }

  List<Map<String, dynamic>> _openInvoices(int customerId) => _creditInvoices(
    customerId,
  ).where((row) => (row['outstanding'] as double) > 0.001).toList();

  double creditOutstanding(int customerId) => DemoStorePayments._roundMoney(
    _openInvoices(
      customerId,
    ).fold<double>(0, (sum, row) => sum + (row['outstanding'] as double)),
  );

  /// ลูกค้ารายนี้ขายเชื่อยอดนี้ได้ไหม — คืนวันครบกำหนด (mirror ของ assertCanCharge)
  String assertCanChargeCredit(int customerId, double amount) {
    final customer = findCustomer(customerId);
    final limit = (customer['creditLimit'] as num?)?.toDouble() ?? 0;
    if (limit <= 0) {
      throw ApiException(
        message: 'payment_error_credit_no_limit'.trParams({
          'name': customer['name'] as String,
        }),
        statusCode: 409,
      );
    }
    final outstanding = creditOutstanding(customerId);
    final available = DemoStorePayments._roundMoney(limit - outstanding);
    if (amount > available + 0.001) {
      throw ApiException(
        message: 'payment_error_credit_limit_exceeded'.trParams({
          'name': customer['name'] as String,
          'limit': limit.toStringAsFixed(2),
          'outstanding': outstanding.toStringAsFixed(2),
          'available': max(available, 0).toStringAsFixed(2),
        }),
        statusCode: 409,
      );
    }
    final term = (customer['creditTermDays'] as num?)?.toInt() ?? 30;
    return _isoDay(AppClock.now().add(Duration(days: term)));
  }

  /// ออเดอร์นี้มีส่วนที่ขายเชื่อไหม — มี = ปิดบิลแล้วยังไม่ให้แต้ม รอรับชำระหนี้ครบ (DECISIONS #59)
  bool _hasCreditPayment(int orderId) => payments.any(
    (row) => row['orderId'] == orderId && row['method'] == PaymentMethod.credit,
  );

  /// แต้มสะสมของบิลขายเชื่อ — mirror ของ backend credit-points.js (docs/DECISIONS.md #59)
  ///
  /// ยอดค้างทุกบิลขายเชื่อของออเดอร์ (รวมดอกเบี้ย) เป็น 0 = ได้แต้มจากยอดสุทธิหลังลดหนี้ กลับมาค้าง =
  /// ดึงคืนเท่าที่ลูกค้ายังมี (ยอดแต้มติดลบไม่ได้) และ pointsEarned เก็บแต้มที่ยังอยู่กับลูกค้าจริง
  ({int earned, int revoked, int shortfall}) _syncCreditPoints(int orderId) {
    const none = (earned: 0, revoked: 0, shortfall: 0);
    final order = findOrder(orderId);
    final customerId = order['customerId'] as int?;
    if (customerId == null) return none;
    final invoices = payments
        .where(
          (row) =>
              row['orderId'] == orderId &&
              row['method'] == PaymentMethod.credit,
        )
        .map(_invoiceRow)
        .toList();
    if (invoices.isEmpty) return none;

    final settled =
        order['status'] == OrderStatus.paid &&
        invoices.every((row) => (row['outstanding'] as double) <= 0.001);
    final refunded = refunds
        .where((row) => row['orderId'] == orderId)
        .fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble());
    // สตางค์เป็นจำนวนเต็มเหมือน backend — หารทศนิยมตรง ๆ อาจปัดต่างกันหนึ่งแต้มที่ขอบ
    final netSatang = (((order['total'] as num).toDouble() - refunded) * 100)
        .round();
    final rateSatang =
        ((settings['pointsEarnRateBaht'] as num).toDouble() * 100).round();
    final target = settled && netSatang > 0 ? netSatang ~/ rateSatang : 0;
    final current = (order['pointsEarned'] as num?)?.toInt() ?? 0;

    if (target > current) {
      adjustCustomerPoints(customerId, target - current);
      order['pointsEarned'] = target;
      return (earned: target - current, revoked: 0, shortfall: 0);
    }
    if (target < current) {
      final balance = (findCustomer(customerId)['pointsBalance'] as num)
          .toInt();
      final revoked = min(current - target, balance);
      if (revoked > 0) adjustCustomerPoints(customerId, -revoked);
      order['pointsEarned'] = current - revoked;
      return (
        earned: 0,
        revoked: revoked,
        shortfall: current - target - revoked,
      );
    }
    return none;
  }

  /// sync ทุกออเดอร์ของบิลขายเชื่อ ([paymentIds]) แล้วรวมผลไว้ใส่ audit
  ({int earned, int revoked, int shortfall}) _syncCreditPointsOf(
    Iterable<int> paymentIds,
  ) {
    var earned = 0;
    var revoked = 0;
    var shortfall = 0;
    final orderIds = {
      for (final paymentId in paymentIds)
        payments.firstWhere((row) => row['id'] == paymentId)['orderId'] as int,
    };
    for (final orderId in orderIds) {
      final result = _syncCreditPoints(orderId);
      earned += result.earned;
      revoked += result.revoked;
      shortfall += result.shortfall;
    }
    return (earned: earned, revoked: revoked, shortfall: shortfall);
  }

  /// คืนเงินบิลขายเชื่อได้ไม่เกินยอดที่ยังค้าง
  double creditRefundable(int paymentId) {
    final payment = payments.firstWhere((row) => row['id'] == paymentId);
    final outstanding = _invoiceRow(payment)['outstanding'] as double;
    return max(outstanding, 0);
  }

  /// รายละเอียดลูกค้าพร้อมยอดหนี้ปัจจุบัน (mirror ของ customer.service.js#getById)
  Map<String, dynamic> customerWithCredit(int id) {
    final customer = findCustomer(id);
    final outstanding = creditOutstanding(id);
    final limit = (customer['creditLimit'] as num?)?.toDouble() ?? 0;
    return {
      ...customer,
      'creditOutstanding': outstanding,
      'creditAvailable': max(
        DemoStorePayments._roundMoney(limit - outstanding),
        0,
      ),
    };
  }

  /// ตั้งวงเงินเครดิต (mirror ของ customer.service.js#updateCredit)
  Map<String, dynamic> updateCustomerCredit(
    int id,
    Map<String, dynamic> body, {
    int? actorId,
  }) {
    final customer = findCustomer(id);
    final previousLimit = (customer['creditLimit'] as num?)?.toDouble() ?? 0;
    final previousTerm = (customer['creditTermDays'] as num?)?.toInt() ?? 30;
    final limit = (body['creditLimit'] as num).toDouble();
    final term = (body['creditTermDays'] as num).toInt();
    final taxId = (body['taxId'] as String?)?.trim() ?? '';
    // อีเมลรับเอกสาร (ticket 23) — ไม่ส่งมา = คงค่าเดิม ส่ง '' = ล้างค่า เหมือน backend
    final email = (body['email'] as String?)?.trim();
    if (taxId.isNotEmpty && !RegExp(r'^\d{13}$').hasMatch(taxId)) {
      throw ApiException(
        message: 'customer_error_tax_id_invalid'.tr,
        statusCode: 422,
      );
    }
    final address = (body['address'] as String?)?.trim() ?? '';
    customer
      ..['creditLimit'] = limit
      ..['creditTermDays'] = term
      ..['taxId'] = taxId.isEmpty ? null : taxId
      ..['address'] = address.isEmpty ? null : address
      ..['email'] = email == null
          ? customer['email']
          : (email.isEmpty ? null : email)
      ..['updatedAt'] = _now();

    if (limit != previousLimit || term != previousTerm) {
      _logAudit(
        actorId: actorId,
        action: 'customer.credit_update',
        summaryArgs: {
          'name': customer['name'],
          'fromLimit': previousLimit,
          'toLimit': limit,
          'fromDays': previousTerm,
          'toDays': term,
        },
        entityType: 'customer',
        entityId: id,
        summary:
            'ตั้งวงเงินเครดิต "${customer['name']}" ${_jsNumber(previousLimit)} → ${_jsNumber(limit)} บาท '
            'เครดิต $previousTerm → $term วัน',
        metadata: {
          'previousCreditLimit': previousLimit,
          'newCreditLimit': limit,
          'previousTermDays': previousTerm,
          'newTermDays': term,
        },
      );
    }
    return customerWithCredit(id);
  }

  Map<String, dynamic> _summaryOf(Map<String, dynamic> customer) {
    final id = customer['id'] as int;
    final invoices = _creditInvoices(id);
    final open = invoices
        .where((row) => (row['outstanding'] as double) > 0.001)
        .toList();
    final aging = {for (final bucket in _agingBuckets) bucket.$1: 0.0};
    var overdue = 0.0;
    for (final row in open) {
      final outstanding = row['outstanding'] as double;
      final days = _daysOverdue(row['dueDate'] as String?, outstanding);
      if (days > 0) overdue += outstanding;
      final bucket = _agingBuckets.firstWhere((entry) => days <= entry.$2);
      aging[bucket.$1] = aging[bucket.$1]! + outstanding;
    }
    final outstanding = open.fold<double>(
      0,
      (sum, row) => sum + (row['outstanding'] as double),
    );
    final limit = (customer['creditLimit'] as num?)?.toDouble() ?? 0;
    return {
      'customer': customer,
      'creditLimit': limit,
      'creditTermDays': customer['creditTermDays'] ?? 30,
      'outstanding': DemoStorePayments._roundMoney(outstanding),
      'overdue': DemoStorePayments._roundMoney(overdue),
      'available': max(DemoStorePayments._roundMoney(limit - outstanding), 0),
      'openInvoiceCount': open.length,
      'oldestDueDate': open.isEmpty ? null : open.first['dueDate'],
      'aging': aging.map(
        (key, value) => MapEntry(key, DemoStorePayments._roundMoney(value)),
      ),
    };
  }

  /// รายชื่อลูกค้าเครดิต — มีวงเงิน หรือยังมีบิลขายเชื่อค้าง เกินกำหนดมากสุดขึ้นก่อน
  List<Map<String, dynamic>> receivableCustomers() {
    final withCredit = customers.where((customer) {
      final limit = (customer['creditLimit'] as num?)?.toDouble() ?? 0;
      return limit > 0 || _creditInvoices(customer['id'] as int).isNotEmpty;
    });
    final rows = withCredit.map(_summaryOf).toList()
      ..sort((a, b) {
        final byOverdue = (b['overdue'] as double).compareTo(
          a['overdue'] as double,
        );
        if (byOverdue != 0) return byOverdue;
        return (b['outstanding'] as double).compareTo(
          a['outstanding'] as double,
        );
      });
    return rows;
  }

  Map<String, dynamic> receivableStatement(int customerId) {
    final customer = findCustomer(customerId);
    return {
      ..._summaryOf(customer),
      'today': _todayIso,
      'invoices': _creditInvoices(customerId)
          .map(
            (row) => {
              ...row,
              'outstanding': max(row['outstanding'] as double, 0),
              'daysOverdue': _daysOverdue(
                row['dueDate'] as String?,
                row['outstanding'] as double,
              ),
            },
          )
          .toList(growable: false),
      'receipts': arReceipts
          .where((row) => row['customerId'] == customerId)
          .toList()
          .reversed
          .toList(growable: false),
      'billingNotes': billingNotes
          .where((row) => row['customerId'] == customerId)
          .map(_withNoteStatus)
          .toList()
          .reversed
          .toList(growable: false),
      'creditNotes': creditNotes
          .where((row) => row['customerId'] == customerId)
          .toList()
          .reversed
          .toList(growable: false),
      'lateFees': arCharges
          .where((row) => row['customerId'] == customerId)
          .toList()
          .reversed
          .toList(growable: false),
    };
  }
}
