// ApiClient — Singleton design pattern.
//
// One HTTP client instance for the whole app, reached via
// ApiClient.instance. Holds the JWT, base URL, and shared http.Client.
// All resource-specific API classes (AuthApi, ReportApi, GeocodingApi)
// go through this client, so the auth header and base URL are
// configured in exactly one place. Throws ApiException on non-2xx
// responses with a parsed error message.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../core/config.dart';

MediaType? _imageMediaTypeFor(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'png':
      return MediaType('image', 'png');
    case 'gif':
      return MediaType('image', 'gif');
    case 'webp':
      return MediaType('image', 'webp');
    case 'bmp':
      return MediaType('image', 'bmp');
    case 'heic':
      return MediaType('image', 'heic');
    case 'heif':
      return MediaType('image', 'heif');
    case 'tif':
    case 'tiff':
      return MediaType('image', 'tiff');
    case 'svg':
      return MediaType('image', 'svg+xml');
    default:
      return null;
  }
}

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _timeout = Duration(seconds: 15);

  String? _token;
  String? get token => _token;
  void setToken(String? t) => _token = t;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query?.map((k, v) => MapEntry(k, v?.toString())),
    );
  }

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => http.get(_uri(path, query), headers: _headers(json: false)));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) {
    return _send(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body)));
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) {
    return _send(() => http.delete(
          _uri(path),
          headers: _headers(json: body != null),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) {
    return _send(() => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body)));
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    File? file,
    String fileField = 'photo',
  }) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(path));
      if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
      req.fields.addAll(fields);
      if (file != null) {
        req.files.add(await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType: _imageMediaTypeFor(file.path),
        ));
      }
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() run) async {
    http.Response res;
    try {
      res = await run().timeout(_timeout);
    } on TimeoutException {
      throw ApiException(0, 'Request timed out. Check your connection and try again.');
    } on SocketException {
      throw ApiException(0, 'Cannot reach the server. Check your internet connection.');
    } on HttpException {
      throw ApiException(0, 'Network error. Please try again.');
    } catch (_) {
      throw ApiException(0, 'Network error. Please try again.');
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    dynamic body = const <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = {'error': res.body};
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(res.statusCode, _extractMessage(body, res.statusCode));
  }

  String _extractMessage(dynamic body, int status) {
    if (body is Map) {
      if (body['error'] is String) return body['error'];
      if (body['message'] is String) return body['message'];
      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        final first = errors.first;
        if (first is Map && first['msg'] is String) return first['msg'];
      }
    }
    if (status == 401) return 'Incorrect password';
    if (status == 403) return 'Not authorized';
    if (status == 404) return 'Not found';
    if (status >= 500) return 'Server error. Please try again.';
    return 'Request failed (HTTP $status)';
  }
}
