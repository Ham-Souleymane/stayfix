import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';
import '../models/hotel_models.dart';
import '../providers/hotel_provider.dart';
import 'add_staff_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'room_list_screen.dart';
import 'selection_screen.dart';
import 'supervisor_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initData();
    }
  }

  void _initData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = Provider.of<HotelProvider>(context, listen: false);
        if (provider.currentUser != null && provider.selectedHotel != null) {
          provider.listenToHotelData();
          provider.fetchHotelStaff();
          if (provider.currentUser!.role == UserRoles.director) {
            provider.generateDefaultRooms();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<HotelProvider>(
      builder: (context, provider, child) {
        final user = provider.currentUser;

        if (_isLoggingOut) {
          return Scaffold(backgroundColor: theme.scaffoldBackgroundColor);
        }

        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            }
          });
          return Scaffold(backgroundColor: theme.scaffoldBackgroundColor);
        }

        if (user.role == UserRoles.director && provider.selectedHotel == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SelectionScreen()),
              );
            }
          });
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
          );
        }

        if (user.role.contains('Superviseur')) {
          return const SupervisorDashboard();
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _buildAppBar(context, user, provider),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              children: [
                _buildRoleBasedView(user, provider),
              ],
            ),
          ),
          floatingActionButton: _buildFab(context, user),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, HotelUser user, HotelProvider provider) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.fullName.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.edit2,
                    size: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "${user.role} • ${provider.selectedHotel?.name ?? '...'}",
                style: GoogleFonts.inter(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Mode toggle button (White Mode vs Dark Mode)
        IconButton(
          tooltip: isDark ? 'Passer en mode clair' : 'Passer en mode sombre',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
              key: ValueKey(isDark),
              color: isDark ? SfColors.gold : theme.colorScheme.primary,
            ),
          ),
          onPressed: () => themeProvider.toggleTheme(),
        ),
        IconButton(
          tooltip: 'Déconnexion',
          icon: Icon(LucideIcons.logOut, color: theme.colorScheme.onSurface),
          onPressed: () {
            _isLoggingOut = true;
            final hotelProvider =
                Provider.of<HotelProvider>(context, listen: false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
              (route) => false,
            );
            Future.delayed(
              const Duration(milliseconds: 200),
              () => hotelProvider.logout(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoleBasedView(HotelUser user, HotelProvider provider) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (user.role == UserRoles.director) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    "Total Staff",
                    "${provider.hotelStaff.length}",
                    LucideIcons.users,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _roomStatsCard(context, provider)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.userPlus, size: 16),
                    label: Text(
                      "Ajouter Directeur",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF18181B)
                          : SfColors.lightBgField,
                      foregroundColor: theme.colorScheme.onSurface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : SfColors.lightBorder,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddStaffScreen(
                          currentUserRole: user.role,
                          isAddingSupervisorMode: false,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.eye, size: 16),
                    label: Text(
                      "Ajouter Superviseur",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SfColors.gold.withValues(alpha: 0.12),
                      foregroundColor: isDark ? SfColors.gold : SfColors.goldDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? SfColors.gold : SfColors.goldDark,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddStaffScreen(
                          currentUserRole: user.role,
                          isAddingSupervisorMode: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              "DIRECTEURS DE DÉPARTEMENT",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: provider.hotelStaff
                      .where((u) => u.role != UserRoles.director)
                      .isEmpty
                  ? Center(
                      child: Text(
                        "Aucun personnel ajouté.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.hotelStaff.length,
                      itemBuilder: (ctx, i) {
                        final staff = provider.hotelStaff[i];
                        if (staff.role == UserRoles.director) {
                          return const SizedBox.shrink();
                        }
                        return _buildStaffTile(staff);
                      },
                    ),
            ),
          ],
        ),
      );
    }

    if (user.role == UserRoles.housekeeping ||
        user.role == UserRoles.houseman ||
        user.role == UserRoles.staff) {
      final tasks = provider.rooms
          .where((r) => r.status.contains('Service') || r.status == 'Checkout')
          .toList();
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statCard("À Nettoyer", "${tasks.length}", LucideIcons.sprayCan),
            const SizedBox(height: 24),
            Text(
              "MES TÂCHES",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune chambre à nettoyer.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (ctx, i) {
                        final r = tasks[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: r.status == 'Checkout'
                                    ? SfColors.warning
                                    : SfColors.info,
                                width: 4,
                              ),
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              LucideIcons.bed,
                              color: theme.colorScheme.onSurface,
                            ),
                            title: Text(
                              "Chambre ${r.number}",
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              r.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 10,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.checkCircle,
                                color: SfColors.success,
                              ),
                              onPressed: () =>
                                  provider.updateRoomStatus(r.id, 'Libre'),
                            ),
                          ),
                        );
                      },
                    ),
            )
          ],
        ),
      );
    }

    bool canViewRooms = [
      UserRoles.housekeepingManager,
      UserRoles.maintenanceManager,
      UserRoles.receptionManager
    ].contains(user.role);
    if (canViewRooms) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _roomStatsCard(context, provider),
            const SizedBox(height: 24),
            Text(
              "ÉTAT DES CHAMBRES",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: provider.rooms.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune chambre.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: provider.rooms.length,
                      itemBuilder: (ctx, i) {
                        final r = provider.rooms[i];
                        if (r.status == 'Libre') return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              LucideIcons.bed,
                              color: r.status == 'Vendu'
                                  ? SfColors.danger
                                  : SfColors.warning,
                            ),
                            title: Text(
                              "Chambre ${r.number}",
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              r.status.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                            trailing: Text(
                              r.type,
                              style: GoogleFonts.inter(
                                color: theme.colorScheme.onSurface,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              height: 30,
            ),
            Text(
              "MON ÉQUIPE",
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 1,
              child: provider.hotelStaff.isEmpty
                  ? Center(
                      child: Text(
                        "Aucune équipe.",
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView(
                      children: provider.hotelStaff
                          .where((u) =>
                              u.role != UserRoles.director &&
                              u.role != user.role)
                          .map((staff) => _buildStaffTile(staff))
                          .toList(),
                    ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: Center(
        child: Text(
          "Bienvenue",
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStaffTile(HotelUser staff) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
          width: 0.8,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: SfColors.gold.withValues(alpha: 0.15),
          child: Icon(
            _getRoleIcon(staff.role),
            color: isDark ? SfColors.gold : SfColors.goldDark,
            size: 18,
          ),
        ),
        title: Text(
          staff.fullName,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          staff.role,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _roomStatsCard(BuildContext context, HotelProvider provider) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                LucideIcons.bed,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoomListScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SfColors.gold.withValues(alpha: 0.12),
                    border: Border.all(
                      color: isDark ? SfColors.gold : SfColors.goldDark,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "VOIR",
                    style: GoogleFonts.inter(
                      color: isDark ? SfColors.gold : SfColors.goldDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "${provider.rooms.length}",
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Chambres Totales",
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String role) {
    if (role.contains('Réception')) {
      return LucideIcons.conciergeBell;
    }
    if (role.contains('Gouvernante') || role.contains('Propreté')) {
      return LucideIcons.sparkles;
    }
    if (role.contains('Maintenance')) {
      return LucideIcons.hammer;
    }
    if (role.contains('Superviseur')) {
      return LucideIcons.eye;
    }
    return LucideIcons.user;
  }

  Widget? _buildFab(BuildContext context, HotelUser user) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    if (user.role == UserRoles.director ||
        [UserRoles.housekeeping, UserRoles.houseman, UserRoles.staff]
            .contains(user.role)) {
      return null;
    }
    return FloatingActionButton(
      backgroundColor: isDark ? SfColors.gold : SfColors.goldDark,
      child: const Icon(LucideIcons.userPlus, color: Colors.white),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddStaffScreen(currentUserRole: user.role),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? SfColors.darkBorder : SfColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 24,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
