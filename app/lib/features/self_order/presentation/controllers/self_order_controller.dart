// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'package:get/get.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/widgets/app_dialogs.dart';
import '../../../menu/domain/entities/category.dart';
import '../../../menu/domain/entities/menu_item.dart';
import '../../../order/domain/entities/cart_line.dart';
import '../../../order/domain/entities/order.dart';
import '../../../order/domain/entities/order_item_payload.dart';
import '../../../order/presentation/widgets/option_selection_sheet.dart';
import '../../domain/entities/self_order_table.dart';
import '../../domain/self_order_limits.dart';
import '../../domain/self_order_link.dart';
import '../../domain/usecases/add_self_order_items_usecase.dart';
import '../../domain/usecases/get_self_order_menu_usecase.dart';
import '../../domain/usecases/get_self_order_table_usecase.dart';

/// คุมหน้าสั่งอาหารเองผ่าน QR ทั้งหน้า (ดู docs/tickets/17-qr-self-order.md) — ไม่พึ่ง
/// SessionService/AuthController เลยแม้แต่น้อย เพราะลูกค้าไม่ได้ login
class SelfOrderController extends GetxController {
  SelfOrderController({
    required GetSelfOrderTableUseCase getTableUseCase,
    required GetSelfOrderMenuUseCase getMenuUseCase,
    required AddSelfOrderItemsUseCase addItemsUseCase,
  }) : _getTable = getTableUseCase,
       _getMenu = getMenuUseCase,
       _addItems = addItemsUseCase;

  final GetSelfOrderTableUseCase _getTable;
  final GetSelfOrderMenuUseCase _getMenu;
  final AddSelfOrderItemsUseCase _addItems;

  late final String qrToken;

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  /// ลิงก์/โต๊ะใช้ไม่ได้จริง ๆ (ไม่ใช่เน็ตสะดุด) — กดลองใหม่กี่ครั้งก็ไม่มีวันสำเร็จ หน้าจอจึงต้อง
  /// เปลี่ยนไอคอนและซ่อนปุ่มลองใหม่ ไม่งั้นลูกค้าจะนึกว่าเน็ตตัวเองมีปัญหาแล้วกดวนอยู่อย่างนั้น
  final RxBool isLinkProblem = false.obs;
  final Rxn<SelfOrderTable> table = Rxn<SelfOrderTable>();
  final Rxn<Order> currentOrder = Rxn<Order>();
  final RxList<Category> categories = <Category>[].obs;
  final RxList<MenuItem> items = <MenuItem>[].obs;

  /// เมนูที่มีขายแต่ลูกค้าสั่งเองไม่ได้ (ขายตามน้ำหนัก ต้องให้พนักงานชั่ง) — เดิมหายไปจากเมนูเฉย ๆ
  /// ลูกค้าที่เห็นเนื้อสดในตู้แต่หาในเมนูไม่เจอไม่รู้ว่าต้องทำยังไง (DECISIONS #64)
  final RxInt staffOnlyCount = 0.obs;
  final RxnInt selectedCategoryId = RxnInt();

  /// จำนวนสูงสุดต่อรายการที่สั่งผ่าน QR ได้ ตามที่ร้านตั้งไว้ใน backend (DECISIONS #99) — ปุ่ม + ทุกจุด
  /// ในหน้านี้หยุดที่ค่านี้ ลูกค้าจึงไม่ต้องรอส่งแล้วโดนปฏิเสธ
  final RxInt maxQuantityPerLine = defaultSelfOrderMaxQuantityPerLine.obs;

