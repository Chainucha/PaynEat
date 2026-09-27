// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// --------------------------------------------------------- refunds -----
extension DemoStoreRefunds on DemoStore {
  List<Map<String, dynamic>> refundsByOrder(int orderId) =>
      refunds.where((row) => row['orderId'] == orderId).toList(growable: false);

  double _refundedTotalByPayment(int paymentId) => refunds
      .where((row) => row['paymentId'] == paymentId)
      .fold<double>(0, (sum, row) => sum + (row['amount'] as num).toDouble());

  /// คืนเงินหลังชำระเงินแล้ว (เต็มจำนวน/บางส่วน) — ผูกกับ payment โดยตรงเพราะออเดอร์
  /// เดียวอาจมีหลาย payment (แยกจ่าย) ไม่แก้ payment เดิมหรือสถานะออเดอร์
  Map<String, dynamic> refundPayment({
    required int paymentId,
    required double amount,
    required String reason,
    required int refundedById,
  }) {
    final payment = payments.firstWhere(
      (row) => row['id'] == paymentId,
      orElse: () => throw ApiException(
        message: 'payment_error_payment_not_found'.tr,
        statusCode: 404,
      ),
    );

    final refundable =
        (payment['amount'] as num).toDouble() -
        _refundedTotalByPayment(paymentId);
    if (amount > refundable + 0.001) {
      throw ApiException(
        message: 'payment_error_refund_exceeds_refundable'.trParams({
          'amount': refundable.toStringAsFixed(2),
        }),
        statusCode: 400,
      );
    }

    // บิลขายเชื่อ: การคืนคือลดหนี้ ลดได้ไม่เกินยอดที่ยังค้าง (mirror ของ payment.service.js#refund)
    if (payment['method'] == PaymentMethod.credit) {
      final owed = creditRefundable(paymentId);
      if (amount > owed + 0.001) {
        throw ApiException(
          message: 'payment_error_credit_refund_exceeds_owed'.trParams({
            'amount': owed.toStringAsFixed(2),
          }),
          statusCode: 400,
        );
      }
    }

    // mirror ของ payment.service.js#refund — เงินสดที่คืนออกจากลิ้นชักของกะที่เปิดอยู่ตอนคืน จึงต้องมี
    // กะเปิดอยู่ (กฎเดียวกับตอนรับเงิน) คืนผ่านช่องทางอื่นไม่แตะลิ้นชักจึงไม่บังคับ — ดู DECISIONS #44
    final shift = _openShift;
    if (shift == null && payment['method'] == PaymentMethod.cash) {
      throw ApiException(
        message: 'payment_error_refund_shift_required'.tr,
        statusCode: 409,
      );
    }

    final previousCredited = _refundedTotalByPayment(paymentId);
    final refund = <String, dynamic>{
      'id': _nextId(),
      'paymentId': paymentId,
      'orderId': payment['orderId'],
      'shiftId': shift?['id'],
      'amount': amount,
      'reason': reason,
      'refundedBy': refundedById,
      'refundedByName': DemoNames.of(_findUser(refundedById)),
      'createdAt': _now(),
      'creditNoteId': null,
      'creditNoteNo': null,
    };
    refunds.add(refund);

    // ลดหนี้บิลขายเชื่อต้องมีเอกสารให้ลูกค้าเสมอ (ใบลดหนี้ DECISIONS #56)
    if (payment['method'] == PaymentMethod.credit) {
      _issueCreditNote(
        payment: payment,
        refund: refund,
        previousCredited: previousCredited,
        actorId: refundedById,
      );
      // ลดหนี้ส่วนที่เหลือจนยอดค้างเป็น 0 = ชำระครบ ได้แต้มจากยอดสุทธิ (DECISIONS #59)
      _syncCreditPoints(payment['orderId'] as int);
    }

    // mirror ของ payment.service.js#refund — ดู docs/tickets/08-audit-log.md
    final order = findOrder(payment['orderId'] as int);
    _logAudit(
      actorId: refundedById,
      action: 'payment.refund',
      summaryArgs: {'code': order['code'], 'amount': amount},
      entityType: 'refund',
      entityId: refund['id'] as int,
      summary: 'คืนเงิน ${_jsNumber(amount)} บาท ให้ออเดอร์ #${order['code']}',
      reason: reason,
      metadata: {
        'paymentId': paymentId,
        'orderId': payment['orderId'],
        'amount': amount,
      },
    );

    return refund;
  }
}
