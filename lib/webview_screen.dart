import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Projenizdeki mevcut servisler
import 'services/deep_link_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/company_selection_screen.dart';
import 'widgets/login_info_bottom_sheet.dart';
import 'widgets/theme_selection_bottom_sheet.dart';
import 'widgets/menu_view_selection_bottom_sheet.dart';

class WebViewScreen extends StatefulWidget {
  final DeepLinkService deepLinkService;
  final String? initialUrl;

  const WebViewScreen({super.key, required this.deepLinkService, this.initialUrl});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  
  bool _isReloading = false;
  bool _isFirstLoad = true;
  bool _hasInternet = true;
  bool _hasTimeoutError = false; 
  bool _isLoggingOut = false;
  bool _showSessionExpiredModal = false;
  bool _isReauthenticatingFromModal = false;
  bool _isMobileAuthNavigating = false;
  bool _isShowingCompanySelectionSheet = false;
  bool _isShowingLoginInfoSheet = false;
  bool _isShowingThemeSheet = false;
  bool _isShowingMenuViewSheet = false;
  
  Timer? _loadingTimeoutTimer;
  DateTime? currentBackPressTime;

  Future<void> _openMenuViewSelectionBottomSheet() async {
    if (_isShowingMenuViewSheet || !mounted) return;
    _isShowingMenuViewSheet = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentViewMode = prefs.getString('saved_menu_view_mode') ?? 'authorized';
      if (!mounted) return;

      final String? selectedMode = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MenuViewSelectionBottomSheet(
          currentViewMode: currentViewMode,
        ),
      );

