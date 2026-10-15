// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// ผลของการเลือกรูป — เก็บเป็น data URL เพื่อส่งขึ้น `menu_items.image_url` ได้ตรง ๆ
typedef PickedMenuImage = ({String dataUrl, int sizeBytes});

/// ความกว้างสูงสุดที่เก็บจริง — การ์ดเมนูใหญ่สุดไม่เกินไม่กี่ร้อย px
/// ย่อตั้งแต่ตอนเลือกจึงคุ้มกว่าปล่อยรูปกล้อง 12MP เข้ามาแล้วค่อยปฏิเสธทีหลัง
/// 640 px คมพอสำหรับการ์ดบนจอ 3x และได้ไฟล์ราว 40–80 KB (1280 px/82% ราว 200 KB ต่อรูป ลูกค้าโหลดผ่านมือถือ
/// ทุกรูปตอนสแกน QR — DECISIONS #101)
const int _maxWidth = 640;
const int _quality = 75;

/// เปิดกล้องหรือคลังภาพให้เลือกรูปเมนู แล้วคืนเป็น data URL (base64)
///
/// ใช้ได้ทุกแพลตฟอร์มที่แอปรองรับ — บนเว็บ image_picker จะเรียก file input
/// ของเบราว์เซอร์ให้เอง จึงไม่ต้องแยกโค้ดตามแพลตฟอร์มอีกต่อไป
///
/// คืนค่า null ถ้าผู้ใช้ยกเลิก
Future<PickedMenuImage?> pickMenuImage(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: _maxWidth.toDouble(),
    imageQuality: _quality,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  final mimeType = file.mimeType ?? _mimeFromFileName(file.name);

  return (
    dataUrl: 'data:$mimeType;base64,${base64Encode(bytes)}',
    sizeBytes: bytes.length,
  );
}

/// บางแพลตฟอร์มไม่ส่ง mimeType กลับมา จึงเดาจากนามสกุลไฟล์แทน
String _mimeFromFileName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}
