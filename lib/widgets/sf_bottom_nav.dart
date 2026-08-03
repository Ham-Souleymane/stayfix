import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';
import 'unread_messages_nav_item.dart';

class SfBottomNav extends StatelessWidget {
  const SfBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTapIndex,
  });

  final int currentIndex;
  final ValueChanged<int> onTapIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final activeColor = isDark ? SfColors.gold : SfColors.goldDark;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.52);

    const items = [
      _NavItemData(icon: LucideIcons.home, label: 'Accueil'),
      _NavItemData(icon: LucideIcons.users, label: 'Agents'),
      _NavItemData(icon: LucideIcons.clipboardList, label: 'Offres'),
      _NavItemData(icon: LucideIcons.messageCircle, label: 'Messages'),
      _NavItemData(icon: LucideIcons.user, label: 'Profil'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? 6 : 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xF0111111)
                : const Color(0xF0FFFFFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : SfColors.lightBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final active = currentIndex == index;

              return Expanded(
                child: InkWell(
                  onTap: () => onTapIndex(index),
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item.label == 'Messages')
                        UnreadMessagesNavItem(
                          isActive: active,
                          onTap: () => onTapIndex(index),
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          dotColor: const Color(0xFFFF3B30),
                          activeSize: 20,
                          inactiveSize: 20,
                          padding: EdgeInsets.zero,
                          fontSize: 11,
                          activeFontWeight: FontWeight.w700,
                          inactiveFontWeight: FontWeight.w500,
                        )
                      else ...[
                        Icon(
                          item.icon,
                          size: 20,
                          color: active ? activeColor : inactiveColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: GoogleFonts.inter(
                            color: active ? activeColor : inactiveColor,
                            fontSize: 11,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}
