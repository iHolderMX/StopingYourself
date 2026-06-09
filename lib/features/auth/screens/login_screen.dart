import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive_helper.dart';
import '../services/supabase_auth_service.dart';

class IsLoadingNotifier extends Notifier<bool> {
  @override bool build() => false;
  void set(bool val) => state = val;
}
final isLoadingProvider = NotifierProvider<IsLoadingNotifier, bool>(IsLoadingNotifier.new);

class IsSignUpNotifier extends Notifier<bool> {
  @override bool build() => false;
  void toggle() => state = !state;
}
final isSignUpProvider = NotifierProvider<IsSignUpNotifier, bool>(IsSignUpNotifier.new);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final isSignUp = ref.read(isSignUpProvider);

    ref.read(isLoadingProvider.notifier).set(true);
    final authService = ref.read(supabaseAuthProvider);
    final error = isSignUp ? await authService.signUp(email, password) : await authService.signIn(email, password);
    ref.read(isLoadingProvider.notifier).set(false);
    if (!mounted) return;

    if (error == null) {
      if (isSignUp) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta creada! Ahora inicia sesion.')));
        ref.read(isSignUpProvider.notifier).toggle();
      } else {
        context.go('/dashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa tu correo primero')));
      return;
    }
    ref.read(isLoadingProvider.notifier).set(true);
    final error = await ref.read(supabaseAuthProvider).resetPassword(email);
    ref.read(isLoadingProvider.notifier).set(false);
    if (!mounted) return;
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Te enviamos un correo para restablecer tu contrasena.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(isLoadingProvider);
    final isSignUp = ref.watch(isSignUpProvider);
    final theme = Theme.of(context);
    final r = ResponsiveHelper(context);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: SingleChildScrollView(
              padding: r.pagePadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: r.formMaxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.shield_outlined, size: r.iconSizeLarge, color: AppTheme.goldAccent),
                      SizedBox(height: r.cardSpacing),
                      Text('Stoping\nYourself', textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: r.titleFontSize, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, height: 1.1)),
                      const SizedBox(height: 12),
                      Text('Cada dia, un paso mas lejos\nde lo que te detiene.', textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: r.subtitleFontSize, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                      SizedBox(height: r.isDesktop ? 56 : 36),
                      TextFormField(
                        controller: _emailController, keyboardType: TextInputType.emailAddress, autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Correo electronico', hintText: 'tu@email.com', prefixIcon: Icon(Icons.email_outlined)),
                        validator: (v) { if (v == null || v.trim().isEmpty) return 'Ingresa tu correo'; if (!v.contains('@')) return 'Correo invalido'; return null; },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController, obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Contrasena', hintText: 'Minimo 6 caracteres', prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                        ),
                        validator: (v) { if (v == null || v.length < 6) return 'Minimo 6 caracteres'; return null; },
                      ),
                      SizedBox(height: r.cardSpacing + 4),
                      SizedBox(height: r.buttonHeight,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSubmit,
                          child: isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(isSignUp ? 'Crear cuenta' : 'Iniciar sesion', style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                      if (!isSignUp) ...[
                        const SizedBox(height: 8),
                        TextButton(onPressed: isLoading ? null : _handleResetPassword,
                          child: Text('Olvide mi contrasena', style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () { ref.read(isSignUpProvider.notifier).toggle(); _formKey.currentState?.reset(); },
                        child: Text(isSignUp ? 'Ya tengo cuenta. Iniciar sesion' : 'No tengo cuenta. Crear una', style: GoogleFonts.inter(color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
