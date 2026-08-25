import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/saving_goal_image_rules.dart';
import '../money_colors.dart';
import 'saving_goal_image.dart';

/// Abre la galeria y devuelve la imagen elegida, o `null` si se cancelo.
///
/// Se piden `maxWidth` e `imageQuality` para que el plugin comprima antes de
/// entregar los bytes. En web el plugin puede ignorarlos, por eso el peso se
/// valida despues contra [SavingGoalImageRules].
Future<SavingGoalImageUpload?> pickSavingGoalImage() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  return SavingGoalImageUpload(fileName: picked.name, bytes: bytes);
}

/// Campo para elegir, ver, cambiar y quitar la foto de una meta.
///
/// Maneja tres estados a la vez, que es justo lo que hace falta al editar:
/// la foto ya guardada ([currentImagePath]), una recien elegida sin guardar
/// ([pickedImage]) y la intencion de quitarla ([imageRemoved]).
class GoalImagePickerField extends StatelessWidget {
  const GoalImagePickerField({
    super.key,
    required this.currentImagePath,
    required this.pickedImage,
    required this.imageRemoved,
    required this.onPick,
    required this.onRemove,
    this.enabled = true,
    this.height = 150,
  });

  /// Ruta de la imagen ya guardada, si la meta tiene una.
  final String? currentImagePath;

  /// Imagen elegida en esta sesion de edicion, aun sin subir.
  final SavingGoalImageUpload? pickedImage;

  /// El usuario pidio quitar la foto existente.
  final bool imageRemoved;

  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool enabled;
  final double height;

  bool get _showsSavedImage =>
      pickedImage == null && !imageRemoved && currentImagePath != null;

  bool get _hasSomethingToShow => pickedImage != null || _showsSavedImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.photo_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Foto (opcional)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_hasSomethingToShow)
          _preview(theme)
        else
          _emptyPicker(theme),
      ],
    );
  }

  Widget _preview(ThemeData theme) {
    final picked = pickedImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: picked != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        picked.bytes,
                        height: height,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : SavingGoalImage(
                      imagePath: currentImagePath!,
                      height: height,
                      width: double.infinity,
                    ),
            ),
            if (picked != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Sin guardar',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onPick : null,
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Cambiar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onRemove : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MoneyColors.negative,
                  side: BorderSide(
                    color: MoneyColors.negative.withValues(alpha: 0.5),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Quitar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyPicker(ThemeData theme) {
    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 6),
            Text(
              imageRemoved ? 'Foto quitada, toca para elegir otra' : 'Agregar foto',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${SavingGoalImageRules.allowedExtensions.join(', ')} · '
              'max ${SavingGoalImageRules.maxSizeMb.toStringAsFixed(0)} MB',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
