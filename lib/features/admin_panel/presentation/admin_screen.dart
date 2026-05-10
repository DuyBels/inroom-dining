import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/admin_panel/presentation/views/tag_management_view.dart';
import '../../../main.dart';
import 'views/account_management_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0; // Trạng thái đang chọn tab nào

  // Danh sách các màn hình tính năng
  final List<Widget> _views = [
    const AccountManagementView(),
    const Center(child: Text('Tính năng Quản lý Menu (Sẽ làm sau)')),
    const TagManagementView(), // <-- Cập nhật Tab thứ 3 bằng giao diện này
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Điều Khiển Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          )
        ],
      ),
      body: Row(
        children: [
          // Thanh Menu bên trái
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.blue[50],
            selectedIconTheme: IconThemeData(color: Colors.blue[800]),
            selectedLabelTextStyle: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Tài khoản'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: Text('Thực đơn'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer),
                label: Text('Thẻ dữ liệu'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Khu vực hiển thị nội dung bên phải
          Expanded(
            child: _views[_selectedIndex],
          ),
        ],
      ),
    );
  }
}