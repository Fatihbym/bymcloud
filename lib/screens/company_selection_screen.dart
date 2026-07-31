import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/deep_link_service.dart';
import '../webview_screen.dart';
import 'login_screen.dart';
import '../services/localization_service.dart';

class CompanySelectionScreen extends StatefulWidget {
  final DeepLinkService deepLinkService;
  final List<dynamic> companies;
  final String email;
  final String password;
  final bool isBottomSheet;

  const CompanySelectionScreen({
    super.key,
    required this.deepLinkService,
    required this.companies,
    required this.email,
    required this.password,
    this.isBottomSheet = false,
  });

  @override
  State<CompanySelectionScreen> createState() => _CompanySelectionScreenState();
}

class _CompanySelectionScreenState extends State<CompanySelectionScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final Map<int, List<dynamic>> _fetchedFirms = {};
  final Map<int, bool> _loadingFirms = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  int? _savedDbId;
  int? _savedFirmId;

  List<Map<String, dynamic>> _filteredCompanies = [];

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _filteredCompanies = List<Map<String, dynamic>>.from(widget.companies);
    _loadSavedPreferences();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _savedDbId = prefs.getInt('saved_dbid');
        _savedFirmId = prefs.getInt('saved_firmaid');

        if (_savedDbId != null) {
          _sortCompanies(_filteredCompanies);
          // Find the saved db and load its firms automatically
          try {
            final savedDb = _filteredCompanies.firstWhere((db) => db['a_id'] == _savedDbId);
            if (!_fetchedFirms.containsKey(_savedDbId) && _loadingFirms[_savedDbId] != true) {
              _loadFirmsForDb(savedDb);
            }
          } catch (e) {
            // Ignore if not found
          }
        }
      });
    }
  }

  void _sortCompanies(List<Map<String, dynamic>> list) {
    if (_savedDbId != null) {
      list.sort((a, b) {
        if (a['a_id'] == _savedDbId) return -1;
        if (b['a_id'] == _savedDbId) return 1;
        return 0;
      });
    }
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(deepLinkService: widget.deepLinkService),
        ),
      );
    }
  }

  /// Fetch firms on-demand for a given database/company ID
  void _loadFirmsForDb(Map<String, dynamic> db) async {
    final int dbid = db['a_id'] ?? 0;
    if (_fetchedFirms.containsKey(dbid) || _loadingFirms[dbid] == true) return;

    if (mounted) {
      setState(() {
        _loadingFirms[dbid] = true;
      });
    }

    try {
      final firms = await AuthService().getFirmsAPI(db);
      if (mounted) {
        setState(() {
          _fetchedFirms[dbid] = firms;
          _loadingFirms[dbid] = false;
          // Re-trigger filter if actively searching
          if (_searchQuery.isNotEmpty) {
            _performSearch(_searchQuery);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingFirms[dbid] = false;
        });
      }
    }
  }

  void _selectFirm(int dbid, int firmaid) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool('remember_me') ?? true;

    final redirectUrl = await AuthService().selectFirmAPI(
      widget.email,
      widget.password,
      dbid,
      firmaid,
      rememberMe: rememberMe,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (redirectUrl != null && redirectUrl.isNotEmpty && !redirectUrl.contains('/auth/login')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('saved_dbid', dbid);
      await prefs.setInt('saved_firmaid', firmaid);

      await AuthService().syncCookiesToWebView("https://bymcloud.app/");

      if (mounted) {
        final fullUrl = redirectUrl.startsWith('http')
            ? redirectUrl
            : 'https://bymcloud.app$redirectUrl';

        if (widget.isBottomSheet) {
          Navigator.of(context).pop(fullUrl);
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => WebViewScreen(
                deepLinkService: widget.deepLinkService,
                initialUrl: fullUrl,
              ),
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService().translate('firm_selection_fail'),
            style: const TextStyle(fontFamily: 'Nunito Sans', fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.redAccent.shade700,
        ),
      );
    }
  }

  /// Debounced search handler for high performance on large lists (100+ items)
  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query) {
    final cleanQuery = query.trim().toLowerCase();
    setState(() {
      _searchQuery = cleanQuery;
      if (cleanQuery.isEmpty) {
        _filteredCompanies = List<Map<String, dynamic>>.from(widget.companies);
        _sortCompanies(_filteredCompanies);
      } else {
        final List<Map<String, dynamic>> results = [];
        for (var company in widget.companies) {
          final Map<String, dynamic> db = Map<String, dynamic>.from(company);
          final String dbName = (db['a_adi'] ?? '').toString().toLowerCase();
          final int dbid = db['a_id'] ?? 0;

          final List<dynamic> allFirms = (db['firma'] != null && (db['firma'] as List).isNotEmpty)
              ? db['firma']
              : (_fetchedFirms[dbid] ?? []);

          final matchingFirms = allFirms.where((firm) {
            final String firmName = (firm['a_adi'] ?? '').toString().toLowerCase();
            return firmName.contains(cleanQuery);
          }).toList();

          bool companyMatches = dbName.contains(cleanQuery);

          if (companyMatches || matchingFirms.isNotEmpty) {
            // Eğer şirket adı aramayla eşleştiyse, o şirketin tüm firmalarını göster.
            // Sadece firma adı eşleştiyse, sadece eşleşen firmaları göster.
            db['_matchingFirms'] = companyMatches ? allFirms : matchingFirms;
            results.add(db);
            
            // Arama sonucunda şirket listelenecek ve otomatik açılacak. 
            // Eğer firmalar henüz yüklenmediyse, otomatik olarak yüklemeyi başlat.
            if (allFirms.isEmpty && !_fetchedFirms.containsKey(dbid) && _loadingFirms[dbid] != true) {
              _loadFirmsForDb(db);
            }
          }
        }
        _sortCompanies(results);
        _filteredCompanies = results;
      }
    });
  }

  /// Skeleton Loader Widget for Firm List Loading State
  Widget _buildSkeletonLoader() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: List.generate(
              3,
              (index) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200.withValues(alpha: _shimmerAnimation.value),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300.withValues(alpha: _shimmerAnimation.value),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300.withValues(alpha: _shimmerAnimation.value),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.isNotEmpty;

    final bodyWidget = Stack(
      children: [
        Column(
          children: [
              // Gelismis Arama Paneli (Enhanced Search Box)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSearching ? const Color(0xFF0075FF) : const Color(0xFFE2E8F0),
                      width: isSearching ? 1.8 : 1.2,
                    ),
                    boxShadow: [
                      if (isSearching)
                        BoxShadow(
                          color: const Color(0xFF0075FF).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(
                      fontFamily: 'Nunito Sans',
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: LocalizationService().translate('search_company'),
                      hintStyle: const TextStyle(
                        fontFamily: 'Nunito Sans',
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0075FF), size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 20),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),

              // Arama Sonuc Bilgi Şeridi
              if (isSearching)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFEDF2F7),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LocalizationService().translate('search_results'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito Sans',
                          color: Color(0xFF334155),
                        ),
                      ),
                      Text(
                        '${_filteredCompanies.length} ${LocalizationService().translate('companies_matched')}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Nunito Sans',
                          color: Color(0xFF0075FF),
                        ),
                      ),
                    ],
                  ),
                ),

              // Performanslı Şirket ve Firma Listesi
              Expanded(
                child: _filteredCompanies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 14),
                            Text(
                              LocalizationService().translate('no_company_found'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Nunito Sans',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final db = _filteredCompanies[index];
                          final String dbName = db['a_adi'] ?? 'Bilinmeyen Şirket';
                          final int dbid = db['a_id'] ?? 0;

                          List<dynamic> firms = db['_matchingFirms'] ??
                              (db['firma'] != null && (db['firma'] as List).isNotEmpty
                                  ? db['firma']
                                  : (_fetchedFirms[dbid] ?? []));

                          final isFetching = _loadingFirms[dbid] == true;
                          final isLastSelectedCompany = (dbid == _savedDbId);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: isLastSelectedCompany ? const Color(0xFFFEF9C3).withValues(alpha: 0.3) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: ExpansionTile(
                                key: ValueKey('db_${dbid}_${isSearching}_$isLastSelectedCompany'),
                                initiallyExpanded: isSearching || isLastSelectedCompany,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                onExpansionChanged: (expanded) {
                                  if (expanded && firms.isEmpty) {
                                    _loadFirmsForDb(db);
                                  }
                                },
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0075FF).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.business_rounded, color: Color(0xFF0075FF), size: 24),
                                ),
                                title: Text(
                                  dbName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Nunito Sans',
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Text(
                                  firms.isNotEmpty
                                      ? '${firms.length} ${LocalizationService().translate('firms_available')}'
                                      : (isFetching ? LocalizationService().translate('company_loading') : LocalizationService().translate('click_to_see_firms')),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    fontFamily: 'Nunito Sans',
                                  ),
                                ),
                                children: [
                                  if (isFetching)
                                    _buildSkeletonLoader()
                                  else if (firms.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            LocalizationService().translate('no_sub_firm'),
                                            style: TextStyle(color: Colors.grey.shade600, fontFamily: 'Nunito Sans'),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => _selectFirm(dbid, 1),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0075FF),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              ),
                                              child: Text(
                                                LocalizationService().translate('connect_to_company'),
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Nunito Sans'),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ...firms.map((firm) {
                                      final String firmName = firm['a_adi'] ?? 'İsimsiz Firma';
                                      final int firmaid = firm['a_id'] ?? 1;
                                      final bool isLastSelectedFirm = (dbid == _savedDbId && firmaid == _savedFirmId);

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                        child: Material(
                                          color: isLastSelectedFirm ? const Color(0xFFFEF9C3) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => _selectFirm(dbid, firmaid),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.storefront_rounded, color: Color(0xFF0075FF), size: 20),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Text(
                                                      firmName,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        fontFamily: 'Nunito Sans',
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF0075FF), size: 14),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // Yükleme Göstergesi (Kart ve Metin Olmadan Sadece Progress Bar)
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0075FF),
                  strokeWidth: 3.5,
                ),
              ),
            ),
        ],
      );

    if (widget.isBottomSheet) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LocalizationService().translate('select_company'),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Nunito Sans',
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: bodyWidget),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: _goToLogin,
        ),
        title: Text(
          LocalizationService().translate('select_company'),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontFamily: 'Nunito Sans',
            fontSize: 18,
          ),
        ),
      ),
      body: bodyWidget,
    );
  }
}
