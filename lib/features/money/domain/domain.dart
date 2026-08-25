/// Capa de dominio del modulo de finanzas.
///
/// Todo lo que hay aqui son funciones puras: no tocan Supabase, no tocan
/// Flutter y no dependen de Riverpod. Son la unica fuente de verdad de las
/// reglas de negocio y por eso se pueden testear sin montar un widget.
library;

export 'debt_rules.dart';
export 'emergency_fund_rules.dart';
export 'salary_rules.dart';
export 'saving_goal_image_rules.dart';
export 'saving_goal_rules.dart';
export 'yield_rules.dart';
