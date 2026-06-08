import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

final supabaseAuthProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(ref.watch(supabaseClientProvider));
});

class SupabaseAuthService {
  final SupabaseClient _client;

  SupabaseAuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error de conexión. Verifica tu internet.';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error de conexion. Verifica tu internet.';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
