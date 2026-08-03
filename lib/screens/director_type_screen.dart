import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screen.dart';
import 'condo_dashboard_screen.dart';
import 'immeuble_dashboard.dart';
import 'manager_profile_config.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DirectorTypeScreen extends StatefulWidget {
  const DirectorTypeScreen({super.key});

  @override
  State<DirectorTypeScreen> createState() => _DirectorTypeScreenState();
}

class _DirectorTypeScreenState extends State<DirectorTypeScreen> {
  String? _selectedType;
  bool _isLoading = false;

  ManagerProfileOption? get _selectedOption =>
      managerProfileOptionByValue(_selectedType);

  @override
  void initState() {
    super.initState();
    _selectedType = kManagerProfileOptions.first.value;
  }

  Future<void> _saveSelection() async {
    final option = _selectedOption;
    if (option == null || _isLoading) {
      showAuthError(
        context,
        'S\u00e9lectionnez votre profil pour continuer.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showAuthError(
          context,
          'Session introuvable. Veuillez vous reconnecter.',
        );
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'directorType': option.label,
        'propertyProfileType': option.value,
        'propertyProfileLabel': option.label,
        'profileCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      final Widget nextScreen = option.value == 'building_manager' ||
              option.value == 'rental_building'
          ? ImmeubleDashboardScreen(propertyType: option.value)
          : CondoDashboardScreen(
              propertyType: option.value,
            );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } catch (_) {
      if (mounted) {
        showAuthError(context, "Erreur lors de l'enregistrement du profil.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOptionTap(ManagerProfileOption option) async {
    if (_isLoading) return;
    setState(() => _selectedType = option.value);
    await _saveSelection();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isCompact = size.height <= 820 || size.width <= 370;
    final heroHeight =
        (size.height * (isCompact ? 0.38 : 0.42)).clamp(280.0, 360.0);
    final panelTop = heroHeight - 26;
    final panelHorizontalPadding = isCompact ? 18.0 : 22.0;
    final innerGap = isCompact ? 12.0 : 16.0;
    final titleSize = isCompact ? 29.0 : 34.0;

    return Scaffold(
      backgroundColor: kAuthBg,
      body: SizedBox(
        height: size.height,
        child: Stack(
          children: [
            _RoleHero(height: heroHeight),
            Positioned(
              top: panelTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: kAuthPanel,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(42),
                    topRight: Radius.circular(42),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 30,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      panelHorizontalPadding,
                      isCompact ? 18 : 22,
                      panelHorizontalPadding,
                      mediaQuery.padding.bottom + (isCompact ? 14 : 20),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenue',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kAuthGoldDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quel type de bien\ng\u00e9rez-vous ?',
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              color: kAuthText,
                              height: 0.92,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'S\u00e9lectionnez votre profil pour personnaliser votre espace de gestion.',
                            style: GoogleFonts.manrope(
                              fontSize: isCompact ? 14 : 15.5,
                              fontWeight: FontWeight.w500,
                              color: kAuthMuted,
                              height: 1.34,
                            ),
                          ),
                          SizedBox(height: isCompact ? 16 : 22),
                          Column(
                            children: [
                              for (int i = 0; i < kManagerProfileOptions.length; i++) ...[
                                if (i > 0) SizedBox(height: innerGap),
                                _StackedRoleCard(
                                  option: kManagerProfileOptions[i],
                                  isSelected:
                                      _selectedType == kManagerProfileOptions[i].value,
                                  onTap: () => _handleOptionTap(
                                    kManagerProfileOptions[i],
                                  ),
                                  compact: isCompact,
                                  isLoading: _isLoading,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/selectionheroimg.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(color: kAuthBg),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x14000000),
                  Color(0x11000000),
                  Color(0xA3050505),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _StackedRoleCard extends StatelessWidget {
  const _StackedRoleCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.compact,
    required this.isLoading,
  });

  final ManagerProfileOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return _RoleCardShell(
      isSelected: isSelected,
      onTap: onTap,
      enabled: !isLoading,
      borderRadius: 20,
      minHeight: compact ? 84 : 96,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: compact ? 14 : 18,
        ),
        child: Row(
          children: [
            _RoleIcon(
              value: option.value,
              size: compact ? 38 : 44,
              featured: false,
            ),
            SizedBox(width: compact ? 14 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    option.label,
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: compact ? 15.0 : 16.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.subtitle,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: compact ? 12.0 : 13.0,
                      fontWeight: FontWeight.w500,
                      height: 1.22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ChevronBubble(
              selected: isSelected,
              size: compact ? 32 : 36,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCardShell extends StatelessWidget {
  const _RoleCardShell({
    required this.child,
    required this.isSelected,
    required this.onTap,
    required this.borderRadius,
    required this.enabled,
    this.minHeight = 156,
  });

  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;
  final double borderRadius;
  final bool enabled;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B0B0B),
                Color(0xFF121212),
              ],
            ),
            border: Border.all(
              color: isSelected ? kAuthGold : const Color(0xFFC99645),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
              if (isSelected)
                BoxShadow(
                  color: kAuthGold.withValues(alpha: 0.22),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ChevronBubble extends StatelessWidget {
  const _ChevronBubble({
    required this.selected,
    required this.size,
  });

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? kAuthGold : kAuthGold.withValues(alpha: 0.72),
          width: 1.1,
        ),
        color:
            selected ? kAuthGold.withValues(alpha: 0.12) : Colors.transparent,
      ),
      child: Icon(
        LucideIcons.chevronRight,
        color: kAuthGold,
        size: size * 0.48,
      ),
    );
  }
}

class _RoleIcon extends StatelessWidget {
  const _RoleIcon({
    required this.value,
    required this.size,
    required this.featured,
  });

  final String value;
  final double size;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    switch (value) {
      case 'hotel_manager':
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              LucideIcons.hotel,
              color: kAuthGold,
              size: size,
            ),
            Positioned(
              top: -size * 0.18,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  featured ? 5 : 3,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      LucideIcons.star,
                      color: kAuthGold,
                      size: featured ? size * 0.13 : size * 0.12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'building_manager':
        return Icon(
          LucideIcons.building2,
          color: kAuthGold,
          size: size,
        );
      case 'rental_building':
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              LucideIcons.keyRound,
              color: kAuthGold,
              size: size * 0.88,
            ),
            Positioned(
              bottom: size * 0.02,
              right: size * 0.02,
              child: Icon(
                LucideIcons.home,
                color: kAuthGold,
                size: size * 0.34,
              ),
            ),
          ],
        );
      case 'villa_owner':
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              LucideIcons.home,
              color: kAuthGold,
              size: size * 0.92,
            ),
            Positioned(
              top: -size * 0.06,
              right: -size * 0.02,
              child: Icon(
                LucideIcons.trees,
                color: kAuthGold,
                size: size * 0.26,
              ),
            ),
          ],
        );
      default:
        return Icon(
          LucideIcons.building,
          color: kAuthGold,
          size: size * 0.94,
        );
    }
  }
}

class _BlackGoldButton extends StatelessWidget {
  const _BlackGoldButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 52.0 : 56.0;
    final arrowSize = compact ? 38.0 : 42.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: const Color(0xFF0B0B0B),
            border: Border.all(color: kAuthGold, width: 1.1),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: arrowSize,
                  height: arrowSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF0CB87),
                        Color(0xFFD6A85A),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.arrowRight,
                    color: Colors.black,
                    size: compact ? 19 : 21,
                  ),
                ),
              ),
              isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 32 : 36,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: compact ? 15.5 : 16.5,
                          fontWeight: FontWeight.w600,
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
