// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import '../../domain/entities/payment.dart';

class PaymentModel extends Payment {
  const PaymentModel({
    required super.id,
    required super.orderId,
    required super.method,
    required super.amount,
    super.received,
    super.change,
    super.reference,
    super.cashierName,
    super.createdAt,
    super.pointsRedeemed,
    super.pointsRedeemedValue,
    super.dueDate,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: (json['id'] as num?)?.toInt() ?? 0,
    orderId: (json['orderId'] as num?)?.toInt() ?? 0,
    method: json['method'] as String? ?? 'cash',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    received: (json['received'] as num?)?.toDouble() ?? 0,
    change: (json['change'] as num?)?.toDouble() ?? 0,
    reference: json['reference'] as String?,
    cashierName: json['cashierName'] as String?,
    createdAt: json['createdAt'] as String?,
    pointsRedeemed: (json['pointsRedeemed'] as num?)?.toInt() ?? 0,
    pointsRedeemedValue: (json['pointsRedeemedValue'] as num?)?.toDouble() ?? 0,
    dueDate: json['dueDate'] as String?,
  );
}

class PaymentSummaryModel extends PaymentSummary {
  const PaymentSummaryModel({
    required super.orderId,
    required super.total,
    required super.paid,
    required super.remaining,
    super.refunded,
    super.payments,
    super.refunds,
  });

  factory PaymentSummaryModel.fromJson(Map<String, dynamic> json) =>
      PaymentSummaryModel(
        orderId: (json['orderId'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        paid: (json['paid'] as num?)?.toDouble() ?? 0,
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
        refunded: (json['refunded'] as num?)?.toDouble() ?? 0,
        payments: (json['payments'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PaymentModel.fromJson)
            .toList(growable: false),
        refunds: (json['refunds'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RefundModel.fromJson)
            .toList(growable: false),
      );
}

class PromptPayQrModel extends PromptPayQr {
  const PromptPayQrModel({
    required super.payload,
    required super.promptPayId,
    super.amount,
  });

  factory PromptPayQrModel.fromJson(Map<String, dynamic> json) =>
      PromptPayQrModel(
        payload: json['payload'] as String? ?? '',
        promptPayId: json['promptPayId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble(),
      );
}

class RefundModel extends Refund {
  const RefundModel({
    required super.id,
    required super.paymentId,
    required super.orderId,
    required super.amount,
    required super.reason,
    super.refundedByName,
    super.createdAt,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) => RefundModel(
    id: (json['id'] as num?)?.toInt() ?? 0,
    paymentId: (json['paymentId'] as num?)?.toInt() ?? 0,
    orderId: (json['orderId'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    reason: json['reason'] as String? ?? '',
    refundedByName: json['refundedByName'] as String?,
    createdAt: json['createdAt'] as String?,
  );
}

class SplitPreviewModel extends SplitPreview {
  const SplitPreviewModel({
    required super.orderId,
    required super.itemIds,
    required super.subtotal,
    required super.discountAmount,
    required super.serviceCharge,
    required super.vat,
    required super.total,
    required super.remaining,
    required super.isLastBatch,
  });

  factory SplitPreviewModel.fromJson(Map<String, dynamic> json) =>
      SplitPreviewModel(
        orderId: (json['orderId'] as num?)?.toInt() ?? 0,
        itemIds: (json['itemIds'] as List? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(growable: false),
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
        serviceCharge: (json['serviceCharge'] as num?)?.toDouble() ?? 0,
        vat: (json['vat'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
        isLastBatch: json['isLastBatch'] as bool? ?? false,
      );
}
