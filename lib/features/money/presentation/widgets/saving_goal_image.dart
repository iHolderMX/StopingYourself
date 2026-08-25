import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/money_providers.dart';
import '../money_colors.dart';

/// Muestra la imagen de una meta a partir de su ruta en Storage.
///
/// El bucket es privado, asi que primero hay que resolver una URL firmada.
/// Esa resolucion vive en `savingGoalImageUrlProvider`, que la cachea.
class SavingGoalImage extends ConsumerWidget {
  const SavingGoalImage({
    super.key,
    required this.imagePath,
    this.height,
    this.width,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  final String imagePath;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: width,
        child: ref.watch(savingGoalImageUrlProvider(imagePath)).when(
          loading: () => _placeholder(theme, child: const _Spinner()),
          error: (_, _) => _placeholder(
            theme,
            child: Icon(
              Icons.broken_image_outlined,
              color: MoneyColors.negative.withValues(alpha: 0.6),
              size: 28,
            ),
          ),
          data: (url) => Image.network(
            url,
            height: height,
            width: width,
            fit: fit,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : _placeholder(theme, child: const _Spinner()),
            errorBuilder: (context, _, _) => _placeholder(
              theme,
              child: Icon(
                Icons.broken_image_outlined,
                color: MoneyColors.negative.withValues(alpha: 0.6),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme, {required Widget child}) {
    return Container(
      height: height,
      width: width,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

/// Abre la imagen de una meta a pantalla completa, con zoom.
Future<void> showSavingGoalImageViewer(
  BuildContext context, {
  required String imagePath,
  required String goalName,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goalName,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: InteractiveViewer(
                maxScale: 4,
                child: SavingGoalImage(
                  imagePath: imagePath,
                  borderRadius: 16,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pellizca o usa la rueda para acercar',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    },
  );
}
