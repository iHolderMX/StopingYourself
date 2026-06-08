import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/lesson.dart';
import '../../../models/user_progress.dart';

final lessonDetailProvider =
    FutureProvider.family<Lesson?, String>((ref, lessonId) {
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
          if (lesson == null) {
            return const Center(child: Text('Lección no encontrada'));
          }
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Lección completada! +25 XP'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCompleting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar progreso')),
        );
      }
    }
  }

  int _calculateScore() {
    final base = switch (widget.lesson.difficultyLevel) {
      1 => 10,
      2 => 25,
      3 => 50,
      _ => 15,
    };
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = widget.lesson;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                _completed ? Icons.verified : Icons.menu_book_rounded,
                size: 64,
                color: _completed ? const Color(0xFF228B22) : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              lesson.title,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lesson.description,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _DifficultyBadge(level: lesson.difficultyLevel),
            const SizedBox(height: 32),
            if (lesson.content != null && lesson.content!.isNotEmpty) ...[
              Text(
                'Contenido de la lección',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildContent(lesson.content!, theme),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Contenido próximamente',
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_isCompleting || _completed) ? null : _markCompleted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _completed
                      ? const Color(0xFF228B22)
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
                        _completed ? '¡Completada!' : 'Marcar como completada',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> content, ThemeData theme) {
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
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          case 'text':
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.6,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            );
          case 'quote':
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          default:
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(value),
            );
        }
      }).toList(),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  final int level;

  const _DifficultyBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (level) {
      case 1:
        label = '🟢 Fácil';
        color = const Color(0xFF4CAF50);
      case 2:
        label = '🟡 Intermedio';
        color = Colors.orange;
      case 3:
        label = '🔴 Avanzado';
        color = Colors.red;
      default:
        label = '⚪ Básico';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
