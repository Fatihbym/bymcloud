import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/localization_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  InAppWebViewController? _webViewController;
  bool _isWebViewLoaded = false;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleResult(String result) {
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService().translate('forgot_pwd_success'),
            style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService().translate('forgot_pwd_fail'),
            style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    }
  }

  void _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService().translate('empty_email'),
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

    if (!_isWebViewLoaded) {
      await Future.delayed(const Duration(seconds: 2));
    }

    if (_webViewController != null) {
      String safeEmail = email.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('"', '\\"');

      String jsCode = '''
        function attemptForgotPassword() {
          // Find the "Şifremi Unuttum" link/button
          var allElements = document.querySelectorAll('a, button, span');
          var forgotBtn = Array.from(allElements).find(el => 
            el.innerText && el.innerText.trim().toLowerCase() === 'şifremi unuttum' ||
            el.innerText && el.innerText.trim().toLowerCase() === 'şifremi unuttum?'
          );
          
          if(forgotBtn) {
            forgotBtn.click();
            
            // Wait for modal to appear
            const observer = new MutationObserver((mutations) => {
              var modal = document.getElementById('forgotPasswordModal') || document.querySelector('.modal.show');
              if (modal && modal.style.display !== 'none') {
                observer.disconnect();
                
                setTimeout(() => {
                  var emailInput = modal.querySelector('input[type="email"]');
                  var submitBtn = Array.from(modal.querySelectorAll('button')).find(b => b.innerText && b.innerText.trim() === 'Gönder');
                  
                  if (emailInput && submitBtn) {
                    emailInput.focus();
                    emailInput.value = '$safeEmail';
                    emailInput.dispatchEvent(new Event('input', { bubbles: true }));
                    emailInput.dispatchEvent(new Event('change', { bubbles: true }));
                    emailInput.blur();
                    
                    submitBtn.click();
                    
                    setTimeout(() => {
                      window.flutter_inappwebview.callHandler('forgotResult', 'success');
                    }, 2000);
                  } else {
                    window.flutter_inappwebview.callHandler('forgotResult', 'error_modal_inputs');
                  }
                }, 1000);
              }
            });
            
            observer.observe(document.body, { childList: true, subtree: true, attributes: true });
            
            setTimeout(() => {
              window.flutter_inappwebview.callHandler('forgotResult', 'error_timeout');
            }, 8000);
          } else {
            window.flutter_inappwebview.callHandler('forgotResult', 'error_btn_not_found');
          }
        }
        attemptForgotPassword();
      ''';
      await _webViewController!.evaluateJavascript(source: jsCode);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Arka Plan Gradyan Katmanı
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

          // 2. Arka Plan Şeffaf Çizgiler Katmanı
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundLinesPainter(animation: _animController),
            ),
          ),

          // 3. Gizli InAppWebView
          Offstage(
            offstage: true,
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://bymcloud.app/auth/login")),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'forgotResult',
                  callback: (args) {
                    if (args.isNotEmpty) {
                      _handleResult(args[0].toString());
                    }
                  },
                );
              },
              onLoadStop: (controller, url) {
                _isWebViewLoaded = true;
              },
            ),
          ),
          // 5. Ana Form İçeriği (Login ekranı ile tam uyumlu)
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
                    const SizedBox(height: 20),
                    Text(
                      LocalizationService().translate('forgot_pwd_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nunito Sans',
                        color: Color(0xFF0075FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      LocalizationService().translate('forgot_pwd_desc'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Nunito Sans',
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // E-Posta Input Girişi
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
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
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
                    const SizedBox(height: 28),

                    // Modern Gönder Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
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
                                LocalizationService().translate('forgot_pwd_btn'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Nunito Sans',
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF64748B)),
                      label: Text(
                        LocalizationService().translate('back_to_login'),
                        style: const TextStyle(
                          fontFamily: 'Nunito Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
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
