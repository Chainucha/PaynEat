// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/services/offline_order_queue_service.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../backup/presentation/widgets/backup_warning_banner.dart';
import '../controllers/home_controller.dart';

/// โครงหน้าหลักของแอป
///
/// - มือถือ: แถบเมนูล่าง (หรือลิ้นชักด้านข้างถ้าเมนูเยอะ เช่น บัญชีแอดมิน)
/// - แท็บเล็ต/เว็บ: NavigationRail ด้านซ้าย ขยายเป็นเมนูเต็มบนจอกว้าง
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  static const int _bottomNavLimit = 5;

  @override
  Widget build(BuildContext context) {
    final device = Responsive.of(context);
    final useRail = device != DeviceType.mobile;
    final useDrawer =
        !useRail && controller.destinations.length > _bottomNavLimit;

    return Obx(
      () => Scaffold(
        appBar: AppBar(
          title: Text(controller.currentTitle),
          actions: const [
            _OfflineQueueBadge(),
            SizedBox(width: 4),
            _ConnectionDot(),
            SizedBox(width: 8),
            _UserChip(),
            SizedBox(width: 8),
          ],
        ),
        drawer: useDrawer ? _AppDrawer() : null,
        body: Row(
          children: [
            if (useRail)
              _NavigationRailSection(extended: device == DeviceType.desktop),
            Expanded(
              child: Column(
                children: [
                  // admin และ manager: ไม่ได้สำรองข้อมูลเกิน 26 ชั่วโมงหรือครั้งล่าสุดล้มเหลว (ticket 33)
                  BackupWarningBanner(
                    onOpenSettings: controller.user?.role == UserRole.admin
                        ? controller.openSettings
                        : null,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: controller.currentIndex.value,
                      children: controller.destinations
                          .map((destination) => destination.page)
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: useRail || useDrawer ? null : _BottomNav(),
      ),
    );
  }
}

class _NavigationRailSection extends GetView<HomeController> {
  const _NavigationRailSection({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height - 56,
        ),
        child: IntrinsicHeight(
          child: NavigationRail(
            extended: extended,
            minExtendedWidth: 210,
            backgroundColor: AppColors.surface,
            // เมนูที่เลือกอยู่เดิมเป็นพื้นสีส้มจาง ๆ ซึ่งแทบแยกไม่ออกจากพื้นขาว
            // ใส่ทั้งพื้น indicator และสีไอคอน/ตัวอักษรให้ชัดขึ้น
            indicatorColor: AppColors.primarySoft,
            selectedIconTheme: IconThemeData(color: AppColors.brandInk),
            // NavigationRail ใช้ TextStyle สองตัวนี้ "แทนที่" สไตล์เดิมทั้งก้อน ไม่ได้ merge
            // จึงต้องระบุ fontFamily เองด้วย ไม่งั้นฟอนต์หลุดไปใช้ค่า default ของแพลตฟอร์ม
            // แล้วอักษรไทยจะกลายเป็นกล่องสี่เหลี่ยม (บั๊กเดียวกับที่เคยเจอในปุ่มเดินสถานะ)
            //
            // ต้องใส่ fontFamilyFallback คู่กันเสมอ ไม่ใช่ fontFamily อย่างเดียว —
            // NotoSansThai ไม่มีกลิฟฮันกึลสักตัว ป้ายเมนูภาษาเกาหลีเลยขึ้นเป็น
            // กล่องสี่เหลี่ยมทั้งแถบ ทั้งที่ส่วนอื่นของหน้าเดียวกันแสดงผลปกติ
            // (จับได้ตอนถ่ายภาพ ko-41-tablet-kitchen รอบแรก)
            selectedLabelTextStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontFamilyFallback: AppTheme.fontFamilyFallback,
              color: AppColors.brandInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelTextStyle: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontFamilyFallback: AppTheme.fontFamilyFallback,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            selectedIndex: controller.currentIndex.value,
            onDestinationSelected: controller.changeTab,
            labelType: extended ? null : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: AppColors.brandInk,
                size: extended ? 30 : 26,
              ),
            ),
            destinations: controller.destinations
                .map(
                  (destination) => NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label.tr),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: controller.currentIndex.value,
      onDestinationSelected: controller.changeTab,
      height: 64,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: controller.destinations
          .map(
            (destination) => NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(
                destination.selectedIcon,
                color: AppColors.brandInk,
              ),
              label: destination.label.tr,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AppDrawer extends GetView<HomeController> {
  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: controller.currentIndex.value,
      onDestinationSelected: (index) {
        controller.changeTab(index);
        Get.back<void>();
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
          child: Row(
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                color: AppColors.brandInk,
                size: 26,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_drawer_brand_name'.tr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    controller.user?.roleLabel ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        ...controller.destinations.map(
          (destination) => NavigationDrawerDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label.tr),
          ),
        ),
      ],
    );
  }
}

/// ป้ายแจ้งจำนวนรายการ "สั่งเพิ่มเข้าออเดอร์เดิม" ที่ค้าง sync เพราะเน็ตหลุดตอนกดยืนยัน
/// (ดู OfflineOrderQueueService / docs/DECISIONS.md) — ไม่แสดงอะไรเลยถ้าไม่มีรายการค้าง
class _OfflineQueueBadge extends StatelessWidget {
  const _OfflineQueueBadge();

  @override
  Widget build(BuildContext context) {
    final queue = Get.find<OfflineOrderQueueService>();

    return Obx(() {
      final count = queue.pending.length;
      if (count == 0) return const SizedBox.shrink();

      return Tooltip(
        message: 'home_offline_queue_tooltip'.trParams({
          'count': count.toString(),
        }),
        child: ActionChip(
          avatar: const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: Colors.white,
          ),
          backgroundColor: AppColors.danger,
          label: Text(
            'home_pending_sync_badge'.trParams({'count': count.toString()}),
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          onPressed: () => _showPendingSheet(context, queue),
        ),
      );
    });
  }

  void _showPendingSheet(BuildContext context, OfflineOrderQueueService queue) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'home_offline_queue_sheet_title'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'home_offline_queue_sheet_subtitle'.tr,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...queue.pending.map(
                (entry) => ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(entry.orderLabel),
                  subtitle: Text(entry.summary),
                  trailing: Text(
                    TimeOfDay.fromDateTime(entry.queuedAt).format(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: queue.isSyncing.value ? null : queue.syncNow,
                  child: queue.isSyncing.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : Text('home_sync_now_button'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ไฟบอกสถานะการเชื่อมต่อ socket — ให้พนักงานรู้ทันทีถ้าเน็ตหลุด
///
/// ตอนเชื่อมต่อปกติเป็นแค่จุดเล็ก ๆ ไม่รบกวนสายตา แต่ตอนหลุดจะกลายเป็นป้ายมีข้อความ
/// เพราะบนมือถือ/แท็บเล็ตไม่มี hover ให้เห็น tooltip — ถ้าสื่อด้วยสีของจุด 9px อย่างเดียว
/// พนักงานจะไม่มีวันสังเกตเห็นตอนที่จำเป็นที่สุด
class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot();

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();

    return ValueListenableBuilder<bool>(
      valueListenable: session.socket.connected,
      builder: (context, connected, _) {
        // โหมดสาธิตไม่มีเซิร์ฟเวอร์โดยตั้งใจ จึงไม่ควรขึ้นป้ายเตือนสีแดงค้างไว้
        if (connected || AppConfig.demoMode) {
          return Tooltip(
            message: connected
                ? 'home_connection_online_tooltip'.tr
                : 'home_connection_offline_tooltip'.tr,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: connected ? AppColors.success : AppColors.textDisabled,
                shape: BoxShape.circle,
              ),
            ),
          );
        }

        return Tooltip(
          message: 'home_connection_offline_tooltip'.tr,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  'home_connection_offline_badge'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserChip extends GetView<HomeController> {
  const _UserChip();

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    if (user == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: user.name,
      offset: const Offset(0, 46),
      onSelected: (value) {
        if (value == 'logout') Get.find<AuthController>().signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(user.roleLabel),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.logout_rounded,
              size: 19,
              color: AppColors.dangerInk,
            ),
            title: Text(
              'home_logout_menu_item'.tr,
              style: TextStyle(color: AppColors.dangerInk),
            ),
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.primarySoft,
        child: Text(
          user.initials,
          style: TextStyle(
            color: AppColors.brandInk,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
