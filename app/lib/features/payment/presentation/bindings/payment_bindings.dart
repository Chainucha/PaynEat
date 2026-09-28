// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../../../core/printing/receipt_printer_service.dart';
import '../../../../core/services/printer_settings_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../customer/domain/usecases/customer_usecases.dart';
import '../../../order/domain/usecases/order_usecases.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../../shift/domain/usecases/shift_usecases.dart';
import '../../../tax_invoice/domain/usecases/tax_invoice_usecases.dart';
import '../../domain/usecases/payment_usecases.dart';
import '../controllers/checkout_controller.dart';
import '../controllers/receipt_controller.dart';
import '../controllers/split_bill_controller.dart';

class CheckoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      CheckoutController(
        getOrder: Get.find<GetOrderUseCase>(),
        getSummary: Get.find<GetPaymentSummaryUseCase>(),
        pay: Get.find<PayOrderUseCase>(),
        getCurrentShift: Get.find<GetCurrentShiftUseCase>(),
        getCustomer: Get.find<GetCustomerUseCase>(),
        getSettings: Get.find<GetSettingsUseCase>(),
        getPromptPayQr: Get.find<GetPromptPayQrUseCase>(),
        refundPayment: Get.find<RefundPaymentUseCase>(),
        session: Get.find<SessionService>(),
      ),
    );
  }
}

class ReceiptBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      ReceiptController(
        getReceipt: Get.find<GetReceiptUseCase>(),
        refundPayment: Get.find<RefundPaymentUseCase>(),
        session: Get.find<SessionService>(),
        printerSettings: Get.find<PrinterSettingsService>(),
        printerService: Get.find<ReceiptPrinterService>(),
        getTaxInvoice: Get.find<GetTaxInvoiceUseCase>(),
        issueTaxInvoice: Get.find<IssueTaxInvoiceUseCase>(),
        voidTaxInvoice: Get.find<VoidTaxInvoiceUseCase>(),
      ),
    );
  }
}

class SplitBillBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(
      SplitBillController(
        getOrder: Get.find<GetOrderUseCase>(),
        getSplitPreview: Get.find<GetSplitPreviewUseCase>(),
        pay: Get.find<PayOrderUseCase>(),
      ),
    );
  }
}
