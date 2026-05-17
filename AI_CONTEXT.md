# AI Context: StopingYourself

Este archivo está diseñado para que cualquier IA asistente (como yo) pueda entender rápidamente de qué trata el proyecto, sus reglas de arquitectura y diseño, y pueda retomarlo sin perder contexto.

## 1. Visión General
**Nombre del Proyecto**: StopingYourself
**Framework**: Flutter (Multiplataforma: Móvil, Web, Escritorio)
**Licencia**: GNU GPLv3 (Todo uso o distribución debe mantenerse como software libre).
**Objetivo**: Aplicación segura con sistema de login, recuperación de contraseña por correo, y futura implementación de autenticación de dos factores (2FA). 

## 2. Temática Visual (UI/UX)
El diseño debe sentirse premium y elegante. Se prohíben colores genéricos.
Paleta obligatoria:
- **Mármol** (Superficies/Fondos): `#F0F0F0`, `#E8E8E8` o texturas sutiles blancas.
- **Oro** (Acentos, Botones principales, Iconos destacados): `#D4AF37`, `#C5A059`.
- **Gris** (Texto secundario, bordes, elementos neutros): `#808080`, `#4A4A4A`.
- **Madera** (Paneles secundarios, tarjetas, detalles cálidos): `#8B5A2B`, `#A0522D`.
- **Verde Bosque** (Éxito, validaciones, elementos de estado): `#228B22`, `#006400`.

*Nota de diseño*: Usar gradientes suaves, micro-animaciones en botones e inputs, y tipografías modernas (ej. Google Fonts como Inter o Outfit).

## 3. Arquitectura del Proyecto Flutter
Se seguirá una estructura basada en características (Feature-First) o Clean Architecture simplificada.
```text
lib/
  core/
    theme/        # Archivos de colores, tipografías y tema global.
    utils/        # Funciones helpers.
  features/
    auth/         # Módulo de Autenticación.
      screens/    # LoginScreen, PasswordRecoveryScreen, TwoFactorScreen.
      widgets/    # Componentes específicos de auth.
      services/   # Conexión a backend/mock para auth.
  main.dart       # Punto de entrada.
```

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
