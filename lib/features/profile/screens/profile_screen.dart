import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../auth/services/supabase_auth_service.dart';
import '../../../models/profile.dart';

final profileProvider = FutureProvider<Profile?>((ref) {
  final user = ref.watch(supabaseClientProvider).auth.currentUser;
  if (user == null) return Future.value(null);
  return ref
      .watch(databaseServiceProvider)
      .getOrCreateProfile(user.id, user.email ?? '');
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final r = ResponsiveHelper(context);
    final neon = theme.colorScheme.primary;

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: neon),
              const SizedBox(height: 16),
              Text('Error al cargar perfil'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(profileProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (profile) => SingleChildScrollView(
          padding: r.pagePadding,
          child: Column(
            children: [
              SizedBox(height: r.isDesktop ? 40 : 20),
              CircleAvatar(
                radius: r.isDesktop ? 56 : 46,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.2,
                ),
                child: Text(
                  (profile?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: r.isDesktop ? 44 : 36,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(height: r.cardSpacing),
              Text(
                profile?.displayName ?? 'Usuario',
                style: GoogleFonts.outfit(
                  fontSize: r.titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: GoogleFonts.inter(
                  fontSize: r.subtitleFontSize,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: r.cardSpacing + 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ProfileStat(
                    icon: Icons.star,
                    value: '${profile?.totalXp ?? 0}',
                    label: 'XP',
                    responsive: r,
                  ),
                  SizedBox(width: r.isDesktop ? 48 : 32),
                  _ProfileStat(
                    icon: Icons.local_fire_department,
                    value: '${profile?.streak ?? 0}',
                    label: 'Dias',
                    responsive: r,
                  ),
                ],
              ),
              SizedBox(height: r.cardSpacing + 20),
              _buildMenuSection(context, theme, r),
              SizedBox(height: r.cardSpacing + 8),
              SizedBox(
                width: double.infinity,
                height: r.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(supabaseAuthProvider).signOut();
                    if (context.mounted) context.go('/');
                  },
                  icon: Icon(Icons.logout, color: neon),
                  label: Text('Cerrar sesion', style: TextStyle(color: neon)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: neon),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.borderRadius),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    ThemeData theme,
    ResponsiveHelper r,
  ) {
    return Column(
      children: [
        _MenuItem(
          icon: Icons.settings_outlined,
          title: 'Configuracion',
          onTap: () {},
          responsive: r,
        ),
        const Divider(height: 1),
        _MenuItem(
          icon: Icons.help_outline,
          title: 'Ayuda y soporte',
          onTap: () {},
          responsive: r,
        ),
        const Divider(height: 1),
        _MenuItem(
          icon: Icons.info_outline,
          title: 'Acerca de',
          onTap: () {},
          responsive: r,
        ),
      ],
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ResponsiveHelper responsive;
  const _ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: responsive.iconSizeMedium,
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: responsive.isDesktop ? 26 : 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: responsive.bodyFontSize - 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final ResponsiveHelper responsive;
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        size: responsive.iconSizeMedium,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: responsive.bodyFontSize,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.borderRadius - 2),
      ),
    );
  }
}
