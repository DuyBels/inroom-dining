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
    initialLocation: '/', 
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
        routes: [
          GoRoute(
            path: ':adminId',
            builder: (context, state) {
              final adminId = state.pathParameters['adminId'];
              return AdminScreen(adminId: adminId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/waiter',
        builder: (context, state) => const WaiterScreen(),
        routes: [
          GoRoute(
            path: ':waiterId',
            builder: (context, state) {
              final waiterId = state.pathParameters['waiterId'];
              return WaiterScreen(waiterId: waiterId);
            },
          ),
        ],
      ),
      // CẤU HÌNH ĐƯỜNG DẪN DYNAMIC ĐỂ TÁCH BIỆT TAB
      GoRoute(
        path: '/kitchen',
        builder: (context, state) => const KitchenScreen(),
        routes: [
          GoRoute(
            path: ':stationId',
            builder: (context, state) {
              final stationId = state.pathParameters['stationId'];
              return KitchenScreen(stationId: stationId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/menu',
        builder: (context, state) => const RoomMenuScreen(),
        routes: [
          GoRoute(
            path: ':roomNumber',
            builder: (context, state) {
              final roomNumber = state.pathParameters['roomNumber'];
              return RoomMenuScreen(roomNumber: roomNumber);
            },
          ),
        ],
      ),
    ],
  );
});