  final RxList<CartLine> cart = <CartLine>[].obs;
  final RxBool isSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    // route ลงทะเบียนเป็น /order/:qrToken (ดู app_routes.dart/app_pages.dart) — อ่านครั้งเดียว
    // ตอนสร้าง controller เพราะหน้านี้ผูกกับโต๊ะเดียวตลอดอายุของมัน ไม่มีการเปลี่ยนโต๊ะกลางคัน
    qrToken = Get.parameters['qrToken'] ?? '';
    load();
  }

  List<MenuItem> get filteredItems {
    final categoryId = selectedCategoryId.value;
    if (categoryId == null) return items;
    return items
        .where((item) => item.categoryId == categoryId)
        .toList(growable: false);
  }

  int get cartItemCount => cart.fold(0, (sum, line) => sum + line.quantity);

  double get cartSubtotalPreview =>
      cart.fold(0.0, (sum, line) => sum + line.lineTotal);

  Future<void> load() async {
    if (qrToken.isEmpty) {
      errorMessage.value = 'self_order_invalid_link'.tr;
      isLinkProblem.value = true;
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;
    isLinkProblem.value = false;

    final tableResult = await _getTable(qrToken);
    final failure = tableResult.failureOrNull;
    if (failure != null) {
      errorMessage.value = failure.message;
      // ลิงก์เสีย (404 หรือรูปแบบ token ผิด) ลองใหม่ไม่มีวันสำเร็จ — ต่างจาก error อื่นที่ลองใหม่ได้
      isLinkProblem.value = isBrokenSelfOrderLink(failure);
      isLoading.value = false;
      return;
    }

    final tableData = tableResult.dataOrNull!;
    table.value = tableData.table;
    currentOrder.value = tableData.order;

    final menuResult = await _getMenu(qrToken);
    menuResult.fold(
      onSuccess: (data) {
        categories.assignAll(data.categories);
        items.assignAll(data.items);
        staffOnlyCount.value = data.staffOnlyCount;
        maxQuantityPerLine.value = data.maxQuantityPerLine;
      },
      onFailure: (menuFailure) => errorMessage.value = menuFailure.message,
    );

    isLoading.value = false;
  }

  void selectCategory(int? categoryId) => selectedCategoryId.value = categoryId;

  /// มีตัวเลือกให้เลือก → เปิดแผ่นเลือกก่อน, ไม่มี → ใส่ตะกร้าเลย 1 ที่ (ดู
  /// order_taking_page.dart#_addToCart — ตรรกะเดียวกัน)
  Future<void> addToCart(MenuItem item) async {
    if (!item.requiresSelection) {
      _addLine(CartLine(menuItem: item));
      return;
    }

    final result = await OptionSelectionSheet.show(
      item,
      maxQuantity: maxQuantityPerLine.value,
    );
    if (result == null) return;
    final note = result.note?.trim();
    _addLine(
      CartLine(
        menuItem: item,
        quantity: result.quantity,
        selectedOptions: result.options,
        note: (note?.isEmpty ?? true) ? null : note,
      ),
    );
  }

  /// รายการนี้ถึงเพดานต่อรายการของ QR แล้ว — หน้าตะกร้าบอกให้เรียกพนักงานถ้าต้องการมากกว่านี้
  bool isAtLineLimit(CartLine line) =>
      line.quantity >= maxQuantityPerLine.value;

  /// รวมบรรทัดที่เมนู/ตัวเลือก/โน้ตเหมือนกันเข้าด้วยกันแทนที่จะขึ้นบรรทัดใหม่ซ้ำ ๆ — กฎเดียวกับ
  /// ตะกร้าฝั่งพนักงาน (CartController.addItem) เพราะลูกค้ากดการ์ดเมนูเดิมซ้ำเป็นเรื่องปกติ
  /// ยอดรวมของบรรทัดหยุดที่เพดานต่อรายการ (กดการ์ดเมนูเดิมซ้ำเกินเพดานแล้วจำนวนไม่เพิ่ม)
  void _addLine(CartLine candidate) {
    final max = maxQuantityPerLine.value;
    final index = cart.indexWhere(
      (line) => line.signature == candidate.signature,
    );
    if (index >= 0) {
      cart[index].quantity = math.min(
        max,
        cart[index].quantity + candidate.quantity,
      );
      cart.refresh();
    } else {
      candidate.quantity = math.min(max, candidate.quantity);
      cart.add(candidate);
    }
  }

  /// ลดเหลือ 0 = เอาออกจากตะกร้า (ปุ่ม − ที่จำนวน 1 จึงลบบรรทัดทิ้งไปเลย ไม่ต้องหาปุ่มลบแยก)
  void updateCartQuantity(int index, int quantity) {
    if (index < 0 || index >= cart.length) return;
    if (quantity <= 0) {
      cart.removeAt(index);
      return;
    }
    cart[index].quantity = math.min(quantity, maxQuantityPerLine.value);
    cart.refresh();
  }

  void removeCartLine(int index) => cart.removeAt(index);

  Future<void> submitCart() async {
    if (cart.isEmpty || isSubmitting.value) return;

    isSubmitting.value = true;
    final result = await _addItems(
      AddSelfOrderItemsParams(
        qrToken: qrToken,
        items: cart
            .map(
              (line) => OrderItemPayload(
                menuItemId: line.menuItem.id,
                quantity: line.quantity,
                optionIds: line.optionIds,
                note: line.note,
              ),
            )
            .toList(growable: false),
      ),
    );
    isSubmitting.value = false;

    result.fold(
      onSuccess: (order) {
        currentOrder.value = order;
        cart.clear();
        AppDialogs.success('self_order_submit_success'.tr);
      },
      onFailure: (failure) => AppDialogs.error(submitErrorMessage(failure)),
    );
  }

  /// ข้อความที่ลูกค้าเห็นเมื่อส่งไม่สำเร็จ — เกินเพดานของ QR (DECISIONS #99) เป็นกติกาของร้าน ไม่ใช่
  /// ระบบขัดข้องที่ต้องแจ้งรหัสคำขอให้ใคร จึงตัดบรรทัดรหัสคำขอที่ failure_mapper ต่อท้ายไว้ออก ให้ลูกค้า
  /// เห็นแค่ข้อความของร้าน error อื่นแสดงตามเดิมทุกตัวอักษร
  static String submitErrorMessage(Failure failure) {
    if (failure is ServerFailure && isSelfOrderLimit(failure)) {
      final suffix = withRequestId('', failure.requestId);
      if (suffix.isNotEmpty && failure.message.endsWith(suffix)) {
        return failure.message.substring(
          0,
          failure.message.length - suffix.length,
        );
      }
    }
    return failure.message;
  }
}
