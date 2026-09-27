// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

part of 'demo_store.dart';

// ------------------------------------------------------- audit logs -------
/// ตัวเลขในประโยค audit แบบเดียวกับ backend (JavaScript): 500.0 เป็น "500", 12.5 คงเดิม
///
/// Dart พิมพ์ double ลงท้าย ".0" เสมอ ประโยคของ Demo Mode จึงเคยต่างจากระบบจริง
/// ("รับชำระหนี้ 500.0 บาท") — เจอตอนเทสต์ประกอบประโยคจาก summaryArgs (DECISIONS #74)
String _jsNumber(Object? value) => switch (value) {
  final double v when v == v.roundToDouble() => v.toInt().toString(),
  _ => '$value',
};

/// Mirror ของ backend audit-log.service.js (ดู docs/tickets/08-audit-log.md)
/// เก็บ log append-only ไว้ในหน่วยความจำเหมือนข้อมูลอื่นๆ ของ Demo Mode —
/// ไม่มี endpoint แก้ไข/ลบเปิดให้ใช้เลยเช่นเดียวกับฝั่ง backend
extension DemoStoreAuditLogs on DemoStore {
  String _auditActorName(int? actorId) {
    if (actorId == null) return 'ระบบ';
    try {
      return DemoNames.of(_findUser(actorId));
    } on ApiException {
      return 'ระบบ';
    }
  }

  void _logAudit({
    int? actorId,
    required String action,
    required String entityType,
    int? entityId,
    required String summary,
    Map<String, dynamic>? summaryArgs,
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    auditLogs.add({
      'id': _nextId(),
      'actorUserId': actorId,
      'actorName': _auditActorName(actorId),
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'summary': summary,
      'reason': reason,
      // เหมือน backend: ค่าที่ประกอบประโยคแบบไม่ผูกภาษา อยู่ใน metadata.summaryArgs (DECISIONS #74)
      'metadata': summaryArgs == null
          ? metadata
          : {...?metadata, 'summaryArgs': summaryArgs},
      'createdAt': _now(),
    });
  }

  List<Map<String, dynamic>> _auditLogMatches({
    int? actorUserId,
    String? action,
    String? entityType,
    int? entityId,
    String? dateFrom,
    String? dateTo,
  }) {
    return auditLogs.reversed
        .where((log) {
          if (actorUserId != null && log['actorUserId'] != actorUserId) {
            return false;
          }
          if (action != null && log['action'] != action) return false;
          if (entityType != null && log['entityType'] != entityType) {
            return false;
          }
          if (entityId != null && log['entityId'] != entityId) return false;

          final createdAt = log['createdAt'] as String;
          if (dateFrom != null && createdAt.compareTo(dateFrom) < 0) {
            return false;
          }
          if (dateTo != null && createdAt.compareTo('${dateTo}T23:59:59') > 0) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// คืน total มาด้วยเหมือน backend (audit-log.controller.js ส่ง meta.total)
  /// เพื่อให้หน้าจอบอกได้ว่าเห็นอยู่กี่จากทั้งหมด และมีให้โหลดต่อไหม
  ({List<Map<String, dynamic>> rows, int total}) auditLogList({
    int? actorUserId,
    String? action,
    String? entityType,
    int? entityId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int limit = 50,
  }) {
    final matched = _auditLogMatches(
      actorUserId: actorUserId,
      action: action,
      entityType: entityType,
      entityId: entityId,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    return (
      rows: matched
          .skip((page - 1) * limit)
          .take(limit)
          .toList(growable: false),
      total: matched.length,
    );
  }

  /// ไม่มี pagination — ใช้สำหรับ export CSV เท่านั้น (ดู
  /// docs/tickets/14-financial-audit-trail.md) mirror ของ
  /// audit-log.repository.js#findAllForExport
  String auditLogExportCsv({
    int? actorUserId,
    String? action,
    String? entityType,
    String? dateFrom,
    String? dateTo,
  }) {
    final rows = _auditLogMatches(
      actorUserId: actorUserId,
      action: action,
      entityType: entityType,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
    return toCsv(rows, [
      (label: 'วันเวลา', value: (Map<String, dynamic> row) => row['createdAt']),
      (label: 'ผู้ทำ', value: (Map<String, dynamic> row) => row['actorName']),
      (label: 'การกระทำ', value: (Map<String, dynamic> row) => row['action']),
      (label: 'ประเภท', value: (Map<String, dynamic> row) => row['entityType']),
      (
        label: 'รหัสอ้างอิง',
        value: (Map<String, dynamic> row) => row['entityId'],
      ),
      (
        label: 'รายละเอียด',
        value: (Map<String, dynamic> row) => row['summary'],
      ),
      (label: 'เหตุผล', value: (Map<String, dynamic> row) => row['reason']),
    ]);
  }
}
