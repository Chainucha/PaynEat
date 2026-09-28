// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/localization/app_translations.dart';
import 'package:payneat_pos/core/localization/locale_service.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/erp_connection/domain/entities/erp_connection_status.dart';
import 'package:payneat_pos/features/erp_connection/domain/repositories/erp_connection_repository.dart';
import 'package:payneat_pos/features/erp_connection/domain/usecases/erp_connection_usecases.dart';
import 'package:payneat_pos/features/erp_connection/presentation/controllers/erp_connection_controller.dart';
import 'package:payneat_pos/features/erp_connection/presentation/widgets/erp_connection_card.dart';

/// หน้าตั้งค่าการเชื่อมต่อ ERP บอกช่องทางของ credential (docs/tickets/32-erp-https-only.md):
/// http ที่ผู้ดูแลเซิร์ฟเวอร์อนุญาตด้วย ERP_ALLOW_INSECURE_HTTP เตือนถาวร, http เดิมที่ถูกหยุดบอกให้เปลี่ยนเป็น https
class _StatusRepository implements ErpConnectionRepository {
  _StatusRepository(this.status);

  final ErpConnectionStatus status;

  @override
  Future<Result<ErpConnectionStatus>> getStatus() async =>
      Result.success(status);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ErpConnectionStatus _connectedVia(ErpTransport transport, String erpUrl) =>
    ErpConnectionStatus(
      mode: ErpMode.connected,
      connection: ErpConnectionInfo(
        erpUrl: erpUrl,
        instanceCode: 'POS-SUKHUMVIT-1',
        instanceName: 'Front counter',
        contractVersion: '1.0.0',
        appliedVersion: 7,
        pullStopped: transport == ErpTransport.insecureBlocked,
        lastError: transport == ErpTransport.insecureBlocked
            ? const ErpPullError(
                kind: 'insecure_transport',
                reason: 'unexpected_response',
              )
            : null,
        transport: transport,
      ),
    );

void main() {
  tearDown(Get.reset);

  Future<void> pumpCard(
    WidgetTester tester,
    ErpConnectionStatus status, {
    Locale locale = LocaleService.thai,
  }) async {
    final repository = _StatusRepository(status);
    Get.put(
      ErpConnectionController(
        getStatus: GetErpStatusUseCase(repository),
        connect: ConnectErpUseCase(repository),
        disconnect: DisconnectErpUseCase(repository),
        pullNow: PullErpNowUseCase(repository),
        updateBranchCode: UpdateBranchCodeUseCase(repository),
        createServedBranch: CreateServedBranchUseCase(repository),
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: locale,
        home: const Scaffold(
          body: SingleChildScrollView(child: ErpConnectionCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final warning = find.byKey(const ValueKey('erp-transport-warning'));

  ButtonStyleButton button(WidgetTester tester, String label) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

  testWidgets('https → ไม่มีกรอบเตือน', (tester) async {
    await pumpCard(
      tester,
      _connectedVia(ErpTransport.https, 'https://erp.example.com'),
    );
    expect(warning, findsNothing);
    expect(button(tester, 'erp_pull_button'.tr).onPressed, isNotNull);
  });

  testWidgets('http ไปเครื่องเดียวกัน (localhost) → ไม่มีกรอบเตือน', (
    tester,
  ) async {
    await pumpCard(
      tester,
      _connectedVia(ErpTransport.loopback, 'http://localhost:3000'),
    );
    expect(warning, findsNothing);
  });

  for (final locale in [
    LocaleService.thai,
    LocaleService.english,
    LocaleService.korean,
  ]) {
    testWidgets(
      '${locale.languageCode}: http ที่ผู้ดูแลเซิร์ฟเวอร์อนุญาต → กรอบเตือนสีแดงถาวรบอกชื่อค่าตั้ง และยังดึงได้',
      (tester) async {
        await pumpCard(
          tester,
          _connectedVia(ErpTransport.insecureAllowed, 'http://erp:3000'),
          locale: locale,
        );
        expect(warning, findsOneWidget);
        expect(
          find.descendant(
            of: warning,
            matching: find.text('erp_transport_insecure_allowed_title'.tr),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: warning,
            matching: find.textContaining('ERP_ALLOW_INSECURE_HTTP=true'),
          ),
          findsOneWidget,
        );
        expect(button(tester, 'erp_pull_button'.tr).onPressed, isNotNull);
      },
    );
  }

  testWidgets(
    'http เดิมที่ถูกหยุด → บอกให้เปลี่ยน มีช่องที่อยู่ให้แก้ และปุ่มที่ต้องเรียก ERP กดไม่ได้',
    (tester) async {
      await pumpCard(
        tester,
        _connectedVia(ErpTransport.insecureBlocked, 'http://erp.lan:3000'),
      );
      expect(
        find.descendant(
          of: warning,
          matching: find.text('erp_transport_insecure_blocked_title'.tr),
        ),
        findsOneWidget,
      );
      // ข้อความเรื่องหยุดดึง/ดึงล้มซ้ำกับกรอบเตือน จึงไม่แสดง
      expect(find.text('erp_pull_stopped_note'.tr), findsNothing);
      expect(find.text('erp_last_error_insecure_transport'.tr), findsNothing);

      final urlField = find.widgetWithText(TextField, 'erp_url_label'.tr);
      expect(urlField, findsOneWidget);
      expect(
        tester.widget<TextField>(urlField).controller!.text,
        'http://erp.lan:3000',
        reason: 'แก้จากที่อยู่เดิมได้เลย',
      );
      expect(find.text('erp_save_address_button'.tr), findsOneWidget);
      expect(button(tester, 'erp_pull_button'.tr).onPressed, isNull);
      expect(find.text('erp_change_credential_button'.tr), findsNothing);
    },
  );
}
