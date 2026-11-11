import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/database_service.dart';
import '../../models/relapse_record.dart';

/// Tipos de recaida disponibles en el formulario.
const relapseTypes = [
  'Cero',
  'Alcohol',
  'Tabaco',
  'Drogas',
  'Juego',
  'Comida',
  'Tecnologia / Redes',
  'Otro',
];

/// Carga ligera para el panel principal: tipo y fecha, sin notas.
/// Suficiente para contadores, racha y proxima meta.
final relapseSummaryProvider =
    FutureProvider.family<List<RelapseRecord>, String>((ref, userId) {
      return ref.watch(databaseServiceProvider).getRelapseSummary(userId);
    });

/// Historial completo (incluye notas). Solo lo consume la pantalla de
/// historial, que se abre bajo demanda.
final relapseHistoryProvider =
    FutureProvider.family<List<RelapseRecord>, String>((ref, userId) {
      return ref.watch(databaseServiceProvider).getRelapseRecords(userId);
    });

/// Tonos de azul neon, variando la opacidad.
Color relapseTypeColor(int i, Color neon) {
  final alphas = [1.0, 0.85, 0.7, 0.55, 0.45, 0.35, 0.25, 0.15];
  return neon.withValues(alpha: alphas[i % alphas.length]);
}

/// Formatea una duracion en texto legible.
String formatRelapseDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;

  final parts = <String>[];
  if (days >= 365) {
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    parts.add('$years a${years > 1 ? 'ños' : 'ño'}');
    if (months > 0) parts.add('$months m');
  } else if (days >= 30) {
    final months = days ~/ 30;
    final remaining = days % 30;
    parts.add('$months m${months > 1 ? 'eses' : 'es'}');
    if (remaining > 0) parts.add('$remaining d');
  } else if (days >= 1) {
    parts.add('$days d');
  }

  if (hours > 0) parts.add('$hours h');
  parts.add('$minutes min');
  parts.add('$seconds s');

  return parts.join(' ');
}

/// Version compacta para promedios: omite las unidades en cero cuando ya hay
/// una unidad mayor. Ej: "1 d", "8 h 30 min", "45 min", "30 s".
String formatRelapseDurationCompact(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;

  final parts = <String>[];
  if (days >= 365) {
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    parts.add('$years a${years > 1 ? 'ños' : 'ño'}');
    if (months > 0) parts.add('$months m');
  } else if (days >= 30) {
    final months = days ~/ 30;
    final remaining = days % 30;
    parts.add('$months m${months > 1 ? 'eses' : 'es'}');
    if (remaining > 0) parts.add('$remaining d');
  } else if (days >= 1) {
    parts.add('$days d');
  }

  if (hours > 0) parts.add('$hours h');
  if (minutes > 0 && days < 1) parts.add('$minutes min');

  if (parts.isEmpty) parts.add('${d.inSeconds % 60} s');

  return parts.join(' ');
}
