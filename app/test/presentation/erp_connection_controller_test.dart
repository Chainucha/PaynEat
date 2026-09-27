// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:payneat_pos/core/demo/demo_data_sources.dart';
import 'package:payneat_pos/core/errors/failures.dart';
import 'package:payneat_pos/core/usecases/result.dart';
import 'package:payneat_pos/features/erp_connection/data/models/erp_connection_status_model.dart';
import 'package:payneat_pos/features/erp_connection/data/repositories/erp_connection_repository_impl.dart';
import 'package:payneat_pos/features/erp_connection/domain/entities/erp_connection_status.dart';
import 'package:payneat_pos/features/erp_connection/domain/repositories/erp_connection_repository.dart';
import 'package:payneat_pos/features/erp_connection/domain/usecases/erp_connection_usecases.dart';
import 'package:payneat_pos/features/erp_connection/presentation/controllers/erp_connection_controller.dart';
import 'package:payneat_pos/features/erp_connection/presentation/erp_unit_label.dart';

/// หน้าตั้งค่าการเชื่อมต่อ PaynEat ERP (ticket 25) — ทุกผลลัพธ์แสดงเป็นข้อความในการ์ด
/// (actionError/actionNotice) จึงทดสอบได้โดยไม่ต้องมี GetMaterialApp
class _FakeErpRepository implements ErpConnectionRepository {
  final statusResults = <Result<ErpConnectionStatus>>[];
  Result<ErpConnectionStatus> connectResult = const Result.success(_connected);
  Result<ErpConnectionStatus> disconnectResult = const Result.success(
    _standalone,
  );
  Result<ErpPullOutcome> pullResult = const Result.success(
    ErpPullOutcome(applied: 4, skipped: 1, status: _connected),
  );
  Result<void> branchCodeResult = const Result.success(null);
  Result<ErpConnectionStatus> createBranchResult = const Result.success(
    _withSilom,
  );

  int statusCalls = 0;
  final connectCalls = <(String, String)>[];
  final branchCodeCalls = <(int, String)>[];
  final createBranchCalls = <String>[];

  @override
  Future<Result<ErpConnectionStatus>> getStatus() async {
    statusCalls += 1;
    return statusResults.isEmpty
        ? const Result.success(_standalone)
        : statusResults.removeAt(0);
  }

  @override
  Future<Result<ErpConnectionStatus>> connect({
    required String erpUrl,
    required String credential,
  }) async {
    connectCalls.add((erpUrl, credential));
    return connectResult;
  }

  @override
  Future<Result<ErpConnectionStatus>> disconnect() async => disconnectResult;

  @override
  Future<Result<ErpPullOutcome>> pullNow() async => pullResult;

  @override
  Future<Result<ErpConnectionStatus>> createServedBranch(String code) async {
    createBranchCalls.add(code);
    return createBranchResult;
  }

