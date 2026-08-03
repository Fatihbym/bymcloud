import 'package:flutter/material.dart';

class MenuViewSelectionBottomSheet extends StatefulWidget {
  final String currentViewMode; // 'authorized', 'package', 'all'

  const MenuViewSelectionBottomSheet({
    super.key,
    required this.currentViewMode,
  });

  @override
  State<MenuViewSelectionBottomSheet> createState() => _MenuViewSelectionBottomSheetState();
}

class _MenuViewSelectionBottomSheetState extends State<MenuViewSelectionBottomSheet> {
  late String _selectedViewMode;

  @override
  void initState() {
    super.initState();
    _selectedViewMode = widget.currentViewMode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0075FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: Color(0xFF0075FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menü Görünümü',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Nunito Sans',
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Ekran ve modül erişim kapsamını seçin',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontFamily: 'Nunito Sans',
                            fontSize: 13,
                          ),
                        ),
                      ],
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

            // Options List
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  _buildOption(
                    context,
                    key: 'authorized',
                    title: 'Sadece Yetkili Olduğum Ekranlar',
                    subtitle: 'Rolünüze tanımlı ekranlar',
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    context,
                    key: 'package',
                    title: 'Paket Tanımlı Tüm Ekranlar',
                    subtitle: 'Paketinizdeki tüm ekranlar',
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    context,
                    key: 'all',
                    title: 'Tüm Modüller',
                    subtitle: 'Sistemdeki tüm modüller',
                    icon: Icons.layers_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String key,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedViewMode == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedViewMode = key;
          });
          Navigator.of(context).pop(key);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF0075FF) : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0075FF).withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0075FF)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? const Color(0xFF0075FF) : const Color(0xFF0F172A),
                        fontFamily: 'Nunito Sans',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontFamily: 'Nunito Sans',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFF0075FF) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0075FF) : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
