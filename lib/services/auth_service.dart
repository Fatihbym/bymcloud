import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'https://bymcloud.app';
  
  // Dynamic User-Agent (Web görünümü ve platform ile 100% eşleşen User-Agent)
  String _customUserAgent = kIsWeb
      ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
      : (defaultTargetPlatform == TargetPlatform.iOS
          ? "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
          : "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36");

  String get customUserAgent => _customUserAgent;

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  String? _sessionCookie;

  String? get sessionCookie => _sessionCookie;

  Future<void> syncCookiesToWebView([String domainUrl = "https://bymcloud.app/"]) async {
    final cookieStr = _sessionCookie;
    if (cookieStr != null && cookieStr.isNotEmpty) {
      try {
        final cookieManager = CookieManager.instance();
        final url = WebUri(domainUrl);
        final parts = cookieStr.split(';');
        for (var part in parts) {
          final trimmed = part.trim();
          if (trimmed.isEmpty) continue;
          final eqIndex = trimmed.indexOf('=');
          if (eqIndex != -1) {
            final name = trimmed.substring(0, eqIndex).trim();
            final value = trimmed.substring(eqIndex + 1).trim();
            if (name.isNotEmpty && !['expires', 'path', 'domain', 'max-age', 'secure', 'httponly', 'samesite'].contains(name.toLowerCase())) {
              await cookieManager.setCookie(
                url: url,
                name: name,
                value: value,
                isSecure: true,
              );
            }
          }
        }
      } catch (e) {
        debugPrint("syncCookiesToWebView error: $e");
      }
    }
  }

  Future<void> init() async {
    await _loadCookie();
    await _initUserAgent();
  }

  Future<void> _initUserAgent() async {
    try {
      final defaultUa = await InAppWebViewController.getDefaultUserAgent();
      if (defaultUa.isNotEmpty) {
        _customUserAgent = defaultUa;
      }
    } catch (e) {
      debugPrint("getDefaultUserAgent error: $e");
    }
  }

  Future<void> logout() async {
    _sessionCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_cookie');
    await prefs.remove('saved_dbid');
    await prefs.remove('saved_firmaid');

    final bool rememberMe = prefs.getBool('remember_me') ?? false;
    if (!rememberMe) {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _loadCookie() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('auth_cookie');
  }

  Future<void> _saveCookie(String cookie) async {
    _sessionCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_cookie', cookie);
  }

  Future<void> clearCookie() async {
    _sessionCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_cookie');
  }

  String _mergeCookies(String? current, String incoming) {
    if (current == null || current.isEmpty) return incoming;

    final Map<String, String> cookiesMap = {};

    void parseAndAdd(String str, bool isIncoming) {
      final parts = str.split(';');
      for (var part in parts) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final eqIndex = trimmed.indexOf('=');
        if (eqIndex != -1) {
          final key = trimmed.substring(0, eqIndex).trim();
          final val = trimmed.substring(eqIndex + 1).trim();
          final lowerKey = key.toLowerCase();
          
          if (isIncoming) {
            cookiesMap[key] = val;
          } else {
            if (key.isNotEmpty && !['expires', 'path', 'domain', 'max-age', 'secure', 'httponly', 'samesite'].contains(lowerKey)) {
              cookiesMap[key] = val;
            }
          }
        }
      }
    }

    parseAndAdd(current, false);
    parseAndAdd(incoming, true);

    final merged = cookiesMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
    _saveCookie(merged);
    return merged;
  }

  /// Step 1: POST /api/mobile/login
  /// Returns list of Database objects from `data['icerik']`
  Future<List<dynamic>?> loginAPI(String email, String password, {bool rememberMe = true}) async {
    try {
      final url = Uri.parse('$baseUrl/api/mobile/login');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': customUserAgent,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "eposta": email,
          "sifre": password,
          "rememberMe": rememberMe,
          "beniHatirla": rememberMe,
          "beni_hatirla": rememberMe,
        }),
      );

      final cookies = response.headers['set-cookie'];
      if (cookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, cookies);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['icerik'] is List) {
          return data['icerik'] as List<dynamic>;
        } else if (data is List) {
          return data;
        } else {
          throw Exception("Gelen veri beklenilen formatta değil: ${response.body}");
        }
      } else {
        throw Exception("Sunucu Hatası (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      debugPrint("API Login error: $e");
      rethrow;
    }
  }

  /// Step 2: POST /api/mobile/get-firms
  /// Takes selected database item, returns list of firm objects
  Future<List<dynamic>> getFirmsAPI(Map<String, dynamic> dbObject) async {
    try {
      final url = Uri.parse('$baseUrl/api/mobile/get-firms');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': customUserAgent,
      };
      
      if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
        headers['Cookie'] = _sessionCookie!;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(dbObject),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data['icerik'] is List) {
          return data['icerik'] as List<dynamic>;
        }
        return [];
      } else {
        throw Exception("Firmalar getirilemedi (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      debugPrint("API getFirms error: $e");
      rethrow;
    }
  }

  /// Step 3: POST /api/mobile/select-firm
  /// Returns redirectUrl string (e.g. "/mobile-auth?sessionId=...")
  Future<String?> selectFirmAPI(String email, String password, int dbid, int firmaid, {bool rememberMe = true}) async {
    try {
      final url = Uri.parse('$baseUrl/api/mobile/select-firm');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': customUserAgent,
      };
      
      if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
        headers['Cookie'] = _sessionCookie!;
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "eposta": email,
          "sifre": password,
          "dbid": dbid,
          "firmaid": firmaid,
          "rememberMe": rememberMe,
          "beniHatirla": rememberMe,
          "beni_hatirla": rememberMe,
        }),
      );

      final cookies = response.headers['set-cookie'];
      if (cookies != null) {
        _sessionCookie = _mergeCookies(_sessionCookie, cookies);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('redirectUrl')) {
          return data['redirectUrl'] as String?;
        }
      }
      return null;
    } catch (e) {
      debugPrint("API selectFirm error: $e");
      return null;
    }
  }
}