  @override
  Future<Result<void>> updateBranchCode(int branchId, String code) async {
    branchCodeCalls.add((branchId, code));
    return branchCodeResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _standalone = ErpConnectionStatus(
  mode: ErpMode.standalone,
  branches: [
    ErpBranchCheck(
      id: 1,
      name: 'สาขาสุขุมวิท',
      code: 'SUKHUMVIT',
      isActive: true,
    ),
  ],
);

const _connected = ErpConnectionStatus(
  mode: ErpMode.connected,
  connection: ErpConnectionInfo(
    erpUrl: 'https://erp.example.com',
    instanceCode: 'POS-SUKHUMVIT-1',
    instanceName: 'Front counter',
    contractVersion: '1.0.0',
    appliedVersion: 12,
    latestVersion: 12,
  ),
);

const _silom = ErpServedBranch(
  code: 'SILOM',
  nameTh: 'สาขาสีลม',
  nameEn: 'Silom',
  isActive: true,
);

/// หลังสร้างสาขา: ชื่อตามที่ ERP เพิ่งเปลี่ยน (ดึงก่อนสร้าง) ไม่ใช่ชื่อในรายการที่แอปถืออยู่
const _withSilom = ErpConnectionStatus(
  mode: ErpMode.connected,
  connection: ErpConnectionInfo(
    erpUrl: 'https://erp.example.com',
    instanceCode: 'POS-SUKHUMVIT-1',
    instanceName: 'Front counter',
    contractVersion: '1.0.0',
    appliedVersion: 16,
  ),
  branches: [
    ErpBranchCheck(
      id: 7,
      name: 'สาขาสีลม คอมเพล็กซ์',
      code: 'SILOM',
      isActive: true,
      servedByErp: true,
    ),
  ],
);

const _credential = 'pnepos_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefg';

ErpConnectionController _controllerFor(ErpConnectionRepository repository) =>
    ErpConnectionController(
      getStatus: GetErpStatusUseCase(repository),
      connect: ConnectErpUseCase(repository),
      disconnect: DisconnectErpUseCase(repository),
      pullNow: PullErpNowUseCase(repository),
      updateBranchCode: UpdateBranchCodeUseCase(repository),
      createServedBranch: CreateServedBranchUseCase(repository),
    );

void main() {
  late _FakeErpRepository repository;
  late ErpConnectionController controller;

  setUp(() {
    repository = _FakeErpRepository();
    controller = _controllerFor(repository);
  });

  tearDown(() => controller.onClose());

  group('ErpConnectionController', () {
    test('load ใช้งานเดี่ยว → ไม่มีการเชื่อมต่อ ไม่มีสาขาต้องแก้', () async {
      await controller.load();

      expect(controller.status.value.isConnected, isFalse);
      expect(controller.status.value.branchesToFix, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.lastPullProblem, isNull);
    });

    test(
      'เชื่อมต่อได้ต่อเมื่อกรอกที่อยู่ credential ขึ้นต้น pnepos_ และรหัสสาขาถูกหมด',
      () async {
        await controller.connect();
        expect(controller.actionError.value, 'erp_error_url_required'.tr);

        controller.urlController.text = 'https://erp.example.com';
        controller.credentialController.text = 'secret';
        await controller.connect();
        expect(controller.actionError.value, 'erp_error_credential_format'.tr);

        repository.statusResults.add(
          const Result.success(
            ErpConnectionStatus(
              mode: ErpMode.standalone,
              branches: [
                ErpBranchCheck(
                  id: 2,
                  name: 'สาขาทองหล่อ',
                  code: 'thonglor',
                  isActive: true,
                  codeProblem: BranchCodeProblem.invalid,
                ),
              ],
            ),
          ),
        );
        await controller.load();
        controller.credentialController.text = _credential;
        await controller.connect();
        expect(controller.actionError.value, 'erp_error_fix_branch_codes'.tr);
        expect(repository.connectCalls, isEmpty, reason: 'ยังไม่เรียก ERP เลย');
      },
    );

    test(
      'เชื่อมต่อสำเร็จ → ล้าง credential ในช่องทันที และบอกว่าเชื่อมต่อในนามอะไร',
      () async {
        await controller.load();
        controller.urlController.text = '  https://erp.example.com ';
        controller.credentialController.text = ' $_credential ';

        await controller.connect();

        expect(repository.connectCalls.single, (
          'https://erp.example.com',
          _credential,
        ));
        expect(controller.credentialController.text, isEmpty);
        expect(controller.status.value.isConnected, isTrue);
        expect(controller.actionError.value, isNull);
        expect(
          controller.actionNotice.value,
          'erp_connected_notice'.trParams({'instance': 'POS-SUKHUMVIT-1'}),
        );
      },
    );

    test(
      'รหัสสาขาไม่ผ่านที่ backend → แสดงเหตุผลและโหลดรายการสาขาใหม่',
      () async {
        await controller.load();
        controller.urlController.text = 'https://erp.example.com';
        controller.credentialController.text = _credential;
        repository.connectResult = const Result.failure(
          ServerFailure(
            'แก้รหัสสาขาให้ตรงรูปแบบก่อนเชื่อมต่อ PaynEat ERP',
            statusCode: 409,
            code: 'BRANCH_CODES_INVALID',
          ),
        );
        final callsBefore = repository.statusCalls;

        await controller.connect();

        expect(
          controller.actionError.value,
          'แก้รหัสสาขาให้ตรงรูปแบบก่อนเชื่อมต่อ PaynEat ERP',
        );
        expect(repository.statusCalls, callsBefore + 1);
        expect(
          controller.credentialController.text,
          _credential,
          reason: 'ล้มแล้วไม่ต้องพิมพ์ credential ใหม่',
        );
      },
    );

    test(
      '422 ที่มีรายละเอียดช่องกรอก → แสดงข้อความของช่อง ไม่ใช่ข้อความรวม',
      () async {
        await controller.load();
        controller.urlController.text = 'ftp://erp';
        controller.credentialController.text = _credential;
        repository.connectResult = const Result.failure(
          ValidationFailure(
            'ข้อมูลที่ส่งมาไม่ถูกต้อง',
            details: [
              FieldError(field: 'erpUrl', message: 'ที่อยู่ต้องเป็น http(s)'),
            ],
          ),
        );

        await controller.connect();

        expect(controller.actionError.value, 'ที่อยู่ต้องเป็น http(s)');
      },
    );

    test(
      'ดึงทันที → บอกจำนวนและเวอร์ชัน; ล้มเหลว → บอกเหตุผลและโหลดสถานะใหม่',
      () async {
        await controller.pullNow();
        expect(
          controller.actionNotice.value,
          'erp_pulled_notice'.trParams({'count': '4', 'version': '12'}),
        );

        repository.pullResult = const Result.failure(
          ServerFailure('ติดต่อ PaynEat ERP ไม่ได้', statusCode: 502),
        );
        final callsBefore = repository.statusCalls;
        await controller.pullNow();
        expect(controller.actionError.value, 'ติดต่อ PaynEat ERP ไม่ได้');
        expect(controller.actionNotice.value, isNull);
        expect(repository.statusCalls, callsBefore + 1);
      },
    );

    test('ออกจากโหมดเชื่อมต่อ → กลับเป็นใช้งานเดี่ยว', () async {
      repository.statusResults.add(const Result.success(_connected));
      await controller.load();
      expect(controller.urlController.text, 'https://erp.example.com');

      await controller.disconnect();

      expect(controller.status.value.isConnected, isFalse);
      expect(controller.actionNotice.value, 'erp_disconnected_notice'.tr);
    });

    test('แก้รหัสสาขา: ตรวจรูปแบบก่อนส่ง และส่งเป็นตัวพิมพ์ใหญ่', () async {
      const branch = ErpBranchCheck(id: 2, name: 'ทองหล่อ', isActive: true);

      expect(await controller.updateBranchCode(branch, 'ทองหล่อ'), isFalse);
      expect(controller.actionError.value, 'erp_error_branch_code_format'.tr);
      expect(repository.branchCodeCalls, isEmpty);

      expect(await controller.updateBranchCode(branch, ' thonglor '), isTrue);
      expect(repository.branchCodeCalls.single, (2, 'THONGLOR'));
    });

    test(
      'เหตุผลของการดึงครั้งล่าสุดเป็นประโยคตามภาษา — credential ถูกเพิกถอนมาก่อน',
      () async {
        ErpConnectionStatus withError(
          ErpPullError? error, {
          bool rejected = false,
        }) => ErpConnectionStatus(
          mode: ErpMode.connected,
          connection: ErpConnectionInfo(
            erpUrl: 'https://erp.example.com',
            instanceCode: 'POS-1',
            instanceName: 'POS',
            contractVersion: '1.0.0',
            appliedVersion: 3,
            lastError: error,
            credentialRejected: rejected,
          ),
        );

        controller.status.value = withError(
          const ErpPullError(kind: 'network'),
        );
        expect(controller.lastPullProblem, 'erp_last_error_network'.tr);

        controller.status.value = withError(
          const ErpPullError(kind: 'something_new'),
        );
        expect(controller.lastPullProblem, 'erp_last_error_other'.tr);

        controller.status.value = withError(
          const ErpPullError(kind: 'credential_rejected'),
          rejected: true,
        );
        expect(controller.lastPullProblem, 'erp_last_error_credential'.tr);
      },
    );

    test(
      'ดึงตามรอบเวลาหยุดรอคน: บอกให้แก้แล้วกดดึงเอง (credential ที่ถูกปฏิเสธมีข้อความของตัวเอง)',
      () {
        ErpConnectionStatus stopped({bool rejected = false}) =>
            ErpConnectionStatus(
              mode: ErpMode.connected,
              connection: ErpConnectionInfo(
                erpUrl: 'https://erp.example.com',
                instanceCode: 'POS-1',
                instanceName: 'POS',
                contractVersion: '1.0.0',
                appliedVersion: 3,
                lastError: const ErpPullError(
                  kind: 'invalid_response',
                  reason: 'unexpected_response',
                ),
                credentialRejected: rejected,
                pullStopped: true,
              ),
            );

        controller.status.value = stopped();
        expect(controller.pullStopped, isTrue);
        expect(
          controller.lastPullProblem,
          'erp_last_error_invalid_response'.tr,
        );
        controller.status.value = stopped(rejected: true);
        expect(controller.pullStopped, isFalse);
        controller.status.value = _connected;
        expect(controller.pullStopped, isFalse);
      },
    );
  });

  group('สร้างสาขานี้ในเครื่อง', () {
    test(
      'สร้างได้: ส่งรหัสของ ERP ใช้สถานะหลังสร้าง และบอกชื่อที่สร้างจริง',
      () async {
        expect(await controller.createBranch(_silom), isTrue);

        expect(repository.createBranchCalls, ['SILOM']);
        expect(controller.status.value.connection!.appliedVersion, 16);
        expect(
          controller.actionNotice.value,
          'erp_branch_created_notice'.trParams({
            'name': 'สาขาสีลม คอมเพล็กซ์',
            'code': 'SILOM',
          }),
        );
        expect(controller.actionError.value, isNull);
        expect(controller.isBusy.value, isFalse);
      },
    );

    test(
      'มีรหัสนี้ในเครื่องแล้ว (409): บอกเหตุผลจาก backend และโหลดรายการใหม่',
      () async {
        repository.createBranchResult = const Result.failure(
          ServerFailure(
            'มีสาขารหัสนี้ในเครื่องแล้ว',
            statusCode: 409,
            code: 'BRANCH_ALREADY_LOCAL',
          ),
        );
        repository.statusResults.add(const Result.success(_withSilom));

        expect(await controller.createBranch(_silom), isFalse);

        expect(controller.actionError.value, 'มีสาขารหัสนี้ในเครื่องแล้ว');
        expect(controller.actionNotice.value, isNull);
        expect(repository.statusCalls, 1, reason: 'โหลดรายการใหม่หลังล้ม');
        expect(controller.status.value.branches.single.code, 'SILOM');
      },
    );

    test('โหมดสาธิตสร้างสาขาจาก ERP ไม่ได้', () async {
      final demo = _controllerFor(
        const ErpConnectionRepositoryImpl(DemoErpConnectionDataSource()),
      );
      addTearDown(demo.onClose);
      expect(await demo.createBranch(_silom), isFalse);
      expect(demo.actionError.value, 'erp_error_demo_mode'.tr);
    });
  });

  group('โหมดสาธิต', () {
    test(
      'ใช้งานเดี่ยวเสมอ และปุ่มเชื่อมต่อได้เหตุผลว่าทำในโหมดสาธิตไม่ได้',
      () async {
        final demo = _controllerFor(
          const ErpConnectionRepositoryImpl(DemoErpConnectionDataSource()),
        );
        addTearDown(demo.onClose);

        await demo.load();
        expect(demo.status.value.mode, ErpMode.standalone);

        demo.urlController.text = 'https://erp.example.com';
        demo.credentialController.text = _credential;
        await demo.connect();
        expect(demo.status.value.mode, ErpMode.standalone);
        expect(demo.actionError.value, 'erp_error_demo_mode'.tr);
      },
    );
  });

  group('สถานะจาก backend', () {
    test(
      'แปลงคำตอบของ /erp/connection และหาสาขาที่ต้องแก้/ไม่ได้ดูแล/ยังไม่มี',
      () {
        final status = ErpConnectionStatusModel.fromJson({
          'mode': 'connected',
          'connection': {
            'erpUrl': 'https://erp.example.com',
            'instanceCode': 'POS-SILOM-1',
            'instanceName': 'Silom',
            'contractVersion': '1.0.0',
            'appliedVersion': 15,
            'latestVersion': 20,
            'lastPullAt': null,
            'lastError': {
              'kind': 'unavailable',
              'status': 503,
              'reason': null,
              'at': '2026-09-27T05:00:00.000Z',
            },
            'credentialRejected': false,
            'pullStopped': true,
            'retryAfter': null,
            'credentialSaved': true,
          },
          'branches': [
            {
              'id': 1,
              'name': 'สีลม',
              'code': 'SILOM',
              'isActive': true,
              'codeProblem': null,
              'servedByErp': true,
              'supersededBy': null,
            },
            {
              'id': 2,
              'name': 'ทองหล่อ',
              'code': 'THONGLOR',
              'isActive': true,
              'codeProblem': null,
              'servedByErp': false,
              'supersededBy': null,
            },
            {
              'id': 3,
              'name': 'ปิดแล้ว',
              'code': null,
              'isActive': false,
              'codeProblem': 'missing',
              'servedByErp': false,
              'supersededBy': null,
            },
          ],
          'servedBranches': [
            {
              'code': 'SILOM',
              'nameTh': 'สีลม',
              'nameEn': 'Silom',
              'isActive': true,
              'localBranchId': 1,
            },
            {
              'code': 'ARI',
              'nameTh': 'อารีย์',
              'nameEn': 'Ari',
              'isActive': true,
              'localBranchId': null,
            },
          ],
        });

        expect(status.isConnected, isTrue);
        expect(status.connection!.appliedVersion, 15);
        expect(status.connection!.lastError!.status, 503);
        expect(status.connection!.pullStopped, isTrue);
        expect(
          status.branchesToFix,
          isEmpty,
          reason: 'สาขาที่ปิดแล้วไม่ต้องแก้',
        );
        expect(status.branchesNotServed.map((b) => b.code), ['THONGLOR']);
        expect(status.servedButMissing.map((b) => b.code), ['ARI']);
      },
    );

    test('รหัสกลางของระบบนิเวศ และชื่อหน่วยจาก ERP', () {
      expect(EcosystemCode.isValid('WHOLE-CHICKEN'), isTrue);
      expect(EcosystemCode.isValid('-BAD'), isFalse);
      expect(EcosystemCode.isValid('lower'), isFalse);
      expect(EcosystemCode.isValid('A'), isFalse);
      expect(EcosystemCode.isValid(null), isFalse);

      expect(ErpUnitLabel.of('kg'), 'erp_unit_kg'.tr);
      expect(ErpUnitLabel.of('kg'), isNot('kg'));
      expect(
        ErpUnitLabel.of('dozen'),
        'dozen',
        reason: 'รหัสที่ไม่รู้จักแสดงตรง ๆ ไม่เดา',
      );
    });
  });
}
