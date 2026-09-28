// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:payneat_pos/core/constants/app_constants.dart';
import 'package:payneat_pos/features/auth/domain/entities/user.dart';
import 'package:payneat_pos/features/order/domain/entities/order.dart';
import 'package:payneat_pos/features/order/domain/entities/order_item.dart';
import 'package:payneat_pos/features/order/data/models/order_model.dart';
import 'package:payneat_pos/features/payment/data/models/payment_model.dart';
import 'package:payneat_pos/features/table/domain/entities/dining_table.dart';

void main() {
  group('User (สิทธิ์ตามบทบาท)', () {
    User userWith(String role) => User(
      id: 1,
      name: 'ทดสอบ',
      username: 'test',
      role: role,
      isActive: true,
    );

    test('แอดมินและผู้จัดการมีสิทธิ์ระดับบริหาร', () {
      expect(userWith(UserRole.admin).isManagement, isTrue);
      expect(userWith(UserRole.manager).isManagement, isTrue);
      expect(userWith(UserRole.waiter).isManagement, isFalse);
    });

    test('ครัวไม่มีสิทธิ์รับออเดอร์หรือเก็บเงิน', () {
      final kitchen = userWith(UserRole.kitchen);

      expect(kitchen.isKitchen, isTrue);
      expect(kitchen.canTakeOrder, isFalse);
      expect(kitchen.canCollectPayment, isFalse);
      expect(kitchen.canSeeReports, isFalse);
    });

    test('ตัวย่อใน avatar มาจากอักษรตัวแรกของชื่อ', () {
      expect(userWith(UserRole.waiter).initials, 'ท');
    });
  });

  group('OrderItem (การเดินสถานะ)', () {
    OrderItem itemWith(String status) => OrderItem(
      id: 1,
      orderId: 1,
      name: 'ผัดกะเพรา',
      unitPrice: 75,
      quantity: 1,
      lineTotal: 75,
      status: status,
    );

    test('สถานะเดินตามลำดับ รอทำ → กำลังทำ → พร้อมเสิร์ฟ → เสิร์ฟแล้ว', () {
      expect(
        itemWith(OrderItemStatus.pending).nextStatus,
        OrderItemStatus.cooking,
      );
      expect(
        itemWith(OrderItemStatus.cooking).nextStatus,
        OrderItemStatus.ready,
      );
      expect(
        itemWith(OrderItemStatus.ready).nextStatus,
        OrderItemStatus.served,
      );
      expect(itemWith(OrderItemStatus.served).nextStatus, isNull);
    });

    test('แก้ไขได้เฉพาะรายการที่ครัวยังไม่เริ่มทำ', () {
      expect(itemWith(OrderItemStatus.pending).isEditable, isTrue);
      expect(itemWith(OrderItemStatus.cooking).isEditable, isFalse);
    });

    test(
      'ครัวเคยทำแล้วถูกเลิกทำกลับไปรอทำ ยังนับว่าเริ่มทำแล้ว แก้/ลบไม่ได้ (T05 #104)',
      () {
        final undone = OrderItemModel.fromJson({
          'id': 1,
          'name': 'ผัดกะเพรา',
          'status': OrderItemStatus.pending,
          'kitchenReached': OrderItemStatus.ready,
        });
        expect(undone.kitchenReached, OrderItemStatus.ready);
        expect(undone.kitchenStarted, isTrue);
        expect(undone.isEditable, isFalse);

        final untouched = OrderItemModel.fromJson({
          'id': 2,
          'name': 'ผัดกะเพรา',
          'status': OrderItemStatus.pending,
          'kitchenReached': null,
        });
        expect(untouched.kitchenStarted, isFalse);
        expect(untouched.isEditable, isTrue);
      },
    );
  });

  group('Order', () {
    Order orderWith({
      required String status,
      List<OrderItem> items = const [],
    }) => Order(
      id: 1,
      code: 'ORD-20260101-0001',
      type: OrderType.dineIn,
      status: status,
      subtotal: 100,
      total: 117.7,
      tableName: 'A1',
      items: items,
    );

    final activeItem = OrderItem(
      id: 1,
      orderId: 1,
      name: 'ผัดกะเพรา',
      unitPrice: 75,
      quantity: 2,
      lineTotal: 150,
      status: OrderItemStatus.pending,
    );
    final cancelledItem = OrderItem(
      id: 2,
      orderId: 1,
      name: 'ต้มยำ',
      unitPrice: 220,
      quantity: 1,
      lineTotal: 220,
      status: OrderItemStatus.cancelled,
    );

    test('ไม่นับรายการที่ยกเลิกเป็นจำนวนรายการในบิล', () {
      final order = orderWith(
        status: OrderStatus.open,
        items: [activeItem, cancelledItem],
      );

      expect(order.activeItems.length, 1);
      expect(order.totalQuantity, 2);
    });

    test('ส่งครัวได้เฉพาะออเดอร์ที่ยังไม่ส่งและมีรายการอาหาร', () {
      expect(
        orderWith(
          status: OrderStatus.open,
          items: [activeItem],
        ).canSendToKitchen,
        isTrue,
      );
      expect(orderWith(status: OrderStatus.open).canSendToKitchen, isFalse);
      expect(
        orderWith(
          status: OrderStatus.inKitchen,
          items: [activeItem],
        ).canSendToKitchen,
        isFalse,
      );
    });
  });

  group('DiningTable', () {
    test('โต๊ะที่มีออเดอร์เปิดอยู่ต้องรายงานว่ามีบิลค้าง', () {
      const table = DiningTable(
        id: 1,
        name: 'A1',
        zone: 'โซนในร้าน',
        seats: 4,
        status: TableStatus.occupied,
        currentOrder: TableOrderSummary(
          id: 9,
          code: 'ORD-1',
          status: OrderStatus.inKitchen,
          total: 500,
        ),
      );

      expect(table.hasOpenOrder, isTrue);
      expect(table.isAvailable, isFalse);
      expect(table.statusLabel, 'มีลูกค้า');
    });
  });

  group('PaymentSummary (T06 #82)', () {
    test('อ่านยอดคืนเงินจาก backend และรวมยอดที่คืนแล้วแยกตาม payment', () {
      final summary = PaymentSummaryModel.fromJson({
        'orderId': 1,
        'total': 100.05,
        'paid': 30,
        'refunded': 70,
        'remaining': 70.05,
        'payments': [
          {'id': 1, 'orderId': 1, 'method': 'cash', 'amount': 50},
          {'id': 2, 'orderId': 1, 'method': 'qr', 'amount': 50},
        ],
        'refunds': [
          {'id': 9, 'paymentId': 1, 'orderId': 1, 'amount': 50, 'reason': 'a'},
          {'id': 10, 'paymentId': 2, 'orderId': 1, 'amount': 20, 'reason': 'b'},
        ],
      });
      expect(summary.paid, 30);
      expect(summary.refunded, 70);
      expect(summary.remaining, 70.05);
      expect(summary.refundedFor(1), 50);
      expect(summary.refundedFor(2), 20);
      expect(summary.refundedFor(3), 0);
      expect(summary.isPartiallyPaid, isTrue);
    });

    test('backend รุ่นเก่าที่ยังไม่ส่งยอดคืนเงิน → ถือว่าไม่มีการคืน', () {
      final summary = PaymentSummaryModel.fromJson({
        'orderId': 1,
        'total': 100,
        'paid': 0,
        'remaining': 100,
      });
      expect(summary.refunded, 0);
      expect(summary.refunds, isEmpty);
    });
  });
}
