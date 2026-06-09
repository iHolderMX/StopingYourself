import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/lesson.dart';

final lessonsProvider = FutureProvider.family<List<Lesson>, String>((
  ref,
  categoryId,
) {
  final db = ref.watch(databaseServiceProvider);
  return db.getLessonsByCategory(categoryId);
});

class LessonsScreen extends ConsumerWidget {
  final String categoryId;
  const LessonsScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonsProvider(categoryId));
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'Lecciones',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: r.subtitleFontSize + 4,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: lessonsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: r.cardSpacing),
              Text('Error: $e'),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(lessonsProvider(categoryId)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (lessons) {
          if (lessons.isEmpty)
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: r.iconSizeLarge,
                    color: Colors.grey,
                  ),
                  SizedBox(height: r.cardSpacing),
                  Text(
                    'No hay lecciones disponibles',
                    style: GoogleFonts.inter(
                      fontSize: r.bodyFontSize,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          return ListView.builder(
            padding: r.pagePadding,
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return _LessonCard(
                lesson: lesson,
                onTap: () => context.go('/lesson/${lesson.id}'),
                r: r,
              );
            },
          );
        },
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onTap;
  final ResponsiveHelper r;
  const _LessonCard({
    required this.lesson,
    required this.onTap,
    required this.r,
  });

  String _difficultyLabel(int level) => switch (level) {
    1 => 'Facil',
    2 => 'Intermedio',
    3 => 'Avanzado',
    _ => 'Basico',
  };
  Color _difficultyColor(int level) => switch (level) {
    1 => const Color(0xFF4CAF50),
    2 => Colors.orange,
    3 => Colors.red,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: r.cardSpacing - 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r.borderRadius),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.borderRadius),
        child: Padding(
          padding: EdgeInsets.all(r.cardSpacing),
          child: Row(
            children: [
              Container(
                width: r.isDesktop ? 56 : 50,
                height: r.isDesktop ? 56 : 50,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(r.borderRadius - 2),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: theme.colorScheme.primary,
                  size: r.iconSizeMedium,
                ),
              ),
              SizedBox(width: r.cardSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (lesson.description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: r.bodyFontSize - 1,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _difficultyColor(
                    lesson.difficultyLevel,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _difficultyLabel(lesson.difficultyLevel),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _difficultyColor(lesson.difficultyLevel),
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
