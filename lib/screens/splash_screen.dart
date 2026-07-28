import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../webview_screen.dart';
import 'company_selection_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  final DeepLinkService deepLinkService;

  const SplashScreen({super.key, required this.deepLinkService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _checkAutoLogin();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool rememberMe = prefs.getBool('remember_me') ?? false;
      final String email = prefs.getString('saved_email') ?? '';
      final String password = prefs.getString('saved_password') ?? '';
      final int? savedDbid = prefs.getInt('saved_dbid');
      final int? savedFirmaid = prefs.getInt('saved_firmaid');

      // Short delay for smooth UI transition
      await Future.delayed(const Duration(milliseconds: 1000));

      if (rememberMe && email.isNotEmpty && password.isNotEmpty) {
        final companies = await AuthService().loginAPI(email, password, rememberMe: rememberMe);

        if (companies != null && companies.isNotEmpty) {
          if (savedDbid != null && savedFirmaid != null) {
            final redirectUrl = await AuthService().selectFirmAPI(
              email,
              password,
              savedDbid,
              savedFirmaid,
              rememberMe: rememberMe,
            );

            if (mounted && redirectUrl != null && redirectUrl.isNotEmpty && !redirectUrl.contains('/auth/login')) {
              final fullUrl = redirectUrl.startsWith('http')
                  ? redirectUrl
                  : 'https://bymcloud.app$redirectUrl';

              // WebView açılmadan ÖNCE çerezleri CookieManager'a tam olarak yazıp bekle
              await AuthService().syncCookiesToWebView("https://bymcloud.app/");

              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      deepLinkService: widget.deepLinkService,
                      initialUrl: fullUrl,
                    ),
                  ),
                );
                return;
              }
            }
          }

          // If db/firm was not saved or auto-select failed, show Company Selection
          if (mounted) {
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
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Auto login error: $e");
    }

    // If auto login is disabled or fails, navigate to LoginScreen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(deepLinkService: widget.deepLinkService),
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
          // Arka Plan Gradyan Katmanı
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

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Kurumsal Logo Görseli
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/logo.png',
                      height: 145,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/app_icon.png',
                          height: 145,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(
                    color: Color(0xFF0075FF),
                    strokeWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundLinesPainter extends CustomPainter {
  final Animation<double>? animation;

  BackgroundLinesPainter({this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF0075FF).withValues(alpha: 0.075)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final circlePaint = Paint()
      ..color = const Color(0xFF0075FF).withValues(alpha: 0.055)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const double step = 35.0;
    final double shift = (animation?.value ?? 0.0) * step;

    for (double i = -size.height - (step * 2); i < size.width + (step * 2); i += step) {
      final double currentX = i + shift;
      canvas.drawLine(
        Offset(currentX, 0),
        Offset(currentX + size.height, size.height),
        linePaint,
      );
    }

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
