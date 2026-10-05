// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// เปิด backend ตัวจริง (`node src/server.js`) ขึ้นมาเป็น process แยก ให้ชุด E2E ยิงผ่าน HTTP จริง
///
/// ทุกครั้งที่เรียก [start] ได้ฐานข้อมูล SQLite ใหม่เอี่ยมในโฟลเดอร์ชั่วคราว (server migrate + seed เอง
/// ตอนบูต — ดู `backend/src/server.js`) บนพอร์ตว่างที่สุ่มได้ จึงรันซ้ำกี่รอบก็ไม่มีข้อมูลค้างจากรอบก่อน
/// และไม่ชนกับ backend ที่เปิดทิ้งไว้ใช้งานเองบนพอร์ต 3000
///
/// ทำไมต้องเป็น process จริง ไม่ใช่ supertest ใน Node: เทสต์ backend เดิม (`backend/tests/`) ยิงผ่าน
/// HTTP จริงอยู่แล้ว แต่เป็นฝั่ง JavaScript ล้วน ส่วนเทสต์ Flutter เดิมทั้งหมดวิ่งบนโหมดสาธิต
/// (`DemoStore` ฝั่ง Dart) — ไม่มีเทสต์ไหนเลยที่ให้โค้ดฝั่งแอป *อ่าน JSON ที่ backend ส่งมาจริง*
/// ชื่อฟิลด์สะกดไม่ตรงกันแค่ตัวเดียวจะผ่านเทสต์ครบทุกตัวแต่พังทันทีที่ร้านเปิดใช้จริง ชุดนี้ปิดช่องนั้น
class BackendProcess {
  BackendProcess._(
    this._process,
    this.port,
    this._tempDir,
    this._log,
    this._backendDir,
    this.databaseFile,
  );

  final Process _process;
  final int port;
  final Directory _tempDir;
  final StringBuffer _log;
  final Directory _backendDir;

  /// ไฟล์ฐานข้อมูลของ backend ตัวนี้ — ค่าเริ่มต้นอยู่ในโฟลเดอร์ชั่วคราวของมันเอง
  final String databaseFile;

  /// โฟลเดอร์ไฟล์สำรอง (ticket 33) — ค่าเริ่มต้นของ backend คือ `backups/` ข้างไฟล์ฐานข้อมูล
  String get backupDir => '${File(databaseFile).parent.path}/backups';

  String get apiBaseUrl => 'http://127.0.0.1:$port/api/v1';

  /// ที่อยู่ของ socket.io (ราก ไม่มี /api/v1) — ตาชั่งสดส่งผ่านช่องนี้ (ticket 22)
  String get socketUrl => 'http://127.0.0.1:$port';

  /// "เลื่อนเวลา" ในฐานข้อมูลของ backend — เทสต์ที่ต้องการบิลเลยกำหนด (ดอกเบี้ยผิดนัด ticket 21) รอ
  /// เวลาจริงไม่ได้ จึงแก้วันที่ตรงในไฟล์ SQLite ด้วย better-sqlite3 ของ backend เอง (WAL mode ให้
  /// process อื่นเขียนพร้อมกับ server ได้) ใช้กับข้อมูลวันที่เท่านั้น ไม่ใช่ทางลัดสร้างข้อมูลเงิน
  Future<void> execSql(String statement) async {
    final result = await Process.run(
      Platform.environment['E2E_NODE'] ?? 'node',
      [
        '-e',
        "const Database = require('better-sqlite3');"
            'const db = new Database(process.argv[1]);'
            'db.exec(process.argv[2]); db.close();',
        databaseFile,
        statement,
      ],
      workingDirectory: _backendDir.path,
    );
    if (result.exitCode != 0) {
      throw StateError('execSql ล้มเหลว: ${result.stderr}');
    }
  }

  /// stdout/stderr ของ backend ทั้งหมด — พิมพ์ออกมาตอนเทสต์ล้มจะรู้ทันทีว่าฝั่งไหนผิด
  String get log => _log.toString();

