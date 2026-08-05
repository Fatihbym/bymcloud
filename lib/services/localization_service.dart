import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLanguage = 'tr-TR';
  String get currentLanguage => _currentLanguage;

  /// Returns current [Locale]
  Locale get currentLocale {
    final parts = _currentLanguage.split('-');
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }
    return const Locale('tr', 'TR');
  }

  /// List of supported languages
  List<String> get supportedLanguages => const ['tr-TR', 'en-US'];

  /// List of supported locales
  List<Locale> get supportedLocales => const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ];

  bool get isTurkish => _currentLanguage == 'tr-TR';
  bool get isEnglish => _currentLanguage == 'en-US';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'tr-TR';
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    if (!supportedLanguages.contains(lang)) return;
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  /// Translates a key with optional string parameter interpolation
  String translate(String key, [Map<String, String>? args]) {
    String text = _localizedStrings[_currentLanguage]?[key] ??
        _localizedStrings['tr-TR']?[key] ??
        key;

    if (args != null && args.isNotEmpty) {
      args.forEach((param, value) {
        text = text.replaceAll('{$param}', value);
      });
    }

    return text;
  }

  /// Static helper method to translate keys directly
  static String tr(String key, [Map<String, String>? args]) {
    return _instance.translate(key, args);
  }

  static const Map<String, Map<String, String>> _localizedStrings = {
    'tr-TR': {
      // General & Common
      'ok': 'Tamam',
      'cancel': 'İptal',
      'confirm': 'Onayla',
      'loading': 'Yükleniyor...',
      'save': 'Kaydet',
      'success': 'Başarılı',
      'error': 'Hata',
      'warning': 'Uyarı',
      'close': 'Kapat',

      // Login & Auth
      'login': 'Giriş Yap',
      'logout': 'Çıkış Yap',
      'email_hint': 'E-Posta Adresi',
      'password_hint': 'Şifre',
      'remember_me': 'Beni Hatırla',
      'forgot_password': 'Şifremi Unuttum',
      'login_desc': 'Hesabınıza giriş yaparak devam edin.',
      'error_title': 'Giriş Hatası Detayı',
      'error_msg': 'E-Posta veya Şifre hatalıdır tekrar deneyiniz',
      'empty_error': 'Lütfen e-posta ve şifrenizi girin.',
      'login_failed': 'Giriş başarısız. Bilgilerinizi kontrol edin.',
      'session_expired_title': 'Oturumunuzun Süresi Doldu',
      'session_expired_desc': 'Güvenliğiniz için oturumunuz sonlandırıldı.\nDevam etmek için lütfen tekrar giriş yapınız.',
      'continue_working': 'Çalışmaya Devam Et',

      // Company & Firm Selection
      'select_company': 'Şirket ve Firma Seçimi',
      'search_company': 'Şirket veya firma adı ile arayın...',
      'no_company_found': 'Aramanızla eşleşen şirket veya firma bulunamadı.',
      'company_loading': 'Firmalar yükleniyor...',
      'click_to_see_firms': 'Firmaları görmek için dokunun',
      'firms_available': 'Firma Mevcut',
      'no_sub_firm': 'Alt firma bulunamadı.',
      'connect_to_company': 'Şirkete Bağlan',
      'continue_btn': 'Devam Et',
      'search_results': 'Arama Sonuçları',
      'companies_matched': 'Şirket Eşleşti',
      'firm_selection_fail': 'Firma seçimi başarısız oldu. Lütfen tekrar deneyin.',

      // Forgot Password
      'forgot_pwd_title': 'Şifremi Unuttum',
      'forgot_pwd_desc': 'Kayıtlı e-posta adresinizi girin, şifre sıfırlama bağlantısını gönderelim.',
      'forgot_pwd_btn': 'Bağlantı Gönder',
      'back_to_login': 'Giriş Ekranına Dön',
      'forgot_pwd_success': 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.',
      'forgot_pwd_fail': 'İşlem başarısız oldu veya e-posta bulunamadı.',
      'empty_email': 'Lütfen e-posta adresinizi girin.',

      // Reconnection & Network Modals
      'reconnecting_title': 'Yeniden Bağlanılıyor',
      'reconnecting_desc': 'Bulut sunucusu ile bağlantı kesildi.\nSisteme yeniden bağlanmaya çalışıyor, lütfen bekleyiniz...',
      'reconnect_btn': 'Yeniden Bağlan',
      'reconnecting_btn_progress': 'Bağlanılıyor...',
      'reload_page_btn': 'Sayfayı Yenile',
      'no_internet_title': 'İnternet Bağlantısı Yok',
      'no_internet_desc': 'Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
      'timeout_title': 'Bağlantı Zaman Aşımı',
      'timeout_desc': 'Sunucu yanıt vermedi veya sayfa yüklemesi çok uzun sürdü. Lütfen oturumunuzu tazeleyin.',
      'try_again_btn': 'Tekrar Deneyin',
      'relogin_btn': 'Yeniden Giriş Yap',

      // Multiple Session Warning
      'multiple_session_title': 'Çoklu Oturum Uyarısı',
      'multiple_session_subtitle': 'Bilgileriniz ile başka bir cihazda oturum açıldı.',
      'multiple_session_bullet_yes': 'Evet: Mevcut oturumunuzu sürdürün (yeni oturum kapatılır)',
      'multiple_session_bullet_no': 'Hayır: Oturumunuzu kapatın (yeni oturum devam eder)',
      'multiple_session_yes_btn': 'Evet (Oturumu Sürdür)',
      'multiple_session_no_btn': 'Hayır (Oturumu Kapat)',

      // Force Logout / Session Terminated Warning
      'force_logout_title': 'Oturumunuz Sonlandırıldı',
      'force_logout_desc': 'Bilgileriniz ile başka bir kullanıcı giriş yapmış durumda, oturumunuz sonlandırılıyor.',
      'force_logout_btn': 'Tamam',

      // Login Info & Devices Logs
      'login_info_title': 'Geçmiş Giriş Kayıtları',
      'login_info_subtitle': 'Son hesap erişim ve cihaz bilgileriniz',
      'date_column': 'Tarih',
      'ip_column': 'IP Adresi',
      'device_column': 'Cihaz Adı',
      'no_login_logs': 'Giriş kaydı bulunamadı.',

      // Theme Selection
      'theme_selection_title': 'Tema Seçimi',
      'theme_selection_subtitle': 'Uygulamanın görünüm temasını özelleştirin',
      'theme_system': 'Sistem Varsayılanı',
      'theme_system_sub': 'Cihazınızın tema ayarlarını otomatik takip eder',
      'theme_light': 'Açık Tema',
      'theme_light_sub': 'Aydınlık ve ferah görünüm',
      'theme_dark': 'Koyu Tema',
      'theme_dark_sub': 'Göz yormayan karanlık görünüm',

      // Menu View Selection
      'menu_view_title': 'Menü Görünümü',
      'menu_view_subtitle': 'Gezinme ve menü düzeninizi seçin',
      'menu_view_auth': 'Yetkili Olduklarım',
      'menu_view_auth_sub': 'Sadece erişim izniniz olan modüller gösterilir',
      'menu_view_all': 'Tümü',
      'menu_view_all_sub': 'Tüm sistem modülleri menüde listelenir',
      'menu_view_popup': 'Açılır Menü',
      'menu_view_popup_sub': 'Kompakt ve açılır menü düzeni',
      'menu_view_fixed': 'Sabit Menü',
      'menu_view_fixed_sub': 'Sürekli açık ve sabit menü düzeni',
    },
    'en-US': {
      // General & Common
      'ok': 'OK',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'loading': 'Loading...',
      'save': 'Save',
      'success': 'Success',
      'error': 'Error',
      'warning': 'Warning',
      'close': 'Close',

      // Login & Auth
      'login': 'Login',
      'logout': 'Logout',
      'email_hint': 'Email Address',
      'password_hint': 'Password',
      'remember_me': 'Remember Me',
      'forgot_password': 'Forgot Password',
      'login_desc': 'Log in to your account to continue.',
      'error_title': 'Login Error Detail',
      'error_msg': 'Invalid email or password, please try again.',
      'empty_error': 'Please enter your email and password.',
      'login_failed': 'Login failed. Please check your credentials.',
      'session_expired_title': 'Session Expired',
      'session_expired_desc': 'Your session has ended for security.\nPlease log in again to continue.',
      'continue_working': 'Continue Working',

      // Company & Firm Selection
      'select_company': 'Select Company and Firm',
      'search_company': 'Search by company or firm name...',
      'no_company_found': 'No company or firm found matching your search.',
      'company_loading': 'Loading firms...',
      'click_to_see_firms': 'Tap to see firms',
      'firms_available': 'Firms Available',
      'no_sub_firm': 'No sub-firm found.',
      'connect_to_company': 'Connect to Company',
      'continue_btn': 'Continue',
      'search_results': 'Search Results',
      'companies_matched': 'Companies Matched',
      'firm_selection_fail': 'Firm selection failed. Please try again.',

      // Forgot Password
      'forgot_pwd_title': 'Forgot Password',
      'forgot_pwd_desc': 'Enter your registered email address, and we will send you a password reset link.',
      'forgot_pwd_btn': 'Send Link',
      'back_to_login': 'Back to Login',
      'forgot_pwd_success': 'Password reset link has been sent to your email address.',
      'forgot_pwd_fail': 'Operation failed or email not found.',
      'empty_email': 'Please enter your email address.',

      // Reconnection & Network Modals
      'reconnecting_title': 'Reconnecting',
      'reconnecting_desc': 'Connection to cloud server lost.\nTrying to reconnect, please wait...',
      'reconnect_btn': 'Reconnect',
      'reconnecting_btn_progress': 'Connecting...',
      'reload_page_btn': 'Reload Page',
      'no_internet_title': 'No Internet Connection',
      'no_internet_desc': 'Please check your internet connection and try again.',
      'timeout_title': 'Connection Timeout',
      'timeout_desc': 'Server did not respond or page load took too long. Please refresh your session.',
      'try_again_btn': 'Try Again',
      'relogin_btn': 'Login Again',

      // Multiple Session Warning
      'multiple_session_title': 'Multiple Session Warning',
      'multiple_session_subtitle': 'Logged in on another device with your credentials.',
      'multiple_session_bullet_yes': 'Yes: Maintain current session (new session will be closed)',
      'multiple_session_bullet_no': 'No: Terminate current session (new session will continue)',
      'multiple_session_yes_btn': 'Yes (Maintain Session)',
      'multiple_session_no_btn': 'No (Logout)',

      // Force Logout / Session Terminated Warning
      'force_logout_title': 'Session Terminated',
      'force_logout_desc': 'Another user logged in with your credentials, your session is being terminated.',
      'force_logout_btn': 'OK (Login Again)',

      // Login Info & Devices Logs
      'login_info_title': 'Login History',
      'login_info_subtitle': 'Your recent account access and device logs',
      'date_column': 'Date',
      'ip_column': 'IP Address',
      'device_column': 'Device Name',
      'no_login_logs': 'No login logs found.',

      // Theme Selection
      'theme_selection_title': 'Theme Selection',
      'theme_selection_subtitle': 'Customize app appearance theme',
      'theme_system': 'System Default',
      'theme_system_sub': 'Automatically matches device theme settings',
      'theme_light': 'Light Theme',
      'theme_light_sub': 'Bright and fresh appearance',
      'theme_dark': 'Dark Theme',
      'theme_dark_sub': 'Easy on the eyes dark appearance',

      // Menu View Selection
      'menu_view_title': 'Menu View',
      'menu_view_subtitle': 'Choose your navigation and menu layout',
      'menu_view_auth': 'Authorized Only',
      'menu_view_auth_sub': 'Displays only modules you have access permission to',
      'menu_view_all': 'All Modules',
      'menu_view_all_sub': 'Lists all system modules in the menu',
      'menu_view_popup': 'Dropdown Menu',
      'menu_view_popup_sub': 'Compact dropdown menu layout',
      'menu_view_fixed': 'Fixed Sidebar',
      'menu_view_fixed_sub': 'Always open fixed menu layout',
    },
  };
}
