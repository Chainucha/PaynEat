// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../../../core/constants/app_constants.dart';

/// การชำระเงิน 1 ครั้ง (1 ออเดอร์อาจมีหลายครั้งได้ กรณีแยกจ่าย)
class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    this.received = 0,
    this.change = 0,
    this.reference,
    this.cashierName,
    this.createdAt,
    this.pointsRedeemed = 0,
    this.pointsRedeemedValue = 0,
    this.dueDate,
  });

  final int id;
  final int orderId;
  final String method;
  final double amount;
  final double received;
  final double change;
  final String? reference;
  final String? cashierName;
  final String? createdAt;
  // ใช้แต้มสะสมแลกส่วนลดรอบจ่ายนี้ (ดู docs/tickets/09-customer-loyalty.md)
  final int pointsRedeemed;
  final double pointsRedeemedValue;

  /// วันครบกำหนดชำระ (YYYY-MM-DD) ของบิลขายเชื่อ — ช่องทางอื่นเป็น null
  final String? dueDate;

  bool get isCredit => method == PaymentMethod.credit;

  String get methodLabel => PaymentMethod.label(method);

  /// ยอดที่ต้องโชว์บนใบเสร็จของวิธีชำระนี้ — ใช้ "เงินที่ลูกค้ายื่นมา" ไม่ใช่
  /// [amount] ที่ตัดเข้าบิล เพราะใบเสร็จไทยกระทบยอดกันเองด้วยบรรทัดเงินทอน
  /// (ยื่นมา − ทอน = ยอดที่ตัดเข้าบิล) ถ้าโชว์ [amount] คู่กับบรรทัดเงินทอน
  /// ลูกค้าจะบวกแล้วไม่ตรงกับเงินที่ยื่นให้จริง
  ///
  /// QR/บัตร/โอน ไม่มีการทอน ฝั่ง backend และ demo จึงเซ็ต received = amount
  /// อยู่แล้ว ส่วนเงื่อนไข `>` เผื่อข้อมูลเก่าที่ยังไม่มีช่อง received (ได้ 0)
  double get tendered => received > amount ? received : amount;
}

/// สรุปยอดชำระของออเดอร์
class PaymentSummary {
  const PaymentSummary({
    required this.orderId,
    required this.total,
    required this.paid,
    required this.remaining,
    this.refunded = 0,
    this.refundDue = 0,
    this.payments = const [],
    this.refunds = const [],
  });

  final int orderId;
  final double total;

  /// เงินที่ร้านถือไว้สุทธิ = ยอดชำระ − ยอดคืนเงิน (T06 #82, docs/DECISIONS.md #87)
  final double paid;
  final double remaining;

  /// ยอดคืนเงินรวมของออเดอร์นี้ — คืนบนบิลที่ยังเปิดทำให้ยอดคงเหลือเพิ่มขึ้นเท่านี้
  final double refunded;

  /// บิลที่ยังเปิดแต่ร้านถือเงินไว้เกินยอดบิล = ยอดที่ต้องคืนลูกค้าก่อน (T07 #105, docs/DECISIONS.md #95)
  /// ยอดคงเหลือเป็น 0 ในกรณีนี้ หน้าจอจึงต้องโชว์ยอดนี้แทน ไม่ใช่ "คงเหลือ 0"
  final double refundDue;
  final List<Payment> payments;
  final List<Refund> refunds;

  bool get needsRefund => refundDue > 0;

  /// ยอดที่คืนไปแล้วของ payment นี้
  double refundedFor(int paymentId) => refunds
      .where((refund) => refund.paymentId == paymentId)
      .fold<double>(0, (sum, refund) => sum + refund.amount);

  bool get isFullyPaid => remaining <= 0 && !needsRefund;
  bool get isPartiallyPaid => paid > 0 && remaining > 0;
}

/// ผลลัพธ์หลังกดชำระเงิน
class PaymentResult {
  const PaymentResult({
    required this.payment,
    required this.isFullyPaid,
    required this.remaining,
  });

  final Payment payment;
  final bool isFullyPaid;
  final double remaining;
}

/// ยอดที่ต้องจ่ายสำหรับรายการอาหารบางส่วน — ใช้ก่อนแยกบิลรายคนจริง
class SplitPreview {
  const SplitPreview({
    required this.orderId,
    required this.itemIds,
    required this.subtotal,
    required this.discountAmount,
    required this.serviceCharge,
    required this.vat,
    required this.total,
    required this.remaining,
    required this.isLastBatch,
    this.vatIncluded = false,
    this.adjustment = 0,
  });

  final int orderId;
  final List<int> itemIds;
  final double subtotal;

  /// ส่วนลดมือ + ส่วนลดโปรโมชันที่ปันมาให้รายการที่เลือก (T10 #83)
  final double discountAmount;
  final double serviceCharge;
  final double vat;
  final double total;
  final double remaining;

  /// ร้านตั้งราคารวม VAT — [vat] อยู่ใน [total] แล้ว แสดงเพื่อให้รู้เท่านั้น ไม่บวกซ้ำ
  final bool vatIncluded;

  /// ส่วนต่างระหว่างยอดที่เก็บจริงกับส่วนแบ่งที่คำนวณได้ เช่นบิลเคยรับเงินแบบระบุยอดไปก่อน — ตัวเลขใน preview
  /// รวมกันได้ [total] เสมอ: subtotal − discount + serviceCharge (+ vat) + adjustment
  final double adjustment;

  /// รายการที่เลือกครอบคลุมทุกรายการที่ยังไม่จ่ายแล้วหรือไม่ — ถ้าใช่ ยอด [total]
  /// จะถูกบังคับให้เท่ากับ [remaining] พอดี กันเศษสตางค์ตกหล่นจากการปัดเศษหลายรอบ
  final bool isLastBatch;
}

/// ข้อมูลใบเสร็จ
class Receipt {
  const Receipt({
    required this.storeName,
    required this.currency,
    required this.vatRate,
    required this.serviceChargeRate,
    required this.payments,
    this.refunds = const [],
    this.refundedTotal = 0,
    this.paidAt,
    this.changeTotal = 0,
  });

  final String storeName;
  final String currency;
  final double vatRate;
  final double serviceChargeRate;
  final List<Payment> payments;
  final List<Refund> refunds;
  final double refundedTotal;
  final String? paidAt;
  final double changeTotal;

  bool get isRefunded => refundedTotal > 0;
}

/// payload สำหรับ QR พร้อมเพย์ (ดู docs/tickets/16-promptpay-qr.md) — [payload] เอาไปเรนเดอร์
/// เป็นภาพ QR ได้เลย (ผ่าน qr_flutter) ไม่ใช่ URL รูปภาพ
class PromptPayQr {
  const PromptPayQr({
    required this.payload,
    required this.promptPayId,
    this.amount,
  });

  final String payload;
  final String promptPayId;
  final double? amount;
}

/// คืนเงินหลังชำระเงินแล้ว — ผูกกับ payment ที่ระบุเสมอ (เต็มจำนวนหรือบางส่วนก็ได้)
class Refund {
  const Refund({
    required this.id,
    required this.paymentId,
    required this.orderId,
    required this.amount,
    required this.reason,
    this.refundedByName,
    this.createdAt,
  });

  final int id;
  final int paymentId;
  final int orderId;
  final double amount;
  final String reason;
  final String? refundedByName;
  final String? createdAt;
}
