import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Điều Khiển Menu', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Dữ liệu Quản trị viên sẽ hiển thị ở đây.', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}