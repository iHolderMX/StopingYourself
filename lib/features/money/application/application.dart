/// Capa de aplicacion del modulo de finanzas.
///
/// Cada controller compone tres pasos que antes estaban dentro de los widgets:
/// validar con las reglas de `domain/`, escribir con los repositorios de
/// `data/` y refrescar las lecturas afectadas. La UI solo llama metodos y
/// traduce errores con [describeMoneyError].
library;

export 'debts_controller.dart';
export 'emergency_funds_controller.dart';
export 'finance_reset_controller.dart';
export 'fixed_expenses_controller.dart';
export 'money_error_message.dart';
export 'money_id.dart';
export 'money_records_controller.dart';
export 'quincena_controller.dart';
export 'salary_controller.dart';
export 'saving_goals_controller.dart';
