import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin_panel/presentation/admin_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/kitchen_dashboard/presentation/kitchen_screen.dart';
import '../../features/room_menu/presentation/room_menu_screen.dart';
import '../../features/waiter_app/presentation/waiter_screen.dart';



final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/', // Điểm bắt đầu luôn là Splash Screen
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
      GoRoute(
        path: '/waiter',
        builder: (context, state) => const WaiterScreen(),
      ),
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => const KitchenScreen(),
      ),
      GoRoute(
        path: '/menu',
        builder: (context, state) => const RoomMenuScreen(),
      ),
    ],
  );
});