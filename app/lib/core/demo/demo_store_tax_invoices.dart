// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------------------- tax invoices -----
extension DemoStoreTaxInvoices on DemoStore {
  Map<String, dynamic>? _activeTaxInvoiceForOrder(int orderId) {
    for (final invoice in taxInvoices.reversed) {
      if (invoice['orderId'] == orderId && invoice['voidedAt'] == null) {
        return invoice;
      }
    }
    return null;
  }

  Map<String, dynamic> taxInvoiceForOrder(int orderId) {
    findOrder(orderId);
    final invoice = _activeTaxInvoiceForOrder(orderId);
    if (invoice == null) {
      throw ApiException(
        message: 'tax_invoice_error_not_found'.tr,
        statusCode: 404,
      );
    }
    return invoice;
  }

  /// เลขที่ใบกำกับภาษีรูปแบบ INV<ปีพ.ศ. 2 หลัก>-<เลขรัน 6 หลัก> รีเซ็ตทุกปี พ.ศ.
  /// (mirror ของ backend: tax-invoice.service.js#nextRunningNumber)
  String _nextTaxInvoiceRunningNumber() {
    final buddhistYear = AppClock.now().year + 543;
    final yy = buddhistYear.toString().substring(
      buddhistYear.toString().length - 2,
    );
    final prefix = 'INV$yy-';
    final count = taxInvoices
        .where(
          (invoice) => (invoice['runningNumber'] as String).startsWith(prefix),
        )
        .length;
    return '$prefix${(count + 1).toString().padLeft(6, '0')}';
  }

  Map<String, dynamic> issueTaxInvoice(
    int orderId,
    Map<String, dynamic> body, {
    int? issuedById,
  }) {
    final order = findOrder(orderId);
    if (order['status'] != OrderStatus.paid) {
      throw ApiException(
        message: 'tax_invoice_error_not_paid'.tr,
        statusCode: 409,
      );
    }
    if (_activeTaxInvoiceForOrder(orderId) != null) {
      throw ApiException(
        message: 'tax_invoice_error_already_issued'.tr,
        statusCode: 409,
      );
    }

    final storeTaxId = settings['storeTaxId'] as String?;
    final storeAddress = settings['storeAddress'] as String?;
    if (storeTaxId == null ||
        storeTaxId.isEmpty ||
        storeAddress == null ||
        storeAddress.isEmpty) {
      throw ApiException(
        message: 'tax_invoice_error_store_not_configured'.tr,
        statusCode: 400,
      );
    }

    final invoiceType = body['invoiceType'] as String;
    final customerName = body['customerName'] as String?;
    final customerAddress = body['customerAddress'] as String?;
    if (invoiceType == TaxInvoiceType.full &&
        (customerName == null ||
            customerName.trim().isEmpty ||
            customerAddress == null ||
            customerAddress.trim().isEmpty)) {
      throw ApiException(
        message: 'tax_invoice_error_full_requires_customer'.tr,
        statusCode: 422,
      );
    }

    final invoice = {
      'id': _nextId(),
      'orderId': orderId,
      'orderCode': order['code'],
      'runningNumber': _nextTaxInvoiceRunningNumber(),
      'invoiceType': invoiceType,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerTaxId': body['customerTaxId'],
      'storeName': settings['storeName'],
      'storeTaxId': storeTaxId,
      'storeAddress': storeAddress,
      'storeBranch': settings['storeBranch'],
      // ฐานภาษี (ยอดก่อน VAT) ไม่ใช่ order.subtotal — mirror ของ tax-invoice.service.js#issue
      // ดูเหตุผลเต็มที่ docs/DECISIONS.md #43
      'subtotal': DemoStorePayments._roundMoney(
        (order['total'] as num).toDouble() - (order['vat'] as num).toDouble(),
      ),
      'vat': order['vat'],
      'total': order['total'],
      'issuedByName': issuedById == null
          ? null
          : DemoNames.of(_findUser(issuedById)),
      'issuedAt': _now(),
      'isVoid': false,
      'voidedAt': null,
      'voidReason': null,
      'voidedByName': null,
    };
    taxInvoices.add(invoice);
    return invoice;
  }

  Map<String, dynamic> voidTaxInvoice(
    int orderId,
    String reason, {
    int? voidedById,
  }) {
    final invoice = taxInvoiceForOrder(orderId);
    invoice['isVoid'] = true;
    invoice['voidedAt'] = _now();
    invoice['voidReason'] = reason;
    invoice['voidedByName'] = voidedById == null
        ? null
        : DemoNames.of(_findUser(voidedById));

    // mirror ของ tax-invoice.service.js#void — ดู docs/tickets/08-audit-log.md
    final order = findOrder(orderId);
    _logAudit(
      actorId: voidedById,
      action: 'tax_invoice.void',
      summaryArgs: {'number': invoice['runningNumber'], 'code': order['code']},
      entityType: 'tax_invoice',
      entityId: invoice['id'] as int,
      summary:
          'ยกเลิกใบกำกับภาษีเลขที่ ${invoice['runningNumber']} ของออเดอร์ #${order['code']}',
      reason: reason,
      metadata: {
        'orderId': order['id'],
        'orderCode': order['code'],
        'runningNumber': invoice['runningNumber'],
      },
    );

    return invoice;
  }
}
