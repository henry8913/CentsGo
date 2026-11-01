import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'disk_cache.dart';

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.fromCache,
  });

  final int statusCode;
  final String body;
  final bool fromCache;

  bool get isValid => statusCode >= 200 && statusCode < 300;
}

/// One HTTP client for every remote call in the app.
///
/// Responsibilities: identifiable User-Agent, timeout, retry with backoff,
/// per-host rate limit (Nominatim asks for max 1 request/second) and an
/// optional on-disk cache so the app degrades gracefully when offline.
class ApiClient {
  ApiClient({
    required this.userAgent,
    DiskCache? cache,
    this.timeout = const Duration(seconds: 20),
    this.maxRetries = 2,
    this.rateLimits = const {},
    HttpClient? httpClient,
  })  : cache = cache ?? DiskCache(),
        _http = httpClient ?? HttpClient();

  final String userAgent;
  final DiskCache cache;
  final Duration timeout;
  final int maxRetries;

  /// Minimum delay between requests to a given host.
  final Map<String, Duration> rateLimits;

  final HttpClient _http;
  final Map<String, DateTime> _lastCall = {};

  Future<ApiResponse> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? cacheTtl,
    bool forceRefresh = false,
    bool allowCache = true,
  }) async {
    if (allowCache && !forceRefresh) {
      final hit = await cache.read(uri.toString());
      if (hit != null && hit.isFresh(cacheTtl ?? const Duration(days: 7))) {
        return ApiResponse(statusCode: hit.statusCode, body: hit.body, fromCache: true);
      }
    }
    final response = await _send('GET', uri, headers: headers);
    if (response.isValid) {
      await cache.write(
        uri.toString(),
        CacheEntry(
          url: uri.toString(),
          body: response.body,
          statusCode: response.statusCode,
          storedAt: DateTime.now(),
        ),
      );
    }
    return response;
  }

  /// HEAD request used for cheap change detection (Last-Modified).
  Future<DateTime?> lastModified(Uri uri) async {
    try {
      await _respectRateLimit(uri);
      final request = await _http.headUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.followRedirects = true;
      final response = await request.close().timeout(timeout);
      final value = response.headers.value(HttpHeaders.lastModifiedHeader);
      await response.drain<void>();
      if (value == null) return null;
      return HttpDate.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<ApiResponse> _send(String method, Uri uri, {Map<String, String>? headers}) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await _respectRateLimit(uri);
        final request = method == 'GET' ? await _http.getUrl(uri) : await _http.headUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        headers?.forEach(request.headers.set);
        request.followRedirects = true;
        final response = await request.close().timeout(timeout);
        final body = method == 'HEAD'
            ? ''
            : await response.transform(utf8.decoder).join().timeout(timeout);
        if (response.statusCode >= 500 && attempt < maxRetries) {
          lastError = HttpException('HTTP ${response.statusCode}');
        } else {
          return ApiResponse(statusCode: response.statusCode, body: body, fromCache: false);
        }
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on HttpException catch (e) {
        lastError = e;
      }
      if (attempt < maxRetries) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (1 << attempt)));
      }
    }
    throw HttpException('Richiesta non riuscita: $lastError', uri: uri);
  }

  Future<void> _respectRateLimit(Uri uri) async {
    final limit = rateLimits[uri.host];
    if (limit == null) return;
    final last = _lastCall[uri.host];
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < limit) {
        await Future<void>.delayed(limit - elapsed);
      }
    }
    _lastCall[uri.host] = DateTime.now();
  }
}
