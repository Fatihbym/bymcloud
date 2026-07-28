import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'company_selection_screen.dart';
import 'forgot_password_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/localization_service.dart';

class LoginScreen extends StatefulWidget {
  final DeepLinkService deepLinkService;
  const LoginScreen({super.key, required this.deepLinkService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String _selectedLanguage = LocalizationService().currentLanguage;
  String _appVersion = '';

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadSavedCredentials();
    try {
      FlutterNativeSplash.remove();
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _emailController.text = prefs.getString('saved_email') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
        _rememberMe = prefs.getBool('remember_me') ?? true;
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    await prefs.setBool('remember_me', true);
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);
  }

  void _toggleRememberMe(bool val) async {
    setState(() => _rememberMe = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', val);
    if (!val) {
      await prefs.remove('saved_email');
      await prefs.remove('saved_password');
    } else {
      if (_emailController.text.isNotEmpty) {
        await prefs.setString('saved_email', _emailController.text.trim());
      }
      if (_passwordController.text.isNotEmpty) {
        await prefs.setString('saved_password', _passwordController.text.trim());
      }
    }
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService().translate('empty_error'),
            style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.orangeAccent.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final companies = await AuthService().loginAPI(email, password, rememberMe: _rememberMe);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (companies != null && companies.isNotEmpty) {
        if (_rememberMe) {
          await _saveCredentials(email, password);
        } else {
          await _clearCredentials();
        }

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CompanySelectionScreen(
              deepLinkService: widget.deepLinkService,
              companies: companies,
              email: email,
              password: password,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService().translate('login_failed'),
              style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: Colors.redAccent.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            LocalizationService().translate('error_title'), 
            style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.bold)
          ),
          content: SingleChildScrollView(
            child: Text(
              LocalizationService().translate('error_msg'), 
              style: const TextStyle(fontFamily: 'Nunito Sans')
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                LocalizationService().translate('ok'), 
                style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.bold)
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Arka Plan Gradyan Yapılandırması
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEDF2F7), Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
                ),
              ),
            ),
          ),

          // Arka Plan Çizgi Animasyon Yapılandırması
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundLinesPainter(animation: _animController),
            ),
          ),

          // Dil Seçimi Modülü (TR / EN)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        LocalizationService().setLanguage('tr-TR');
                        setState(() => _selectedLanguage = 'tr-TR');
                      },
                      child: Text(
                        'TR',
                        style: TextStyle(
                          fontFamily: 'Nunito Sans',
                          fontSize: 14,
                          fontWeight: _selectedLanguage == 'tr-TR' ? FontWeight.w800 : FontWeight.w600,
                          color: _selectedLanguage == 'tr-TR' ? const Color(0xFF0075FF) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const Text(
                      ' / ',
                      style: TextStyle(
                        fontFamily: 'Nunito Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        LocalizationService().setLanguage('en-US');
                        setState(() => _selectedLanguage = 'en-US');
                      },
                      child: Text(
                        'EN',
                        style: TextStyle(
                          fontFamily: 'Nunito Sans',
                          fontSize: 14,
                          fontWeight: _selectedLanguage == 'en-US' ? FontWeight.w800 : FontWeight.w600,
                          color: _selectedLanguage == 'en-US' ? const Color(0xFF0075FF) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Giriş Formu ve Kullanıcı Arayüzü Bileşenleri
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Kurumsal Logo Görseli
                    Hero(
                      tag: 'app_logo',
                      child: Image.asset(
                        'assets/logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/app_icon.png',
                            height: 120,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bulut ERP',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Nunito Sans',
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Giriş Kartı
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService().translate('login'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito Sans',
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            LocalizationService().translate('login_desc'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Nunito Sans',
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // E-Posta Input Girişi
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                              fontFamily: 'Nunito Sans',
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: LocalizationService().translate('email_hint'),
                              hintStyle: const TextStyle(fontFamily: 'Nunito Sans', color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8), size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF0075FF), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Şifre Input Girişi
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            style: const TextStyle(
                              fontFamily: 'Nunito Sans',
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: LocalizationService().translate('password_hint'),
                              hintStyle: const TextStyle(fontFamily: 'Nunito Sans', color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                              prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF94A3B8), size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF0075FF), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Beni Hatırla & Şifremi Unuttum Satırı
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () {
                                  _toggleRememberMe(!_rememberMe);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (val) {
                                            _toggleRememberMe(val ?? false);
                                          },
                                          activeColor: const Color(0xFF0075FF),
                                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        LocalizationService().translate('remember_me'),
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Nunito Sans',
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0075FF),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  LocalizationService().translate('forgot_password'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito Sans',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Modern Giriş Butonu
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0075FF),
                                disabledBackgroundColor: const Color(0xFF0075FF).withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      LocalizationService().translate('login'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Nunito Sans',
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // App Version
                    if (_appVersion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          'v$_appVersion',
                          style: const TextStyle(
                            fontFamily: 'Nunito Sans',
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Arka Plan Çizgi Animasyon Motoru
class BackgroundLinesPainter extends CustomPainter {
  final Animation<double>? animation;

  BackgroundLinesPainter({this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Çizgi Grafiği Çizim Yapılandırması
    final linePaint = Paint()
      ..color = const Color(0xFF0075FF).withValues(alpha: 0.075)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Odak Halkaları Çizim Yapılandırması
    final circlePaint = Paint()
      ..color = const Color(0xFF0075FF).withValues(alpha: 0.055)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double step = 35.0;
    final double shift = (animation?.value ?? 0.0) * step;

    // Çapraz Çizgi Render Döngüsü
    for (double i = -size.height - (step * 2); i < size.width + (step * 2); i += step) {
      final double currentX = i + shift;
      canvas.drawLine(
        Offset(currentX, 0),
        Offset(currentX + size.height, size.height),
        linePaint,
      );
    }

    // Odak Halka Render Döngüsü
    final double pulse = (animation?.value ?? 0.0) * 12.0;

    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 100 + pulse, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 180 + pulse, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.1), 260 + pulse, circlePaint);

    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.85), 140 - pulse, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.85), 220 - pulse, circlePaint);
  }

  @override
  bool shouldRepaint(covariant BackgroundLinesPainter oldDelegate) => true;
}