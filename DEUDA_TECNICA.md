# Deuda Técnica

Registro de cosas pendientes, decisiones postergadas y trampas conocidas.
La idea es que nada quede solo en la memoria de quien lo hizo.

---

## 🎫 Escaneo de tickets con OpenAI (retirado)

**Estado**: eliminado del proyecto. Pendiente de reimplementar si se quiere.

**Qué hacía**: en Finanzas → "Nuevo registro" había un botón de escáner. Elegías
la foto de un ticket, se mandaba a OpenAI (`gpt-4o`), y la respuesta
auto-rellenaba el monto y la descripción del formulario. Era un atajo para no
teclear el monto a mano; ninguna otra parte de la app dependía de ello.

**Por qué se quitó**: era lo único que necesitaba un secreto
(`OPENAI_API_KEY`), y en Flutter Web **no se puede esconder una llave en el
cliente**. Todo lo que se empaqueta se descarga al navegador y se puede
extraer con DevTools. Peor aún, el `.env` estaba declarado como *asset* en
`pubspec.yaml`, así que en un deploy habría quedado descargable directo en
`https://<host>/assets/.env`.

Al quitarlo, el proyecto quedó **sin ningún secreto**: no necesita variables de
entorno ni en local ni en Vercel.

**Qué se eliminó**:

- `lib/core/services/openai_service.dart`
- `_scanReceipt()` y `_showScannedItemsDialog()` de `money_tracking_screen.dart`
  (más el botón y el estado `_scanning`)
- La dependencia `flutter_dotenv` y la carga de `dotenv` en `main.dart`
- La entrada `assets: - .env` de `pubspec.yaml`
- `.env` del control de versiones (sigue en local, ya ignorado)

**Cómo reimplementarlo bien (si se retoma)**:

1. Crear una **Supabase Edge Function** (`supabase/functions/scan-receipt/`)
   que reciba la imagen y hable con OpenAI.
2. Guardar la llave como secreto de la función:
   `supabase secrets set OPENAI_API_KEY=...`. Así nunca sale del servidor.
3. Desde Dart llamar a `supabase.functions.invoke('scan-receipt')`. La sesión
   del usuario viaja sola, y en la función se valida que haya sesión.
4. Ubicarlo en las capas del módulo: repositorio en `data/`, caso de uso en
   `application/`, nunca llamado directo desde el widget (que es como estaba:
   `OpenAIService()` se instanciaba dentro del `State`).

⚠️ **Acción pendiente de seguridad**: la `OPENAI_API_KEY` quedó en el historial
de git de commits anteriores. Sacarla del tracking no la borra del historial.
**Hay que rotarla** en platform.openai.com aunque ya no se use.

---

## 🗄️ Base de datos

### Tablas sin migración versionada

Existen en Supabase pero no hay SQL en `supabase/migrations/`:
`money_records`, `fixed_expenses`, `salary_settings`, `debts`, `debt_payments`,
`monthly_payments`.

Sin el esquema versionado no se puede recrear el proyecto desde cero ni revisar
constraints en code review. No se generaron a ciegas desde los modelos de Dart
para no desalinearse con la base real.

### GRANTs faltantes: la trampa del error 42501

Postgres tiene **dos** capas de permisos y ambas fallan con el mismo código
`42501`:

1. **GRANT**: si el rol `authenticated` puede tocar la tabla.
2. **RLS**: qué filas puede tocar.

Las tablas creadas a mano por SQL pueden quedarse sin los `GRANT` que Supabase
aplica por defecto, y entonces **las políticas RLS ni se evalúan**. Se corrigió
en `supabase/migrations/fix_finance_grants.sql`, que además dejó
`ALTER DEFAULT PRIVILEGES` para que no vuelva a pasar.

Los mensajes de error en `money_failure.dart` ya distinguen ambas causas.

### `register_debt_payment` sin aplicar

`supabase/migrations/create_register_debt_payment.sql` define una función que
registra un pago y actualiza el saldo de la deuda en **una sola transacción**.
No está aplicada.