      if (selectedMode != null && mounted) {
        await prefs.setString('saved_menu_view_mode', selectedMode);
        await _applyMenuViewToWebView(selectedMode);
      }
    } catch (e) {
      debugPrint("Menu view selection sheet error: $e");
    } finally {
      _isShowingMenuViewSheet = false;
      await _cleanUpWebModals();
    }
  }

  Future<void> _applyMenuViewToWebView([String? viewMode]) async {
    if (_webViewController == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedMode = viewMode ?? prefs.getString('saved_menu_view_mode') ?? 'authorized';

      await _webViewController!.evaluateJavascript(source: """
        (function() {
          try {
            var targetKeyword = '';
            if ('$selectedMode' === 'authorized') targetKeyword = 'yetkili';
            else if ('$selectedMode' === 'package') targetKeyword = 'paket';
            else if ('$selectedMode' === 'all') targetKeyword = 'tüm modüller';

            if (!targetKeyword) return;

            var menuItems = document.querySelectorAll('.sub-menu *, dxbl-popup *, .user-popup-wrapper *, .user-popup-item *');
            for (var i = 0; i < menuItems.length; i++) {
              var t = (menuItems[i].innerText || menuItems[i].textContent || '').trim().toLowerCase();
              if (t.indexOf(targetKeyword) !== -1) {
                menuItems[i].click();
                break;
              }
            }
          } catch(e) {}
        })();
      """);
    } catch (e) {
      debugPrint("Apply menu view error: $e");
    }
  }

  Future<void> _openThemeSelectionBottomSheet() async {
    if (_isShowingThemeSheet || !mounted) return;
    _isShowingThemeSheet = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentTheme = prefs.getString('saved_theme_mode') ?? 'system';
      if (!mounted) return;

      final String? selectedTheme = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ThemeSelectionBottomSheet(
          currentTheme: currentTheme,
        ),
      );

      if (selectedTheme != null && mounted) {
        await prefs.setString('saved_theme_mode', selectedTheme);
        await _applyThemeToWebView(selectedTheme);
      }
    } catch (e) {
      debugPrint("Theme selection sheet error: $e");
    } finally {
      _isShowingThemeSheet = false;
      await _cleanUpWebModals();
    }
  }

  Future<void> _applyThemeToWebView([String? themeMode]) async {
    if (_webViewController == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedTheme = themeMode ?? prefs.getString('saved_theme_mode') ?? 'system';

      bool isDark = false;
      if (selectedTheme == 'dark') {
        isDark = true;
      } else if (selectedTheme == 'light') {
        isDark = false;
      } else {
        if (mounted) {
          isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
        } else {
          isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
        }
      }

      final bsTheme = isDark ? 'dark' : 'light';

      await _webViewController!.evaluateJavascript(source: """
        (function() {
          try {
            document.documentElement.setAttribute('data-bs-theme', '$bsTheme');
            document.documentElement.setAttribute('data-theme', '$bsTheme');
            if ($isDark) {
              document.documentElement.classList.add('dark', 'dark-mode');
              if (document.body) document.body.classList.add('dark', 'dark-mode');
            } else {
              document.documentElement.classList.remove('dark', 'dark-mode');
              if (document.body) document.body.classList.remove('dark', 'dark-mode');
            }
          } catch(e) {}
        })();
      """);
    } catch (e) {
      debugPrint("Apply theme error: $e");
    }
  }

  Future<void> _openLoginInfoBottomSheet(List<Map<String, String>> logs) async {
    if (_isShowingLoginInfoSheet || !mounted) return;
    _isShowingLoginInfoSheet = true;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => LoginInfoBottomSheet(loginLogs: logs),
      );
    } catch (e) {
      debugPrint("Login info bottom sheet error: $e");
    } finally {
      _isShowingLoginInfoSheet = false;
      await _cleanUpWebModals();
    }
  }

  Future<void> _cleanUpWebModals() async {
    if (_webViewController == null) return;
    try {
      await _webViewController!.evaluateJavascript(source: """
        (function() {
          document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, .company-tree, .company-tree-scroll, dxbl-modal-backdrop, .dxbl-modal-backdrop, .dxbl-popup-backdrop, .modal-backdrop, .dxbl-popup-portal').forEach(function(el) {
            el.setAttribute('data-native-handled', 'true');
            try {
              el.style.setProperty('display', 'none', 'important');
              el.style.setProperty('visibility', 'hidden', 'important');
              el.style.setProperty('opacity', '0', 'important');
              el.style.setProperty('pointer-events', 'none', 'important');
            } catch(_) {}
          });

          if (document.body) {
            document.body.classList.remove('dxbl-modal-open', 'modal-open', 'dxbl-popup-open', 'dxbl-overflow-hidden');
            document.body.style.removeProperty('pointer-events');
            document.body.style.removeProperty('overflow');
            document.body.style.removeProperty('touch-action');
          }
          if (document.documentElement) {
            document.documentElement.classList.remove('dxbl-modal-open', 'modal-open', 'dxbl-popup-open', 'dxbl-overflow-hidden');
            document.documentElement.style.removeProperty('pointer-events');
            document.documentElement.style.removeProperty('overflow');
            document.documentElement.style.removeProperty('touch-action');
          }

          try {
            var closeBtn = document.querySelector('button[aria-label="Close"], .dxbl-popup-header-button, [data-dismiss="modal"]');
            if (closeBtn) {
              closeBtn.click();
            }
          } catch(_) {}
        })();
      """);
    } catch (_) {}
  }

  Future<void> _openCompanySelectionBottomSheet() async {
    if (_isShowingCompanySelectionSheet || !mounted) return;
    _isShowingCompanySelectionSheet = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0075FF)),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final String email = prefs.getString('saved_email') ?? '';
      final String password = prefs.getString('saved_password') ?? '';
      final bool rememberMe = prefs.getBool('remember_me') ?? true;

      if (email.isEmpty || password.isEmpty) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Oturum bilgisi bulunamadı, lütfen tekrar giriş yapınız.',
                style: TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }

      final companies = await AuthService().loginAPI(email, password, rememberMe: rememberMe);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (companies != null && companies.isNotEmpty && mounted) {
        final String? redirectUrl = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CompanySelectionScreen(
            deepLinkService: widget.deepLinkService,
            companies: companies,
            email: email,
            password: password,
            isBottomSheet: true,
          ),
        );

        if (redirectUrl != null && redirectUrl.isNotEmpty && mounted) {
          final fullUrl = redirectUrl.startsWith('http')
              ? redirectUrl
              : 'https://bymcloud.app$redirectUrl';

          await AuthService().syncCookiesToWebView("https://bymcloud.app/");
          if (_webViewController != null) {
            try {
              await _webViewController!.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri(fullUrl),
                  headers: {
                    if (AuthService().sessionCookie != null && AuthService().sessionCookie!.isNotEmpty)
                      'Cookie': AuthService().sessionCookie!,
                  },
                ),
              );
            } catch (_) {}
          }
        } else if (mounted) {
          await _cleanUpWebModals();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Şirket listesi alınamadı.',
              style: TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.redAccent.shade700,
          ),
        );
      }
    } catch (e) {
      debugPrint("Company selection sheet load error: $e");
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }
    } finally {
      _isShowingCompanySelectionSheet = false;
      await _cleanUpWebModals();
    }
  }
  
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late final StreamSubscription<Uri> _deepLinkSubscription;
  late PullToRefreshController pullToRefreshController;

  void _syncCookies() async {
    await AuthService().syncCookiesToWebView(widget.initialUrl ?? "https://bymcloud.app/");
  }

  @override
  void initState() {
    super.initState();

    PlatformInAppWebViewController.debugLoggingSettings.enabled = false;
    _syncCookies();

    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(
        color: Colors.black87,
        backgroundColor: Colors.white,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          try {
            _webViewController?.reload();
          } catch (_) {}
        } else if (Platform.isIOS) {
          try {
            _webViewController?.loadUrl(urlRequest: URLRequest(url: await _webViewController?.getUrl()));
          } catch (_) {}
        }
      },
    );
    
    _deepLinkSubscription = widget.deepLinkService.uriStream.listen((Uri uri) {
      if (_webViewController != null && !_isLoggingOut) {
        try {
          _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
        } catch (_) {}
      }
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasNoInternet = results.length == 1 && results.first == ConnectivityResult.none;
      final hasInternet = !hasNoInternet;
      if (mounted && _hasInternet != hasInternet) {
        setState(() {
          _hasInternet = hasInternet;
        });
        if (hasInternet && !_isFirstLoad && !_isLoggingOut) {
          _reloadPage();
        }
      }
    });
  }

  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    _connectivitySubscription.cancel();
    _deepLinkSubscription.cancel();
    super.dispose();
  }

  void _reloadPage() {
    if (!mounted) return;
    setState(() {
      _isReloading = true;
      _hasTimeoutError = false; 
    });
    
    try {
      if (_webViewController != null) {
        _webViewController!.reload();
      }
    } catch (e) {
      debugPrint("WebView Reload Exception: $e");
    }
  }

  bool _isLoginOrLogoutUrl(WebUri? url) {
    if (url == null) return false;
    final path = url.path.toLowerCase();
    final full = url.toString().toLowerCase();
    return path.contains('/auth/login') || 
           path.endsWith('/login') || 
           path.contains('/auth/logout') || 
           path.endsWith('/logout') ||
           path.contains('/account/login') ||
           path.contains('/account/logout') ||
           path.contains('/cikis') ||
           path.endsWith('/cikis') ||
           full.contains('/auth/login') ||
           full.contains('/auth/logout') ||
           full.contains('logout=') ||
           full.contains('action=logout');
  }

  void _startLoadingTimeoutTimer() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          _hasTimeoutError = true; 
          _isFirstLoad = false;
          _isReloading = false;
          _isMobileAuthNavigating = false;
        });
      }
    });
  }

  void _cancelLoadingTimeoutTimer() {
    _loadingTimeoutTimer?.cancel();
  }

  Future<void> _handleContinueWorking() async {
    if (_isReauthenticatingFromModal) return;
    if (mounted) {
      setState(() {
        _isReauthenticatingFromModal = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool rememberMe = prefs.getBool('remember_me') ?? false;
      final String email = prefs.getString('saved_email') ?? '';
      final String password = prefs.getString('saved_password') ?? '';
      final int? savedDbid = prefs.getInt('saved_dbid');
      final int? savedFirmaid = prefs.getInt('saved_firmaid');

      if (rememberMe && email.isNotEmpty && password.isNotEmpty && savedDbid != null && savedFirmaid != null) {
        final companies = await AuthService().loginAPI(email, password, rememberMe: true);
        if (companies != null && companies.isNotEmpty) {
          final redirectUrl = await AuthService().selectFirmAPI(
            email,
            password,
            savedDbid,
            savedFirmaid,
            rememberMe: true,
          );

          if (redirectUrl != null && redirectUrl.isNotEmpty && !redirectUrl.contains('/auth/login')) {
            final fullUrl = redirectUrl.startsWith('http')
                ? redirectUrl
                : 'https://bymcloud.app$redirectUrl';

            await AuthService().syncCookiesToWebView("https://bymcloud.app/");
            if (_webViewController != null) {
              try {
                await _webViewController!.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri(fullUrl),
                    headers: {
                      if (AuthService().sessionCookie != null && AuthService().sessionCookie!.isNotEmpty)
                        'Cookie': AuthService().sessionCookie!,
                    },
                  ),
                );
              } catch (_) {}
            }
            if (mounted) {
              setState(() {
                _showSessionExpiredModal = false;
                _isReauthenticatingFromModal = false;
              });
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Continue working auto-reauth error: $e");
    }

    if (mounted) {
      setState(() {
        _isReauthenticatingFromModal = false;
        _showSessionExpiredModal = false;
      });
    }
    _triggerNativeLogout();
  }

  void _triggerNativeLogout() {
    if (_isLoggingOut) return;
    if (mounted) {
      setState(() {
        _isLoggingOut = true;
      });
    }
    _handleLogout();
  }

  void _handleLogout() async {
    try {
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
    } catch (e) {
      debugPrint("Cookie delete error: $e");
    }
    await AuthService().logout();
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
    if (_isLoggingOut) {
      return const Scaffold(
        backgroundColor: Color(0xFFFCFCFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0075ff)),
        ),
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_webViewController != null) {
          try {
            if (await _webViewController!.canGoBack()) {
              _webViewController!.goBack();
              return;
            }
          } catch (_) {}
        }

        DateTime now = DateTime.now();
        if (currentBackPressTime == null || now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
          currentBackPressTime = now;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Çıkmak için tekrar basın'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          // KESİN ÇÖZÜM: InAppWebView HER ZAMAN ağaçta kalır.
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.initialUrl ?? "https://bymcloud.app/"),
                  headers: {
                    if (AuthService().sessionCookie != null && AuthService().sessionCookie!.isNotEmpty)
                      'Cookie': AuthService().sessionCookie!,
                  },
                ),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useHybridComposition: true,
                  allowsBackForwardNavigationGestures: true,
                  thirdPartyCookiesEnabled: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: false,
                ),
                onDownloadStartRequest: (controller, downloadStartRequest) async {
                  debugPrint("File Download Requested: ${downloadStartRequest.url}");
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final Uri downloadUri = Uri.parse(downloadStartRequest.url.toString());
                    final filename = downloadStartRequest.suggestedFilename ?? 'Dosya';

                    if (await canLaunchUrl(downloadUri)) {
                      await launchUrl(
                        downloadUri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'İndirme başlatıldı: $filename',
                              style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: const Color(0xFF0075FF),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } else {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Dosya indirme başlatılamadı: $filename',
                              style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: Colors.redAccent.shade700,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint("File Download Error: $e");
                  }
                },
                initialUserScripts: UnmodifiableListView([
                  UserScript(
                    source: """
                      if (!window._logoutListenerAdded) {
                        window._logoutListenerAdded = true;
                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li, form') : null;
                          if (target) {
                            var text = (target.innerText || target.textContent || '').trim().toLowerCase();
                            var href = (target.getAttribute && target.getAttribute('href')) ? target.getAttribute('href').toLowerCase() : '';
                            var action = (target.getAttribute && target.getAttribute('action')) ? target.getAttribute('action').toLowerCase() : '';
                            var title = (target.getAttribute && target.getAttribute('title')) ? target.getAttribute('title').toLowerCase() : '';
                            
                            var isLogoutText = text.indexOf('oturumu kapat') !== -1 || 
                                               text.indexOf('oturum kapat') !== -1 || 
                                               text.indexOf('çıkış yap') !== -1 || 
                                               text.indexOf('cikis yap') !== -1 ||
                                               text.indexOf('çıkış') !== -1 ||
                                               text.indexOf('cikis') !== -1 ||
                                               text.indexOf('logout') !== -1 ||
                                               text.indexOf('log out') !== -1 ||
                                               text.indexOf('sign out') !== -1 ||
                                               text.indexOf('signout') !== -1;
                                               
                            var isLogoutUrl = href.indexOf('/logout') !== -1 || 
                                              href.indexOf('/auth/logout') !== -1 || 
                                              href.indexOf('/cikis') !== -1 ||
                                              action.indexOf('/logout') !== -1 ||
                                              action.indexOf('/auth/logout') !== -1;
                                              
                            var isLogoutTitle = title.indexOf('çıkış') !== -1 || title.indexOf('logout') !== -1 || title.indexOf('oturum') !== -1;

                            if (isLogoutText || isLogoutUrl || isLogoutTitle) {
                              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                window.flutter_inappwebview.callHandler('onExplicitLogoutClicked');
                              }
                            }
                          }
                        }, true);
                      }

                      if (!window._companySelectionListenerAdded) {
                        window._companySelectionListenerAdded = true;
                        var _lastCompanyModalTrigger = 0;
                        
                        if (!document.getElementById('_nativeCompanyStyle')) {
                          var styleNode = document.createElement('style');
                          styleNode.id = '_nativeCompanyStyle';
                          styleNode.innerHTML = 'dxbl-modal-root[data-native-handled="true"], .dxbl-modal-root[data-native-handled="true"], .company-tree[data-native-handled="true"], .company-tree-scroll[data-native-handled="true"] { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; position: absolute !important; top: -9999px !important; }';
                          (document.head || document.documentElement).appendChild(styleNode);
                        }

                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li') : null;
                          if (target) {
                            var text = (target.innerText || target.textContent || '').trim().toLowerCase();
                            var className = (target.className || '').toString().toLowerCase();
                            
                            var isFirmaButton = text.indexOf('firma değiştir') !== -1 || 
                                                text.indexOf('firma degistir') !== -1 || 
                                                text.indexOf('şirket değiştir') !== -1 || 
                                                text.indexOf('sirket degistir') !== -1 ||
                                                text.indexOf('firma seç') !== -1 ||
                                                text.indexOf('firma sec') !== -1 ||
                                                (className.indexOf('user-popup-item') !== -1 && (text.indexOf('firma') !== -1 || text.indexOf('değiştir') !== -1 || text.indexOf('degistir') !== -1));
                                                
                            if (isFirmaButton) {
                              var now = Date.now();
                              if (now - _lastCompanyModalTrigger > 2000) {
                                _lastCompanyModalTrigger = now;
                                setTimeout(function() {
                                  document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, .company-tree, .company-tree-scroll').forEach(function(m) {
                                    m.setAttribute('data-native-handled', 'true');
                                  });
                                }, 80);

                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onCompanySelectionRequested');
                                }
                              }
                            }
                          }
                        }, true);

                        function checkCompanyModalCard() {
                          var modals = document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, .company-tree, .company-tree-scroll');
                          for (var i = 0; i < modals.length; i++) {
                            var modal = modals[i];
                            if (modal.getAttribute('data-native-handled') === 'true') {
                              continue;
                            }

                            var text = (modal.innerText || modal.textContent || '');
                            var isCompanyModal = modal.classList.contains('company-tree') || 
                                                 modal.classList.contains('company-tree-scroll') || 
                                                 text.indexOf('Seçim Yapınız') !== -1 || 
                                                 text.indexOf('Secim Yapiniz') !== -1;

                            if (isCompanyModal) {
                              modal.setAttribute('data-native-handled', 'true');
                              var rootModal = modal.closest('dxbl-modal-root, .dxbl-modal-root');
                              if (rootModal) {
                                rootModal.setAttribute('data-native-handled', 'true');
                              }

                              var now = Date.now();
                              if (now - _lastCompanyModalTrigger > 2000) {
                                _lastCompanyModalTrigger = now;
                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onCompanySelectionRequested');
                                }
                              }
                            }
                          }
                        }

                        var companyObserver = new MutationObserver(checkCompanyModalCard);
                        companyObserver.observe(document.body || document.documentElement, { childList: true, subtree: true });
                        checkCompanyModalCard();
                      }

                      if (!window._loginInfoListenerAdded) {
                        window._loginInfoListenerAdded = true;
                        var _lastLoginInfoTrigger = 0;

                        function tryExtractAndOpenLoginInfo() {
                          var attempts = 0;
                          var maxAttempts = 15;
                          
                          var interval = setInterval(function() {
                            attempts++;
                            var modals = document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, dxbl-modal-dialog, .dxbl-popup');
                            var found = false;
                            
                            for (var i = 0; i < modals.length; i++) {
                              var m = modals[i];
                              var mText = (m.innerText || m.textContent || '');
                              
                              var isLoginModal = mText.indexOf('Bilgisayar Adı') !== -1 || 
                                                 mText.indexOf('Bilgisayar Adi') !== -1 ||
                                                 mText.indexOf('IP') !== -1 ||
                                                 mText.indexOf('Tarih') !== -1 ||
                                                 m.querySelector('.dxbl-grid') !== null ||
                                                 m.querySelector('table') !== null;
                                                 
                              if (isLoginModal) {
                                var logs = [];
                                var rows = m.querySelectorAll('tbody tr');
                                for (var r = 0; r < rows.length; r++) {
                                  var cells = rows[r].querySelectorAll('td[role="gridcell"], td');
                                  if (cells.length >= 3) {
                                    var dateVal = (cells[0].innerText || cells[0].textContent || '').trim();
                                    var ipVal = (cells[1].innerText || cells[1].textContent || '').trim();
                                    var devVal = (cells[2].innerText || cells[2].textContent || '').trim();
                                    if (dateVal || ipVal || devVal) {
                                      logs.push({ date: dateVal, ip: ipVal, device: devVal });
                                    }
                                  }
                                }
                                
                                if (logs.length > 0 || attempts >= maxAttempts) {
                                  found = true;
                                  clearInterval(interval);
                                  
                                  var rootM = m.closest('dxbl-modal-root, .dxbl-modal-root') || m;
                                  rootM.setAttribute('data-native-handled', 'true');
                                  
                                  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                    window.flutter_inappwebview.callHandler('onLoginInfoRequested', logs);
                                  }
                                  break;
                                }
                              }
                            }
                            
                            if (!found && attempts >= maxAttempts) {
                              clearInterval(interval);
                              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                window.flutter_inappwebview.callHandler('onLoginInfoRequested', []);
                              }
                            }
                          }, 100);
                        }

                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li') : null;
                          if (target) {
                            var text = (target.innerText || target.textContent || '').trim().toLowerCase();
                            var className = (target.className || '').toString().toLowerCase();
                            
                            var isLoginInfoBtn = text.indexOf('giriş bilgisi') !== -1 || 
                                                 text.indexOf('giris bilgisi') !== -1 || 
                                                 text.indexOf('giriş bilgiler') !== -1 || 
                                                 text.indexOf('giris bilgiler') !== -1 ||
                                                 (className.indexOf('user-popup-item') !== -1 && (text.indexOf('giriş') !== -1 || text.indexOf('giris') !== -1));
                                                 
                            if (isLoginInfoBtn) {
                              var now = Date.now();
                              if (now - _lastLoginInfoTrigger > 1500) {
                                _lastLoginInfoTrigger = now;
                                tryExtractAndOpenLoginInfo();
                              }
                            }
                          }
                        }, true);

                        function checkLoginInfoModalCard() {
                          var modals = document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root');
                          for (var i = 0; i < modals.length; i++) {
                            var modal = modals[i];
                            if (modal.getAttribute('data-native-handled') === 'true') {
                              continue;
                            }

                            var text = (modal.innerText || modal.textContent || '');
                            var isLoginInfoModal = text.indexOf('Bilgisayar Adı') !== -1 || 
                                                   text.indexOf('Bilgisayar Adi') !== -1 ||
                                                   (text.indexOf('Tarih') !== -1 && text.indexOf('IP') !== -1);

                            if (isLoginInfoModal) {
                              var now = Date.now();
                              if (now - _lastLoginInfoTrigger > 1500) {
                                _lastLoginInfoTrigger = now;
                                tryExtractAndOpenLoginInfo();
                              }
                            }
                          }
                        }

                        var loginInfoObserver = new MutationObserver(checkLoginInfoModalCard);
                        loginInfoObserver.observe(document.body || document.documentElement, { childList: true, subtree: true });
                        checkLoginInfoModalCard();
                      }

                      if (!window._themeSelectionListenerAdded) {
                        window._themeSelectionListenerAdded = true;
                        var _lastThemeModalTrigger = 0;

                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li, i') : null;
                          if (target) {
                            var popupItem = target.closest('.user-popup-item') || target;
                            var text = (popupItem.innerText || popupItem.textContent || '').trim().toLowerCase();
                            var className = (popupItem.className || '').toString().toLowerCase();
                            var hasPalette = popupItem.querySelector ? (popupItem.querySelector('.fa-palette, .fa-paint-brush') !== null) : false;
                            if (!hasPalette && target.className && target.className.toString().indexOf('fa-palette') !== -1) {
                              hasPalette = true;
                            }

                            var isThemeBtn = (text === 'tema') || 
                                             (text.indexOf('tema') !== -1 && (hasPalette || className.indexOf('user-popup-item') !== -1)) ||
                                             (hasPalette && (text.indexOf('tema') !== -1 || text.length < 15));

                            if (isThemeBtn) {
                              var now = Date.now();
                              if (now - _lastThemeModalTrigger > 1500) {
                                _lastThemeModalTrigger = now;

                                try {
                                  e.preventDefault();
                                  e.stopPropagation();
                                } catch(_) {}

                                setTimeout(function() {
                                  document.querySelectorAll('.user-popup-wrapper .sub-menu, dxbl-modal-root, .dxbl-modal-root').forEach(function(m) {
                                    m.setAttribute('data-native-handled', 'true');
                                  });
                                }, 80);

                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onThemeSelectionRequested');
                                }
                              }
                            }
                          }
                        }, true);
                      }

                      if (!window._menuViewSelectionListenerAdded) {
                        window._menuViewSelectionListenerAdded = true;
                        var _lastMenuViewModalTrigger = 0;

                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li, i') : null;
                          if (target) {
                            var popupItem = target.closest('.user-popup-item') || target;
                            var text = (popupItem.innerText || popupItem.textContent || '').trim().toLowerCase();
                            var className = (popupItem.className || '').toString().toLowerCase();
                            var hasEye = popupItem.querySelector ? (popupItem.querySelector('.fa-eye') !== null) : false;
                            if (!hasEye && target.className && target.className.toString().indexOf('fa-eye') !== -1) {
                              hasEye = true;
                            }

                            var isMenuViewBtn = (text.indexOf('menü görünümü') !== -1 || text.indexOf('menu gorunumu') !== -1) ||
                                                (hasEye && (text.indexOf('görünüm') !== -1 || text.indexOf('gorunum') !== -1 || text.indexOf('menü') !== -1 || text.indexOf('menu') !== -1));

                            if (isMenuViewBtn) {
                              var now = Date.now();
                              if (now - _lastMenuViewModalTrigger > 1500) {
                                _lastMenuViewModalTrigger = now;

                                try {
                                  e.preventDefault();
                                  e.stopPropagation();
                                } catch(_) {}

                                setTimeout(function() {
                                  document.querySelectorAll('.user-popup-wrapper .sub-menu, dxbl-modal-root, .dxbl-modal-root').forEach(function(m) {
                                    m.setAttribute('data-native-handled', 'true');
                                  });
                                }, 80);

                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onMenuViewSelectionRequested');
                                }
                              }
                            }
                          }
                        }, true);
                      }
                    """,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                onConsoleMessage: (controller, consoleMessage) {
                  if (kDebugMode && consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
                    debugPrint("Web Error: ${consoleMessage.message}");
                  }
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url;
                  if (_isLoginOrLogoutUrl(url)) {
                    if (!_isLoggingOut) {
                      if (_isFirstLoad && AuthService().sessionCookie != null && AuthService().sessionCookie!.isNotEmpty) {
                        await AuthService().syncCookiesToWebView("https://bymcloud.app/");
                        if (widget.initialUrl != null) {
                          controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(widget.initialUrl!),
                              headers: {
                                'Cookie': AuthService().sessionCookie!,
                              },
                            ),
                          );
                          return NavigationActionPolicy.CANCEL;
                        }
                      }
                      _triggerNativeLogout();
                    }
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                pullToRefreshController: pullToRefreshController,
                
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  try {
                    controller.addJavaScriptHandler(
                      handlerName: 'onMenuViewSelectionRequested',
                      callback: (args) {
                        _openMenuViewSelectionBottomSheet();
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onThemeSelectionRequested',
                      callback: (args) {
                        _openThemeSelectionBottomSheet();
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onExplicitLogoutClicked',
                      callback: (args) {
                        _triggerNativeLogout();
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onSessionExpiredCardDetected',
                      callback: (args) {
                        if (mounted && !_showSessionExpiredModal && !_isLoggingOut) {
                          setState(() {
                            _showSessionExpiredModal = true;
                          });
                        }
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onCompanySelectionRequested',
                      callback: (args) {
                        _openCompanySelectionBottomSheet();
                      },
                    );
                    controller.addJavaScriptHandler(
                      handlerName: 'onLoginInfoRequested',
                      callback: (args) {
                        if (args.isNotEmpty && args[0] is List) {
                          final List rawList = args[0] as List;
                          final List<Map<String, String>> logs = rawList.map((item) {
                            if (item is Map) {
                              return {
                                'date': (item['date'] ?? '').toString(),
                                'ip': (item['ip'] ?? '').toString(),
                                'device': (item['device'] ?? '').toString(),
                              };
                            }
                            return {'date': '', 'ip': '', 'device': ''};
                          }).toList();
                          _openLoginInfoBottomSheet(logs);
                        } else {
                          _openLoginInfoBottomSheet([]);
                        }
                      },
                    );
                  } catch (e) {
                    debugPrint("JS Handler Exception: $e");
                  }
                },
                
                onLoadStart: (controller, url) {
                  if (mounted && _hasTimeoutError) {
                    setState(() => _hasTimeoutError = false);
                  }
                  _startLoadingTimeoutTimer(); 
                  if (_isLoginOrLogoutUrl(url)) {
                    if (!_isLoggingOut) {
                      _triggerNativeLogout();
                    }
                    return;
                  }
                },
                
                onUpdateVisitedHistory: (controller, url, isReload) {
                  if (_isLoginOrLogoutUrl(url)) {
                    if (!_isLoggingOut) {
                      _triggerNativeLogout();
                    }
                  }
                  
                  if (url != null && !url.path.contains('/mobile-auth')) {
                    if (mounted && (_isFirstLoad || _isMobileAuthNavigating)) {
                      _cancelLoadingTimeoutTimer();
                      setState(() {
                        _isFirstLoad = false;
                        _isMobileAuthNavigating = false;
                      });
                    }
                  }
                },
                
                onProgressChanged: (controller, progress) async {
                  // Yükleme %100 olduğunda Flutter bekleme ekranını garantili şekilde kapat
                  if (progress == 100 && mounted) {
                    _cancelLoadingTimeoutTimer();
                    try {
                      final currentUrl = await controller.getUrl();
                      final isMobileAuth = currentUrl?.path.contains('/mobile-auth') ?? false;
                      
                      if (!isMobileAuth && (_isFirstLoad || _isReloading || _isMobileAuthNavigating)) {
                        setState(() {
                          _isFirstLoad = false;
                          _isReloading = false;
                          _isMobileAuthNavigating = false;
                          _hasTimeoutError = false;
                        });
                      }
                    } catch (_) {}
                  }
                },
                
                onLoadStop: (controller, url) async {
                  pullToRefreshController.endRefreshing();
                  _cancelLoadingTimeoutTimer();
                  await _applyThemeToWebView();

                  // Sadece web tarafının kendi siyah loader'ını gizler
                  try {
                    await controller.evaluateJavascript(source: """
                      if (!window._pageLoaderStyleAdded) {
                        window._pageLoaderStyleAdded = true;
                        var style = document.createElement('style');
                        style.innerHTML = '.app-page-loader { display: none !important; visibility: hidden !important; opacity: 0 !important; pointer-events: none !important; }';
                        (document.head || document.documentElement).appendChild(style);
                      }
                    """);
                  } catch (_) {}

                  try {
                    await controller.evaluateJavascript(source: """
                      if (!window._reconnectCardObserverAdded) {
                        window._reconnectCardObserverAdded = true;
                        function checkReconnectCard() {
                          var card = document.querySelector('.bym-reconnect-card');
                          if (card) {
                            card.style.display = 'none';
                            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                              window.flutter_inappwebview.callHandler('onSessionExpiredCardDetected');
                            }
                          }
                        }
                        var observer = new MutationObserver(checkReconnectCard);
                        observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
                        checkReconnectCard();
                      }
                    """);
                  } catch (_) {}

                  try {
                    await controller.evaluateJavascript(source: """
                      if (!window._logoutListenerAdded) {
                        window._logoutListenerAdded = true;
                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span') : null;
                          if (target) {
                            var text = (target.innerText || target.textContent || '').trim();
                            var isDangerClass = target.classList && target.classList.contains('danger');
                            if (text.indexOf('Oturumu Kapat') !== -1 || text.indexOf('Oturum Kapat') !== -1 || text.indexOf('Çıkış Yap') !== -1 || (isDangerClass && text.indexOf('Oturum') !== -1)) {
                              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                window.flutter_inappwebview.callHandler('onExplicitLogoutClicked');
                              }
                            }
                          }
                        }, true);
                      }
                    """);
                  } catch (_) {}

                  try {
                    await controller.evaluateJavascript(source: """
                      if (!window._companySelectionListenerAdded) {
                        window._companySelectionListenerAdded = true;
                        var _lastCompanyModalTrigger = 0;
                        
                        function hideElementSafely(el) {
                          if (!el) return;
                          el.setAttribute('data-native-handled', 'true');
                          try {
                            el.style.setProperty('display', 'none', 'important');
                            el.style.setProperty('visibility', 'hidden', 'important');
                            el.style.setProperty('opacity', '0', 'important');
                            el.style.setProperty('pointer-events', 'none', 'important');
                            el.style.setProperty('position', 'absolute', 'important');
                            el.style.setProperty('top', '-9999px', 'important');
                          } catch (_) {}
                        }
                        
                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li') : null;
                          if (target) {
                            var text = (target.innerText || target.textContent || '').trim().toLowerCase();
                            var className = (target.className || '').toString().toLowerCase();
                            
                            var isFirmaButton = text.indexOf('firma değiştir') !== -1 || 
                                                text.indexOf('firma degistir') !== -1 || 
                                                text.indexOf('şirket değiştir') !== -1 || 
                                                text.indexOf('sirket degistir') !== -1 ||
                                                text.indexOf('firma seç') !== -1 ||
                                                text.indexOf('firma sec') !== -1 ||
                                                (className.indexOf('user-popup-item') !== -1 && (text.indexOf('firma') !== -1 || text.indexOf('değiştir') !== -1 || text.indexOf('degistir') !== -1));
                                                
                            if (isFirmaButton) {
                              var now = Date.now();
                              if (now - _lastCompanyModalTrigger > 2000) {
                                _lastCompanyModalTrigger = now;
                                setTimeout(function() {
                                  document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, .company-tree, .company-tree-scroll').forEach(function(m) {
                                    hideElementSafely(m);
                                  });
                                }, 80);

                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onCompanySelectionRequested');
                                }
                              }
                            }
                          }
                        }, true);

                        function checkCompanyModalCard() {
                          var modals = document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, .company-tree, .company-tree-scroll');
                          for (var i = 0; i < modals.length; i++) {
                            var modal = modals[i];
                            if (modal.getAttribute('data-native-handled') === 'true') {
                              continue;
                            }

                            var text = (modal.innerText || modal.textContent || '');
                            var isCompanyModal = modal.classList.contains('company-tree') || 
                                                 modal.classList.contains('company-tree-scroll') || 
                                                 text.indexOf('Seçim Yapınız') !== -1 || 
                                                 text.indexOf('Secim Yapiniz') !== -1;

                            if (isCompanyModal) {
                              var rootModal = modal.closest('dxbl-modal-root, .dxbl-modal-root') || modal;
                              hideElementSafely(modal);
                              hideElementSafely(rootModal);

                              var now = Date.now();
                              if (now - _lastCompanyModalTrigger > 2000) {
                                _lastCompanyModalTrigger = now;
                                if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                  window.flutter_inappwebview.callHandler('onCompanySelectionRequested');
                                }
                              }
                            }
                          }
                        }

                        var companyObserver = new MutationObserver(checkCompanyModalCard);
                        companyObserver.observe(document.body || document.documentElement, { childList: true, subtree: true });
                        checkCompanyModalCard();
                      }

                      if (!window._loginInfoListenerAdded) {
                        window._loginInfoListenerAdded = true;
                        var _lastLoginInfoTrigger = 0;

                        function tryExtractAndOpenLoginInfo() {
                          var attempts = 0;
                          var maxAttempts = 15;
                          
                          var interval = setInterval(function() {
                            attempts++;
                            var modals = document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root, dxbl-modal-dialog, .dxbl-popup');
                            var found = false;
                            
                            for (var i = 0; i < modals.length; i++) {
                              var m = modals[i];
                              var mText = (m.innerText || m.textContent || '');
                              
                              var isLoginModal = mText.indexOf('Bilgisayar Adı') !== -1 || 
                                                 mText.indexOf('Bilgisayar Adi') !== -1 ||
                                                 mText.indexOf('IP') !== -1 ||
                                                 mText.indexOf('Tarih') !== -1 ||
                                                 m.querySelector('.dxbl-grid') !== null ||
                                                 m.querySelector('table') !== null;
                                                 
                              if (isLoginModal) {
                                var logs = [];
                                var rows = m.querySelectorAll('tbody tr');
                                for (var r = 0; r < rows.length; r++) {
                                  var cells = rows[r].querySelectorAll('td[role="gridcell"], td');
                                  if (cells.length >= 3) {
                                    var dateVal = (cells[0].innerText || cells[0].textContent || '').trim();
                                    var ipVal = (cells[1].innerText || cells[1].textContent || '').trim();
                                    var devVal = (cells[2].innerText || cells[2].textContent || '').trim();
                                    if (dateVal || ipVal || devVal) {
                                      logs.push({ date: dateVal, ip: ipVal, device: devVal });
                                    }
                                  }
                                }
                                
                                if (logs.length > 0 || attempts >= maxAttempts) {
                                  found = true;
                                  clearInterval(interval);
                                  
                                  var rootM = m.closest('dxbl-modal-root, .dxbl-modal-root') || m;
                                  rootM.setAttribute('data-native-handled', 'true');
                                  
                                  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                    window.flutter_inappwebview.callHandler('onLoginInfoRequested', logs);
                                  }
                                  break;
                                }
                              }
                            }
                            
                            if (!found && attempts >= maxAttempts) {
                              clearInterval(interval);
                              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                                window.flutter_inappwebview.callHandler('onLoginInfoRequested', []);
                              }
                            }
                          }, 100);
                        }

                        document.addEventListener('click', function(e) {
                          var target = e.target ? e.target.closest('button, a, div, span, li') : null;
                          if (target) {
                            var text = (target.innerText || target.textContent || '').trim().toLowerCase();
                            var className = (target.className || '').toString().toLowerCase();
                            
                            var isLoginInfoBtn = text.indexOf('giriş bilgisi') !== -1 || 
                                                 text.indexOf('giris bilgisi') !== -1 || 
                                                 text.indexOf('giriş bilgiler') !== -1 || 
                                                 text.indexOf('giris bilgiler') !== -1 ||
                                                 (className.indexOf('user-popup-item') !== -1 && (text.indexOf('giriş') !== -1 || text.indexOf('giris') !== -1));
                                                 
                            if (isLoginInfoBtn) {
                              var now = Date.now();
                              if (now - _lastLoginInfoTrigger > 1500) {
                                _lastLoginInfoTrigger = now;
                                tryExtractAndOpenLoginInfo();
                              }
                            }
                          }
                        }, true);

                        function checkLoginInfoModalCard() {
                          var modals = document.querySelectorAll('dxbl-modal-root, .dxbl-modal-root');
                          for (var i = 0; i < modals.length; i++) {
                            var modal = modals[i];
                            if (modal.getAttribute('data-native-handled') === 'true') {
                              continue;
                            }

                            var text = (modal.innerText || modal.textContent || '');
                            var isLoginInfoModal = text.indexOf('Bilgisayar Adı') !== -1 || 
                                                   text.indexOf('Bilgisayar Adi') !== -1 ||
                                                   (text.indexOf('Tarih') !== -1 && text.indexOf('IP') !== -1);

                            if (isLoginInfoModal) {
                              var now = Date.now();
                              if (now - _lastLoginInfoTrigger > 1500) {
                                _lastLoginInfoTrigger = now;
                                tryExtractAndOpenLoginInfo();
                              }
                            }
                          }
                        }

                        var loginInfoObserver = new MutationObserver(checkLoginInfoModalCard);
                        loginInfoObserver.observe(document.body || document.documentElement, { childList: true, subtree: true });
                        checkLoginInfoModalCard();
                      }
                    """);
                  } catch (_) {}

                  if (_isLoginOrLogoutUrl(url)) {
                    if (!_isLoggingOut) {
                      _triggerNativeLogout();
                    }
                    return;
                  }

                  if (url != null && url.path.contains('/mobile-auth')) {
                    if (mounted) {
                      setState(() {
                        _isMobileAuthNavigating = true;
                        _isFirstLoad = true;
                      });
                    }
                    Future.delayed(const Duration(milliseconds: 3500), () async {
                      if (!mounted) return;
                      try {
                        final currentUrl = await controller.getUrl();
                        if (currentUrl != null && currentUrl.path.contains('/mobile-auth')) {
                          await AuthService().syncCookiesToWebView("https://bymcloud.app/");
                          controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri("https://bymcloud.app/"),
                              headers: {
                                if (AuthService().sessionCookie != null && AuthService().sessionCookie!.isNotEmpty)
                                  'Cookie': AuthService().sessionCookie!,
                              },
                            ),
                          );
                        } else {
                          setState(() {
                            _isFirstLoad = false;
                            _isMobileAuthNavigating = false;
                          });
                        }
                      } catch (_) {}
                    });
                    return;
                  }

                  if (mounted) {
                    setState(() {
                      _isFirstLoad = false;
                      _isReloading = false;
                      _isMobileAuthNavigating = false;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  pullToRefreshController.endRefreshing();
                  final desc = error.description.toLowerCase();
                  final isCancelled = desc.contains('cancel') ||
                                      desc.contains('interrupted') ||
                                      error.type == WebResourceErrorType.CANCELLED;
                  if (request.isForMainFrame == true && !isCancelled) {
                    debugPrint("CRITICAL WEB ERROR: ${error.description} (type: ${error.type})");
                    if (mounted) {
                      final isOfflineError = error.type == WebResourceErrorType.HOST_LOOKUP ||
                                             error.type == WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                                             error.type == WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
                                             desc.contains('offline') ||
                                             desc.contains('not connected') ||
                                             desc.contains('internet');
                      setState(() {
                        _isFirstLoad = false;
                        _isReloading = false;
                        if (isOfflineError) {
                          _hasInternet = false;
                        } else {
                          _hasTimeoutError = true;
                        }
                      });
                    }
                  }
                },
              ),
              
              if (_isFirstLoad || _isReloading || _isLoggingOut)
                Container(
                  color: const Color(0xFFF8FAFC),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'assets/logo.png',
                            height: 90,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/app_icon.png',
                                height: 90,
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 36),
                        const CircularProgressIndicator(
                          color: Color(0xFF0075FF),
                          strokeWidth: 3.5,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Yükleniyor...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Nunito Sans',
                            color: Color(0xFF64748B),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_showSessionExpiredModal)
                Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
                                ),
                                child: const Icon(
                                  Icons.lock_clock_rounded,
                                  color: Color(0xFF0075FF),
                                  size: 36,
                                ),
                              ),
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Oturumunuzun Süresi Doldu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Nunito Sans',
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Güvenliğiniz için oturumunuz sonlandırıldı.\nDevam etmek için lütfen tekrar giriş yapınız.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Nunito Sans',
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _isReauthenticatingFromModal ? null : _handleContinueWorking,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0075FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isReauthenticatingFromModal
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.login_rounded, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Çalışmaya Devam Et',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Nunito Sans',
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _isReauthenticatingFromModal
                                  ? null
                                  : () {
                                      setState(() {
                                        _showSessionExpiredModal = false;
                                      });
                                      _triggerNativeLogout();
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                                backgroundColor: const Color(0xFFFEF2F2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.logout_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Çıkış Yap',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Nunito Sans',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (!_hasInternet || _hasTimeoutError)
                Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            !_hasInternet ? Icons.wifi_off_rounded : Icons.timer_off_rounded, 
                            size: 72, 
                            color: Colors.grey.shade400
                          ),
                          const SizedBox(height: 16),
                          Text(
                            !_hasInternet ? 'İnternet Bağlantısı Yok' : 'Bağlantı Zaman Aşımı',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            !_hasInternet 
                                ? 'Lütfen internet bağlantınızı kontrol edip tekrar deneyin.'
                                : 'Sunucu yanıt vermedi veya sayfa yüklemesi çok uzun sürdü. Lütfen oturumunuzu tazeleyin.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, height: 1.4, fontSize: 15),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (!_hasInternet) {
                                  setState(() {
                                    _hasInternet = true;
                                    _isFirstLoad = true;
                                  });
                                  _reloadPage();
                                } else {
                                  _triggerNativeLogout();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0075FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: Icon(!_hasInternet ? Icons.refresh_rounded : Icons.login_rounded, size: 22),
                              label: Text(!_hasInternet ? 'Tekrar Deneyin' : 'Yeniden Giriş Yap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}