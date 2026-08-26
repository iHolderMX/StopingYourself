# AI Context: StopingYourself

Este archivo está diseñado para que cualquier IA asistente (como yo) pueda entender rápidamente de qué trata el proyecto, sus reglas de arquitectura y diseño, y pueda retomarlo sin perder contexto.

## 1. Visión General
**Nombre del Proyecto**: StopingYourself
**Framework**: Flutter (Multiplataforma: Móvil, Web, Escritorio)
**Licencia**: GNU GPLv3 (Todo uso o distribución debe mantenerse como software libre).
**Objetivo**: Aplicación segura con sistema de login, recuperación de contraseña por correo, y futura implementación de autenticación de dos factores (2FA). 

## 2. Temática Visual (UI/UX)
El diseño debe sentirse premium y elegante. La paleta real vive en
`lib/core/theme/app_theme.dart` (fuente de verdad). Hay dos temas:

- **Tema oscuro (principal)**: azul neón sobre negro/grises.
  - Neón: `#00D4FF` (primary), `#4DE8FF` (bright), `#0099BB` (dim).
  - Fondos: `#0A0A0F` (negro), `#18181F`, `#1E1E26`, `#2A2A35`, `#3A3A48`.
  - Texto: `#E0E0E0` (claro), `#888899` (atenuado).
- **Tema claro**: `#1A73E8` (primary), `#4A90D9` (secondary), fondo `#F8F9FA`.

Colores semánticos de finanzas: `lib/features/money/presentation/money_colors.dart`
(`MoneyColors`: positive/negative/warning/emergency + paleta de gráficas).

*Nota de diseño*: gradientes suaves, micro-animaciones y tipografías Google
Fonts (Inter para body, Outfit para títulos).

> Nota histórica: una versión previa de este documento describía una paleta
> mármol/oro/madera/verde bosque que nunca se implementó. El tema real es el
> descrito arriba.

## 3. Arquitectura del Proyecto Flutter
Estructura basada en características (Feature-First). Estado con **Riverpod**
(sin codegen), navegación con **go_router**, backend en **Supabase**.

```text
lib/
  core/
    theme/        # app_theme.dart (paleta y tema global).
    router/       # app_router.dart (GoRouter + ShellRoute).
    services/     # database_service.dart, supabase_service.dart, openai_service.dart.
    utils/        # responsive_helper.dart.
  features/
    <feature>/
      screens/    # Pantallas (features aún no refactorizadas).
  main.dart
```

### Módulo de referencia: `features/money/` (Clean Architecture por capas)
El módulo de finanzas es el patrón a seguir para el resto. Cuatro capas:

```text
features/money/
  domain/         # Reglas de negocio como funciones puras (sin Flutter/Supabase).
                  #   yield_rules, salary_rules, debt_rules, saving_goal_rules,
                  #   emergency_fund_rules. Testeadas al 100%.
  data/           # Repositorios (uno por agregado) + money_providers.dart
                  #   (TODOS los providers viven aquí, no en la UI) +
                  #   money_failure.dart (errores tipados, no se tragan).
  application/    # Controllers (casos de uso): validan con domain, escriben
                  #   con data e invalidan providers. IDs con uuid (money_id.dart).
  presentation/   # Widgets. Solo pintan y llaman controllers. Sin lógica de negocio.
```

**Archivos e imágenes**: no se guardan en la base de datos. Van a **Supabase
Storage** y la tabla solo guarda la *ruta* dentro del bucket (nunca la URL,
porque los buckets son privados y las URLs firmadas caducan). Referencia:
metas de ahorro con foto (`saving_goal_image_rules.dart`,
`saving_goal_images_repository.dart`, bucket `saving-goal-images`).

Reglas al extender el módulo o replicar el patrón:
- La UI **nunca** llama a Supabase ni a `DatabaseService` directo: usa controllers.
- Los cálculos (porcentajes, totales, validaciones) van en `domain/`, no en widgets.
- Los providers se declaran en `data/money_providers.dart`, no dentro de pantallas.
- Los errores se muestran con `describeMoneyError`; no hay `catch` que devuelva
  listas vacías disfrazando fallos.

## 3.1 Secretos y configuración

**El proyecto no tiene secretos y debe seguir así.** No hay `.env` versionado
ni variables de entorno necesarias para compilar o desplegar.

- `AppConfig.supabaseUrl` y `AppConfig.supabaseAnonKey` viven en el código a
  propósito: la clave es *publishable* y está diseñada para ser pública. Lo que
  protege los datos son las políticas **RLS** de cada tabla.
- En Flutter Web **cualquier valor empaquetado es público** (se descarga al
  navegador). No sirve `.env`, ni `--dart-define`, ni variables del hosting.
- Si en el futuro se necesita una llave privada (OpenAI, pasarelas de pago,
  etc.), **va en una Supabase Edge Function**, nunca en el cliente. Ver
  `DEUDA_TECNICA.md`.

Deploy en Vercel: `vercel.json` hace el rewrite a `index.html` (necesario para
`go_router`, si no un refresh en `/money` da 404). Output: `build/web`.

## 4. Backend y Seguridad
- Actualmente el backend es **Mock/Temporal** para validar UI y flujos.
- En el futuro se migrará a una solución de bajo costo y alta seguridad.
- El flujo de recuperación debe contemplar entrada de correo -> envío de código -> validación de código de 6 dígitos.
- 2FA debe estar preparado en UI para aceptar apps tipo Google Authenticator (TOTP) o SMS.

## 5. Próximos Pasos (Hoja de Ruta)
1. Setup inicial (Paleta de colores en Flutter).
2. UI de Login (`LoginScreen`).
3. UI de Recuperación (`PasswordRecoveryScreen` y dialog/pantalla para código).
4. Configuración de Lógica Mock.
5. Integración con backend real.
