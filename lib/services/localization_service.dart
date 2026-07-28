import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  String _currentLanguage = 'tr-TR';
  String get currentLanguage => _currentLanguage;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'tr-TR';
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  String translate(String key) {
    return _localizedStrings[_currentLanguage]?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _localizedStrings = {
    'tr-TR': {
      'login': 'Giriş Yap',
      'email_hint': 'E-Posta Adresi',
      'password_hint': 'Şifre',
      'remember_me': 'Beni Hatırla',
      'forgot_password': 'Şifremi Unuttum',
      'login_desc': 'Hesabınıza giriş yaparak devam edin.',
      'error_title': 'Giriş Hatası Detayı',
      'error_msg': 'E-Posta veya Şifre hatalıdır tekrar deneyiniz',
      'empty_error': 'Lütfen e-posta ve şifrenizi girin.',
      'login_failed': 'Giriş başarısız. Bilgilerinizi kontrol edin.',
      'ok': 'Tamam',
      
      // company_selection
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

      // forgot_password
      'forgot_pwd_title': 'Şifremi Unuttum',
      'forgot_pwd_desc': 'Kayıtlı e-posta adresinizi girin, şifre sıfırlama bağlantısını gönderelim.',
      'forgot_pwd_btn': 'Bağlantı Gönder',
      'back_to_login': 'Giriş Ekranına Dön',
      'forgot_pwd_success': 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.',
      'forgot_pwd_fail': 'İşlem başarısız oldu veya e-posta bulunamadı.',
      'empty_email': 'Lütfen e-posta adresinizi girin.',
    },
    'en-US': {
      'login': 'Login',
      'email_hint': 'Email Address',
      'password_hint': 'Password',
      'remember_me': 'Remember Me',
      'forgot_password': 'Forgot Password',
      'login_desc': 'Log in to your account to continue.',
      'error_title': 'Login Error',
      'error_msg': 'Invalid email or password, please try again.',
      'empty_error': 'Please enter your email and password.',
      'login_failed': 'Login failed. Please check your credentials.',
      'ok': 'OK',
      
      // company_selection
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

      // forgot_password
      'forgot_pwd_title': 'Forgot Password',
      'forgot_pwd_desc': 'Enter your registered email address, and we will send you a password reset link.',
      'forgot_pwd_btn': 'Send Link',
      'back_to_login': 'Back to Login',
      'forgot_pwd_success': 'Password reset link has been sent to your email address.',
      'forgot_pwd_fail': 'Operation failed or email not found.',
      'empty_email': 'Please enter your email address.',
    },
  };
}
