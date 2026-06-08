import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/lessons/screens/lessons_screen.dart';
import '../../features/lessons/screens/lesson_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/relapse/screens/relapse_tracking_screen.dart';
import '../../features/money/screens/money_tracking_screen.dart';
import '../services/supabase_service.dart';
import '../shell/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = client.auth.currentUser != null;
      final isOnLogin = state.matchedLocation == '/';

      if (!isLoggedIn && !isOnLogin) {
        return '/';
      }
      if (isLoggedIn && isOnLogin) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/lessons-shell',
            builder: (context, state) => const _LessonsPlaceholder(),
          ),
          GoRoute(
            path: '/relapse',
            builder: (context, state) => const RelapseTrackingScreen(),
          ),
          GoRoute(
            path: '/money',
            builder: (context, state) => const MoneyTrackingScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/lessons/:categoryId',
            builder: (context, state) =>
                LessonsScreen(categoryId: state.pathParameters['categoryId']!),
          ),
          GoRoute(
            path: '/lesson/:lessonId',
            builder: (context, state) =>
                LessonDetailScreen(lessonId: state.pathParameters['lessonId']!),
          ),
        ],
      ),
    ],
  );
});

class _LessonsPlaceholder extends StatelessWidget {
  const _LessonsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Selecciona una categoria desde Inicio'));
  }
}
