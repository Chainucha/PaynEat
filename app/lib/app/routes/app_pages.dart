// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:get/get.dart';

import '../../features/auth/presentation/pages/branch_selection_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/customer/presentation/bindings/customer_bindings.dart';
import '../../features/customer/presentation/pages/customer_detail_page.dart';
import '../../features/home/presentation/bindings/home_binding.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/ingredient/presentation/pages/ingredient_form_page.dart';
import '../../features/menu/presentation/pages/menu_form_page.dart';
import '../../features/order/presentation/bindings/order_bindings.dart';
import '../../features/order/presentation/pages/order_detail_page.dart';
import '../../features/order/presentation/pages/order_taking_page.dart';
import '../../features/payment/presentation/bindings/payment_bindings.dart';
import '../../features/payment/presentation/pages/checkout_page.dart';
import '../../features/payment/presentation/pages/receipt_page.dart';
import '../../features/payment/presentation/pages/split_bill_page.dart';
import '../../features/promotion/presentation/pages/promotion_form_page.dart';
import '../../features/receivable/presentation/bindings/receivable_bindings.dart';
import '../../features/receivable/presentation/pages/customer_statement_page.dart';
import '../../features/self_order/presentation/bindings/self_order_binding.dart';
import '../../features/self_order/presentation/pages/self_order_page.dart';
import '../../features/shift/presentation/pages/shift_page.dart';
import 'app_routes.dart';
import 'session_guard.dart';

/// ตารางเส้นทางของแอป — ผูก route → หน้าจอ → binding (DI เฉพาะของหน้านั้น)
class AppPages {
  const AppPages._();

  /// หน้าที่เปิดได้โดยไม่ต้องมีเซสชันพนักงาน — ที่เหลือผ่าน [SessionGuard]
  static const _publicRoutes = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.branchSelection,
    AppRoutes.selfOrder,
  };

  static final List<GetPage<dynamic>> pages = [
    for (final page in _routes)
      _publicRoutes.contains(page.name)
          ? page
          : page.copy(middlewares: [SessionGuard()]),
  ];

  static final List<GetPage<dynamic>> _routes = [
    GetPage<void>(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage<void>(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage<void>(
      name: AppRoutes.branchSelection,
      page: () => const BranchSelectionPage(),
    ),
    GetPage<void>(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.newOrder,
      page: () => const OrderTakingPage(),
      binding: OrderTakingBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.orderDetail,
      page: () => const OrderDetailPage(),
      binding: OrderDetailBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.checkout,
      page: () => const CheckoutPage(),
      binding: CheckoutBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.splitBill,
      page: () => const SplitBillPage(),
      binding: SplitBillBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.receipt,
      page: () => const ReceiptPage(),
      binding: ReceiptBinding(),
    ),
    GetPage<void>(name: AppRoutes.menuForm, page: () => const MenuFormPage()),
    GetPage<void>(
      name: AppRoutes.promotionForm,
      page: () => const PromotionFormPage(),
    ),
    GetPage<void>(
      name: AppRoutes.ingredientForm,
      page: () => const IngredientFormPage(),
    ),
    GetPage<void>(name: AppRoutes.shift, page: () => const ShiftPage()),
    GetPage<void>(
      name: AppRoutes.customerDetail,
      page: () => const CustomerDetailPage(),
      binding: CustomerDetailBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.customerStatement,
      page: () => const CustomerStatementPage(),
      binding: CustomerStatementBinding(),
    ),
    // ลูกค้าสแกน QR เข้ามาตรงนี้ — ไม่มี login gate ใดๆ เลย (ดู docs/tickets/17-qr-self-order.md)
    GetPage<void>(
      name: AppRoutes.selfOrder,
      page: () => const SelfOrderPage(),
      binding: SelfOrderBinding(),
    ),
  ];
}
