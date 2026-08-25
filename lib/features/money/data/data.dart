/// Capa de datos del modulo de finanzas.
///
/// Un repositorio por agregado de negocio. Todos propagan [MoneyFailure] en
/// lugar de devolver listas vacias cuando algo falla, para que la UI pueda
/// distinguir "no tienes datos" de "no pude leerlos".
library;

export 'debts_repository.dart';
export 'emergency_funds_repository.dart';
export 'finance_reset_repository.dart';
export 'fixed_expenses_repository.dart';
export 'money_failure.dart';
export 'money_providers.dart';
export 'money_records_repository.dart';
export 'quincena_repository.dart';
export 'salary_repository.dart';
export 'saving_goal_images_repository.dart';
export 'saving_goals_repository.dart';
