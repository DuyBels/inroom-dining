import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart'; // import biến supabase

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Đợi 1 chút để UI kịp render hiệu ứng loading (Tùy chọn)
    await Future.delayed(const Duration(milliseconds: 500));

    final session = supabase.auth.currentSession;

    if (session == null) {
      // Chưa đăng nhập -> Đẩy ra trang login
      if (mounted) context.go('/login');
    } else {
      // Đã đăng nhập -> Lấy Role để chia đường
      try {
        final profile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', session.user.id)
            .single();

        final String role = profile['role'];

        if (!mounted) return;

        switch (role) {
          case 'ADMIN': context.go('/admin'); break;
          case 'WAITER': context.go('/waiter'); break;
          case 'STATION': context.go('/kitchen'); break;
          case 'ROOM': context.go('/menu'); break;
          default: context.go('/login');
        }
      } catch (e) {
        // Lỗi lấy profile -> Bắt đăng nhập lại
        await supabase.auth.signOut();
        if (mounted) context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.deepOrange,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}