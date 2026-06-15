import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../models/lesson.dart';
import '../../../models/user_progress.dart';

final lessonDetailProvider = FutureProvider.family<Lesson?, String>((
  ref,
  lessonId,
) {
  final db = ref.watch(databaseServiceProvider);
  return db.getLesson(lessonId);
});

class LessonDetailScreen extends ConsumerWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonDetailProvider(lessonId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: lessonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lesson) {
          if (lesson == null)
            return const Center(child: Text('Leccion no encontrada'));
          return _LessonContent(lesson: lesson);
        },
      ),
    );
  }
}

class _LessonContent extends ConsumerStatefulWidget {
  final Lesson lesson;
  const _LessonContent({required this.lesson});
  @override
  ConsumerState<_LessonContent> createState() => _LessonContentState();
}

class _LessonContentState extends ConsumerState<_LessonContent> {
  bool _isCompleting = false;
  bool _completed = false;

  Future<void> _markCompleted() async {
    final user = ref.read(supabaseClientProvider).auth.currentUser;
    if (user == null) return;
    setState(() => _isCompleting = true);
    try {
      final db = ref.read(databaseServiceProvider);
      final progress = UserProgress(
        id: '${user.id}_${widget.lesson.id}',
        userId: user.id,
        lessonId: widget.lesson.id,
        completed: true,
        score: _calculateScore(),
        completedAt: DateTime.now(),
      );
      await db.upsertProgress(progress);
      setState(() {
        _isCompleting = false;
        _completed = true;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Leccion completada! +25 XP'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
    } catch (e) {
      setState(() => _isCompleting = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar progreso')),
        );
    }
  }

  int _calculateScore() => switch (widget.lesson.difficultyLevel) {
    1 => 10,
    2 => 25,
    3 => 50,
    _ => 15,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = widget.lesson;
    final r = ResponsiveHelper(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: r.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                _completed ? Icons.verified : Icons.menu_book_rounded,
                size: r.iconSizeLarge,
                color: _completed
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.primary,
              ),
            ),
            SizedBox(height: r.cardSpacing + 2),
            Text(
              lesson.title,
              style: GoogleFonts.outfit(
                fontSize: r.titleFontSize,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            Text(
              lesson.description,
              style: GoogleFonts.inter(
                fontSize: r.bodyFontSize,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            SizedBox(height: r.cardSpacing + 4),
            _DifficultyBadge(level: lesson.difficultyLevel, responsive: r),
            SizedBox(height: r.cardSpacing + 12),
            if (lesson.content != null && lesson.content!.isNotEmpty) ...[
              Text(
                'Contenido de la leccion',
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize + 2,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: r.cardSpacing - 4),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.cardSpacing + 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(r.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildContent(lesson.content!, theme, r),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(r.isDesktop ? 48 : 32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(r.borderRadius),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      size: r.iconSizeLarge,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    SizedBox(height: r.cardSpacing),
                    Text(
                      'Contenido proximamente',
                      style: GoogleFonts.inter(
                        fontSize: r.bodyFontSize,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: r.cardSpacing + 16),
            SizedBox(
              width: double.infinity,
              height: r.buttonHeight,
              child: ElevatedButton(
                onPressed: (_isCompleting || _completed)
                    ? null
                    : _markCompleted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _completed
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.primary,
                ),
                child: _isCompleting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _completed ? 'Completada!' : 'Marcar como completada',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    Map<String, dynamic> content,
    ThemeData theme,
    ResponsiveHelper r,
  ) {
    final sections = content['sections'] as List<dynamic>? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map<Widget>((section) {
        final s = section as Map<String, dynamic>;
        final type = s['type'] as String? ?? 'text';
        final value = s['value'] as String? ?? '';
        switch (type) {
          case 'heading':
            return Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: r.subtitleFontSize + 2,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          case 'text':
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize,
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            );
          case 'quote':
            return Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              padding: EdgeInsets.all(r.cardSpacing),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.borderRadius - 2),
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: r.bodyFontSize,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          default:
            return Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(value),
            );
        }
      }).toList(),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final int level;
  final ResponsiveHelper responsive;
  const _DifficultyBadge({required this.level, required this.responsive});

  @override
  Widget build(BuildContext context) {
    final neon = Theme.of(context).colorScheme.primary;
    String label;
    Color color;
    switch (level) {
      case 1:
        label = 'Facil';
        color = neon;
      case 2:
        label = 'Intermedio';
        color = neon.withValues(alpha: 0.7);
      case 3:
        label = 'Avanzado';
        color = neon.withValues(alpha: 0.4);
      default:
        label = 'Basico';
        color = neon.withValues(alpha: 0.2);
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: responsive.bodyFontSize - 1,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
