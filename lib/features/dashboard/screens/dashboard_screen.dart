import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/category.dart';
import '../../../models/profile.dart';

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    if (user == null) throw Exception('No autenticado');
    final db = ref.watch(databaseServiceProvider);
    final profile = await db.getOrCreateProfile(user.id, user.email ?? '');
    final categories = await db.getCategories();
    final completedCount = await db.getCompletedLessonsCount(user.id);
    final totalXp = await db.getTotalXp(user.id);
    return DashboardData(
      profile: profile,
      categories: categories,
      completedLessons: completedCount,
      totalXp: totalXp,
    );
  }

  Future<void> loadDashboard() async {
    ref.invalidateSelf();
    await future;
  }
}

class DashboardData {
  final Profile profile;
  final List<Category> categories;
  final int completedLessons;
  final int totalXp;
  DashboardData({
    required this.profile,
    required this.categories,
    required this.completedLessons,
    required this.totalXp,
  });
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardData>(
      DashboardNotifier.new,
    );

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final r = ResponsiveHelper(context);

    return Scaffold(
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error al cargar datos',
                style: GoogleFonts.inter(fontSize: r.bodyFontSize),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.read(dashboardProvider.notifier).loadDashboard(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (data) =>
            _DashboardContent(data: data, userId: data.profile.id, r: r),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final String userId;
  final ResponsiveHelper r;

  const _DashboardContent({
    required this.data,
    required this.userId,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: r.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme),
            SizedBox(height: r.cardSpacing + 4),
            _buildStatsRow(context, theme),
            SizedBox(height: r.cardSpacing + 4),
            _buildWeeklyProgress(context, theme),
            SizedBox(height: r.cardSpacing + 4),
            _buildCategoriesSection(context, theme),
            SizedBox(height: r.cardSpacing),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${data.profile.displayName}!',
              style: GoogleFonts.outfit(
                fontSize: r.titleFontSize,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: r.iconSizeMedium,
                ),
                const SizedBox(width: 4),
                Text(
                  'Racha de ${data.profile.streak} dias',
                  style: GoogleFonts.inter(
                    fontSize: r.subtitleFontSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: CircleAvatar(
            radius: r.isDesktop ? 34 : 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            child: Text(
              data.profile.displayName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: r.isDesktop ? 28 : 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, ThemeData theme) {
    final items = [
      _StatData(Icons.star, '${data.totalXp}', 'XP', theme.colorScheme.primary),
      _StatData(
        Icons.check_circle_outline,
        '${data.completedLessons}',
        'Lecciones',
        theme.colorScheme.secondary,
      ),
      _StatData(
        Icons.local_fire_department,
        '${data.profile.streak}',
        'Dias',
        Colors.orange,
      ),
    ];

    return Wrap(
      spacing: r.cardSpacing - 4,
      runSpacing: r.cardSpacing - 4,
      children: items
          .map(
            (s) => SizedBox(
              width: _statCardWidth(context),
              child: _StatCard(data: s, r: r),
            ),
          )
          .toList(),
    );
  }

  double _statCardWidth(BuildContext context) {
    final cols = r.statColumns;
    final w = MediaQuery.of(context).size.width - r.padHorizontal * 2;
    final spacing = (cols - 1) * (r.cardSpacing - 4);
    return (w - spacing) / cols;
  }

  Widget _buildWeeklyProgress(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.cardSpacing + 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu progreso semanal',
            style: GoogleFonts.outfit(
              fontSize: r.subtitleFontSize + 2,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: r.cardSpacing),
          SizedBox(
            height: r.isDesktop ? 220 : 160,
            child: _WeeklyChart(r: r),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categorias',
          style: GoogleFonts.outfit(
            fontSize: r.subtitleFontSize + 2,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),
        if (data.categories.isEmpty)
          Container(
            padding: EdgeInsets.all(r.isDesktop ? 48 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(r.borderRadius),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: r.iconSizeLarge,
                    color: Colors.grey,
                  ),
                  SizedBox(height: r.cardSpacing),
                  Text(
                    'No hay categorias aun',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: r.cardSpacing - 4,
            runSpacing: r.cardSpacing - 4,
            children: data.categories
                .map(
                  (cat) => SizedBox(
                    width: _categoryCardWidth(context),
                    child: _CategoryTile(
                      category: cat,
                      onTap: () => context.go('/lessons/${cat.id}'),
                      r: r,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  double _categoryCardWidth(BuildContext context) {
    final cols = r.gridColumns;
    final w = MediaQuery.of(context).size.width - r.padHorizontal * 2;
    final spacing = (cols - 1) * (r.cardSpacing - 4);
    return (w - spacing) / cols;
  }
}

class _StatData {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatData(this.icon, this.value, this.label, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  final ResponsiveHelper r;
  const _StatCard({required this.data, required this.r});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: r.isDesktop ? 20 : 16,
        horizontal: r.isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(data.icon, color: data.color, size: r.iconSizeMedium),
          SizedBox(height: r.isDesktop ? 10 : 8),
          Text(
            data.value,
            style: GoogleFonts.outfit(
              fontSize: r.isDesktop ? 26 : 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: GoogleFonts.inter(
              fontSize: r.isDesktop ? 13 : 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;
  final ResponsiveHelper r;
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.r,
  });

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseColor(category.colorHex);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(r.borderRadius - 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.borderRadius - 2),
        child: Padding(
          padding: EdgeInsets.all(r.cardSpacing),
          child: Row(
            children: [
              Container(
                width: r.isDesktop ? 56 : 48,
                height: r.isDesktop ? 56 : 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    category.emoji,
                    style: TextStyle(fontSize: r.isDesktop ? 28 : 24),
                  ),
                ),
              ),
              SizedBox(width: r.cardSpacing),
              Expanded(
                child: Text(
                  category.name,
                  style: GoogleFonts.inter(
                    fontSize: r.bodyFontSize,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                size: r.iconSizeMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final ResponsiveHelper r;
  const _WeeklyChart({required this.r});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final values = [3, 2, 4, 3, 1, 0, 0];

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final maxVal = values.reduce((a, b) => a > b ? a : b);
              final height = maxVal > 0 ? (values[i] / maxVal * 100) : 5.0;
              final isToday = i == 4;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.isDesktop ? 6 : 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${values[i]}',
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 2,
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                      SizedBox(height: r.isDesktop ? 6 : 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        height: height + 8,
                        decoration: BoxDecoration(
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(height: r.cardSpacing - 4),
        Row(
          children: List.generate(7, (i) {
            final isToday = i == 4;
            return Expanded(
              child: Center(
                child: Container(
                  width: r.isDesktop ? 28 : 24,
                  height: r.isDesktop ? 28 : 24,
                  decoration: isToday
                      ? BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(
                            r.isDesktop ? 14 : 12,
                          ),
                        )
                      : null,
                  child: Center(
                    child: Text(
                      days[i],
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize - 2,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