Mientras no se aplique, `DebtsRepository.registerPayment` usa un patrón de
**compensación**: si falla actualizar el saldo, borra el pago recién insertado.
Cubre el 95% de los casos, pero no es atómico de verdad.

### `DebtPayment` sin `user_id`

El modelo no tiene el campo. `deleteAllOf` en `DebtsRepository` filtra los pagos
por `debt_id` (obteniendo antes los ids de las deudas del usuario) justo para
esquivarlo. Funciona, pero implica una consulta extra.

---

## 💰 Reglas de negocio por confirmar

Se extrajeron al dominio **tal cual estaban** en la UI, para no cambiar
comportamiento durante el refactor. Están marcadas con `TODO(Gus)`:

- **`SalaryRules.quincenasPerMonth = 2`** → la quincena se asume como medio
  salario mensual. Si depende de días trabajados o de fechas de pago reales,
  este es el único lugar a cambiar.
- **`DebtRules.minimumPaymentRate = 0.06`** → pago mínimo sugerido del 6%. Si
  viene del contrato de una tarjeta concreta, debería ser un campo de la deuda
  y no una constante global.

---

## 🧹 Código huérfano o incompleto

- **`monthly_payments`**: tiene 6 métodos en `DatabaseService` y **cero**
  consumidores. Decidir si se conecta a una pantalla o se elimina. El reinicio
  de finanzas sí los borra.
- **`SalarySetting.dailyReturn`**: existe en el modelo y nunca se escribe.
- **Falta `updateFixedExpense`**: los gastos fijos solo se pueden crear y
  borrar, no editar. (Las metas de ahorro sí son totalmente editables.)
- **Métodos de finanzas en `DatabaseService`**: ya nadie del módulo `money` los
  usa (todo pasa por los repositorios de `data/`). Se pueden borrar, pero hay
  que verificar antes que ningún otro feature los llame.
- **`isar` / `isar_flutter_libs`**: declaradas en `pubspec.yaml` y no se usan en
  ninguna parte. Candidatas a eliminar.

---

## 🎨 UI

- **Colores sueltos**: `debts_content.dart` y `emergency_fund_content.dart`
  todavía usan algunos `Colors.green` / `Colors.red` / `Colors.amber` directos
  en lugar de `MoneyColors`. Cosmético.
- **`_selectedIndex` desincronizado en `AppShell`**: el índice del menú se
  guarda con `setState` y no se sincroniza con la URL. Un deep-link o el botón
  "atrás" del navegador dejan el menú marcando la sección equivocada.
- **Compresión de imágenes en web**: `pickSavingGoalImage()` pide `maxWidth` e
  `imageQuality`, pero `image_picker_for_web` puede ignorarlos. En web una foto
  puede llegar a tamaño original y ser rechazada por el límite de 5 MB. Si
  estorba, hay que redimensionar manualmente antes de subir.

---

## 🧪 Pruebas

- **Solo el módulo `money` tiene tests** (159, en `domain/` y `application/`).
  El resto de features (salud, LoL, lecciones, actividades, recaídas, auth) no
  tiene ninguna.
- **No hay tests de widget** en todo el proyecto. La UI se verifica a mano.
- **Los repositorios no tienen tests de integración**: se prueban vía fakes en
  los tests de controllers, así que las consultas reales a Supabase (filtros,
  nombres de columnas) no están cubiertas.

---

## 🏗️ Arquitectura

- **Solo `features/money` está por capas**
  (`domain` / `data` / `application` / `presentation`). Los demás features
  siguen siendo widgets que llaman a `DatabaseService` directo, con providers
  declarados dentro de los archivos de UI. El módulo de finanzas es el patrón a
  replicar (ver `AI_CONTEXT.md`).
- **`DatabaseService` sigue siendo un god-object** (~680 líneas) con todos los
  dominios juntos: salud, LoL, lecciones, actividades, perfil.
- **No se usan `AsyncNotifier` de Riverpod**: en Riverpod 3 el `family` de
  `AsyncNotifier` requiere `riverpod_generator`, que el proyecto no tiene. Se
  optó por controllers explícitos que reciben `Ref`. Si algún día se agrega
  `build_runner`, se puede migrar.
