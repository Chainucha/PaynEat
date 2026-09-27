// Copyright 2026 Suruch Chakrapeesirisuk
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../app/config/app_config.dart';
import '../errors/exceptions.dart';

/// HTTP client กลางของแอป
///
/// หน้าที่:
/// - แนบ JWT ให้ทุก request อัตโนมัติ
/// - แนบ `x-request-id` ใหม่ทุก request — backend ใส่รหัสเดียวกันในทุกบรรทัด log ของคำขอนั้น
///   (สัญญา telemetry, ticket 24) error ที่แสดงให้ร้านเห็นมีรหัสนี้ติดไปด้วย แจ้งแล้วค้น log ได้ตรงตัว
/// - แกะ envelope `{ success, data, meta }` ของ backend ให้เหลือเฉพาะที่ใช้จริง
/// - แปลง error ทุกแบบให้เป็น [ApiException] / [NetworkException] รูปแบบเดียว
class ApiClient {
  ApiClient({
    Dio? dio,
    this.tokenProvider,
    this.onUnauthorized,
    String? Function()? languageProvider,
  }) : _dio = dio ?? Dio(),
       languageProvider = languageProvider ?? _currentLanguage {
    _dio.options
      ..baseUrl = AppConfig.apiBaseUrl
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers = {'Content-Type': 'application/json'}
      // ให้ dio ไม่โยน exception เอง เราจัดการ status code ทั้งหมดในที่เดียว
      ..validateStatus = (status) => status != null && status < 500;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // header ที่ระบุมาตรงๆ ต่อ request (เช่น pendingToken ตอนเลือกสาขาครั้งแรก ดู
          // features/auth) มาก่อนเสมอ ไม่ให้ tokenProvider (token ของ session ปัจจุบัน) ทับ
          if (!options.headers.containsKey('Authorization')) {
            final token = tokenProvider?.call();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          options.headers.putIfAbsent(requestIdHeader, newRequestId);
          // backend แปลข้อความ error ตามภาษานี้ (ไม่ส่ง = ไทย) — อ่านทุก request
          // เพราะผู้ใช้สลับภาษาได้กลางกะโดยไม่ต้องล็อกอินใหม่ (DECISIONS #64)
          final language = this.languageProvider();
          if (language != null && language.isNotEmpty) {
            options.headers['Accept-Language'] = language;
          }
          return handler.next(options);
        },
      ),
    );

    if (AppConfig.enableApiLog) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true, request: false),
      );
    }
  }

  final Dio _dio;

  /// ดึง token ปัจจุบัน (ฉีดจากภายนอกเพื่อไม่ให้ network layer ผูกกับ storage)
  final String? Function()? tokenProvider;

  /// ถูกเรียกเมื่อเจอ 401 เพื่อให้แอปเด้งกลับหน้า login
  final void Function()? onUnauthorized;

  /// ภาษาที่ส่งไปเป็น `Accept-Language` — ค่าเริ่มต้นคือภาษาที่แอปแสดงอยู่ตอนนี้
  final String? Function() languageProvider;

  static String? _currentLanguage() => Get.locale?.languageCode;

  static const requestIdHeader = 'x-request-id';
  static final _random = Random.secure();

  /// `pos-` + 16 hex — ตรงรูปแบบ `^[\w-]{8,64}$` ที่ backend รับ (ไม่ตรง backend จะสร้างรหัสใหม่แทน)
  /// และสั้นพอให้ร้านอ่านบอกทางโทรศัพท์ได้
  static String newRequestId() =>
      'pos-${List.generate(8, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  /// รหัสคำขอที่ backend ยืนยันกลับมา (header) — ถ้าไม่มี (proxy ตัดทิ้ง, ต่อไม่ถึง backend) ใช้รหัสที่แอปส่งไป
  static String? _requestIdOf(
    RequestOptions request,
    Response<dynamic>? response,
  ) =>
      response?.headers.value(requestIdHeader) ??
      request.headers[requestIdHeader] as String?;

  Future<ApiResult> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: _clean(query)));

  Future<ApiResult> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _request(
    () => _dio.post(
      path,
      data: body,
      options: headers == null ? null : Options(headers: headers),
    ),
  );

  Future<ApiResult> patch(String path, {Object? body}) =>
      _request(() => _dio.patch(path, data: body));

  Future<ApiResult> put(String path, {Object? body}) =>
      _request(() => _dio.put(path, data: body));

  Future<ApiResult> delete(String path) => _request(() => _dio.delete(path));

  /// ดึง response แบบข้อความดิบ (ไม่ใช่ envelope `{success,data}`) — ใช้กับ endpoint ที่ตอบเป็น
  /// ไฟล์ เช่น CSV export ซึ่งไม่ใช่ JSON
  ///
  /// รับเป็นไบต์แล้วถอดเองแทน [ResponseType.plain] เพราะตัวถอด UTF-8 ของ Dart ตัด BOM หัวข้อความ
  /// ทิ้งเสมอ — backend ใส่ BOM ให้ทุกไฟล์ CSV เพื่อให้ Excel อ่านภาษาไทยถูก ถ้าหายระหว่างทาง ไฟล์ที่
  /// ร้านดาวน์โหลดไปจะเปิดใน Excel เป็นตัวอักษรเพี้ยน (ดู docs/DECISIONS.md #45)
  Future<String> getText(String path, {Map<String, dynamic>? query}) async =>
      _decodeKeepingBom(await getBytes(path, query: query));

  /// ดึงไฟล์ดิบเป็นไบต์ (ไม่ใช่ envelope `{success,data}`) — CSV export และ PDF เอกสารลูกหนี้
  /// (ดู docs/tickets/23-document-pdf-email.md)
  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query}) async {
    late final Response<List<int>> response;
    try {
      response = await _dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        options: Options(responseType: ResponseType.bytes),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      throw ApiException(
        message: error.message ?? 'error_api_call_failed'.tr,
        statusCode: error.response?.statusCode,
        requestId: _requestIdOf(error.requestOptions, error.response),
      );
    }

    final statusCode = response.statusCode ?? 500;
    if (statusCode == 401) onUnauthorized?.call();
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException(
        message: 'error_api_call_failed_with_status'.trParams({
          'status': statusCode.toString(),
        }),
        statusCode: statusCode,
        requestId: _requestIdOf(response.requestOptions, response),
      );
    }
    return response.data ?? const [];
  }

  /// ถอด UTF-8 แล้วคืน BOM กลับไปถ้าไบต์ต้นฉบับมี — ได้ข้อความตรงกับที่เซิร์ฟเวอร์ส่งมาทุกตัวอักษร
  static String _decodeKeepingBom(List<int> bytes) {
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
    final text = utf8.decode(bytes, allowMalformed: true);
    return hasBom && !text.startsWith('\uFEFF') ? '\uFEFF$text' : text;
  }

  Future<ApiResult> _request(Future<Response<dynamic>> Function() send) async {
    late final Response<dynamic> response;
    try {
      response = await send();
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError) {
        throw const NetworkException();
      }
      // 5xx (validateStatus ไม่รับ) ยังมี error body ของ backend อยู่ — อ่านข้อความที่แปลแล้ว, code และ
      // รหัสคำขอจาก body นั้นเหมือน 4xx แทนข้อความภาษาอังกฤษยาว ๆ ของ Dio
      final errorResponse = error.response;
      if (errorResponse != null) return _resultOf(errorResponse);
      throw ApiException(
        message: error.message ?? 'error_api_call_failed'.tr,
        requestId: _requestIdOf(error.requestOptions, null),
      );
    }
    return _resultOf(response);
  }

  ApiResult _resultOf(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 500;
    final body = response.data;

    if (statusCode >= 200 && statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return ApiResult(
          data: body['data'],
          meta: body['meta'] as Map<String, dynamic>?,
        );
      }
      return const ApiResult(data: null);
    }

    if (statusCode == 401) onUnauthorized?.call();

    final error = body is Map<String, dynamic> ? body['error'] : null;
    throw ApiException(
      message: error is Map<String, dynamic>
          ? (error['message'] as String? ?? 'error_api_call_failed'.tr)
          : 'error_api_call_failed_with_status'.trParams({
              'status': statusCode.toString(),
            }),
      statusCode: statusCode,
      code: error is Map<String, dynamic> ? error['code'] as String? : null,
      details: error is Map<String, dynamic> && error['details'] is List
          ? (error['details'] as List).whereType<Map<String, dynamic>>().toList(
              growable: false,
            )
          : null,
      requestId: _requestIdOf(response.requestOptions, response),
    );
  }

  /// ตัด key ที่เป็น null ออกจาก query string
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null) cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }
}

/// ผลลัพธ์ดิบจาก API หลังแกะ envelope แล้ว
class ApiResult {
  const ApiResult({required this.data, this.meta});

  final dynamic data;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> get asMap => data is Map<String, dynamic>
      ? data as Map<String, dynamic>
      : <String, dynamic>{};

  List<Map<String, dynamic>> get asList => data is List
      ? (data as List).whereType<Map<String, dynamic>>().toList(growable: false)
      : const [];

  int get total => (meta?['total'] as num?)?.toInt() ?? asList.length;
}