  /// [environment] ทับค่า env ของ backend เพิ่มเติม — เช่น ต่อตาชั่ง (SCALE_DRIVER) หรือเปิดอีเมลแบบ
  /// ไม่ส่งจริง (MAIL_TRANSPORT=json) สำหรับชุดที่ต้องใช้ (tickets 22–23)
  ///
  /// [databaseFile] เปิดบนไฟล์ฐานข้อมูลที่มีอยู่แล้ว เช่น ไฟล์ที่เพิ่งกู้คืน (ticket 33) แทนฐานข้อมูลใหม่
  static Future<BackendProcess> start({
    Duration bootTimeout = const Duration(seconds: 60),
    Map<String, String> environment = const {},
    String? databaseFile,
  }) async {
    final backendDir = _findBackendDir();
    if (!Directory('${backendDir.path}/node_modules').existsSync()) {
      throw StateError(
        'ยังไม่ได้ติดตั้ง dependency ของ backend — รัน `cd backend && npm ci` ก่อน',
      );
    }

    final port = await _freePort();
    final tempDir = await Directory.systemTemp.createTemp('payneat-e2e-');
    final log = StringBuffer();
    final database = databaseFile ?? '${tempDir.path}/e2e.sqlite';

    // สำเนา env ของเครื่องแล้วทับเฉพาะที่ต้องคุม — ตัด ANTHROPIC_API_KEY ออกเสมอ กันไม่ให้
    // เทสต์ไปเรียก Claude API จริงเสียเงินโดยไม่ตั้งใจ (ผู้ช่วย AI มีทางถอยเมื่อไม่มี key อยู่แล้ว)
    final processEnvironment = <String, String>{
      ...Platform.environment,
      'NODE_ENV': 'test',
      'JWT_SECRET': 'e2e-secret',
      'DATABASE_FILE': database,
      'PORT': '$port',
      'HOST': '127.0.0.1',
      // /metrics อยู่พอร์ตของตัวเอง (ticket 24) — ไฟล์ E2E รันขนานกันหลาย backend จึงให้ระบบเลือกพอร์ตว่างเอง
      // ไม่งั้นทุกตัวแย่ง 9464 (backend ยังทำงานต่อได้ แต่ log error ทุกครั้งโดยไม่จำเป็น)
      'METRICS_PORT': '0',
      ...environment,
    }..remove('ANTHROPIC_API_KEY');
    // ที่เก็บไฟล์สำรองต้องเป็นค่าเริ่มต้นข้างฐานข้อมูลชั่วคราว ไม่ใช่ค่าที่เครื่องนักพัฒนาตั้งไว้ (ticket 33)
    for (final name in ['BACKUP_DIR', 'BACKUP_COPY_DIR']) {
      if (!environment.containsKey(name)) processEnvironment.remove(name);
    }

    final process = await Process.start(
      Platform.environment['E2E_NODE'] ?? 'node',
      ['src/server.js'],
      workingDirectory: backendDir.path,
      environment: processEnvironment,
      includeParentEnvironment: false,
    );
    process.stdout.transform(utf8.decoder).listen(log.write);
    process.stderr.transform(utf8.decoder).listen(log.write);

    int? earlyExit;
    unawaited(process.exitCode.then((code) => earlyExit = code));

    final backend = BackendProcess._(
      process,
      port,
      tempDir,
      log,
      backendDir,
      database,
    );
    // วัดเวลาที่ผ่านไปด้วย Stopwatch (monotonic) ไม่ใช่นาฬิกา — AppClock ถูกตรึงได้ในเทสต์ ถ้าใช้ตัวนั้น
    // timeout อาจไม่มีวันถึง ส่วน DateTime.now() ถูกกฎ use_app_clock_not_date_time_now ห้ามไว้
    final elapsed = Stopwatch()..start();
    while (!await _isHealthy(port)) {
      if (earlyExit != null) {
        await backend._cleanTempDir();
        throw StateError(
          'backend ปิดตัวเองก่อนพร้อมใช้งาน (exit $earlyExit):\n$log',
        );
      }
      if (elapsed.elapsed > bootTimeout) {
        await backend.stop();
        throw TimeoutException(
          'backend ไม่ตอบ /health ภายใน ${bootTimeout.inSeconds} วินาที:\n$log',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return backend;
  }

  Future<void> stop() async {
    _process.kill(ProcessSignal.sigterm);
    // server.js ปิด DB ให้เองตอนได้ SIGTERM — รอให้จบจริงก่อนลบไฟล์ ไม่งั้นไฟล์ -wal อาจค้าง
    await _process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    await _cleanTempDir();
  }

  /// กู้คืน [backupFile] ลง [databaseFile] ด้วยคำสั่ง `db:restore` ตัวจริง (ticket 33) แบบที่เจ้าของร้าน
  /// พิมพ์บนเครื่องเซิร์ฟเวอร์ คืนข้อความที่คำสั่งพิมพ์ออกมา — คำสั่งปฏิเสธ = เทสต์ล้มพร้อมเหตุผล
  static Future<String> restore({
    required String backupFile,
    required String databaseFile,
  }) async {
    final backendDir = _findBackendDir();
    final environment = <String, String>{
      ...Platform.environment,
      'NODE_ENV': 'test',
      'JWT_SECRET': 'e2e-secret',
      'DATABASE_FILE': databaseFile,
    }..removeWhere((key, _) => key == 'BACKUP_DIR' || key == 'BACKUP_COPY_DIR');
    final result = await Process.run(
      Platform.environment['E2E_NODE'] ?? 'node',
      ['src/db/restore.js', backupFile],
      workingDirectory: backendDir.path,
      environment: environment,
      includeParentEnvironment: false,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'db:restore ล้มเหลว (exit ${result.exitCode}):\n'
        '${result.stdout}${result.stderr}',
      );
    }
    return '${result.stdout}';
  }

  Future<void> _cleanTempDir() async {
    if (_tempDir.existsSync()) await _tempDir.delete(recursive: true);
  }

  /// หา `backend/` โดยไล่ขึ้นจากโฟลเดอร์ที่รันเทสต์ — `flutter test` รันจาก `app/` เสมอ แต่ไม่ผูก
  /// ตายตัวไว้เผื่อมีคนรันจาก root ของรีโป
  static Directory _findBackendDir() {
    var dir = Directory.current.absolute;
    for (var i = 0; i < 4; i++) {
      final candidate = Directory('${dir.path}/backend');
      if (File('${candidate.path}/src/server.js').existsSync()) {
        return candidate;
      }
      dir = dir.parent;
    }
    throw StateError('หาโฟลเดอร์ backend/ ไม่เจอจาก ${Directory.current.path}');
  }

  static Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static Future<bool> _isHealthy(int port) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 500);
    try {
      final request = await client.get('127.0.0.1', port, '/health');
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == 200;
    } on Object {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
