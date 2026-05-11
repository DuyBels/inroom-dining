import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/admin_panel/presentation/views/menu_management_view.dart';
import '../../../main.dart';

// Import các giao diện tính năng con
import 'views/account_management_view.dart';
import 'views/category_management_view.dart';
import 'views/tag_management_view.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Trạng thái lưu tab đang được chọn (Mặc định là 0 - Quản lý tài khoản)
  int _selectedIndex = 0;

  // Danh sách các màn hình tính năng tương ứng với các mục ở thanh Menu
  final List<Widget> _views = [
    const AccountManagementView(),
    const CategoryManagementView(),
    const MenuManagementView(), // <-- Đã được thay thế thành View Thực Đơn
    const TagManagementView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Bảng Điều Khiển Admin',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.blue[800],
        actions: [
          // Nút Đăng xuất
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              // Gọi API đăng xuất của Supabase
              await supabase.auth.signOut();
              // Chuyển hướng người dùng về trang đăng nhập
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 16), // Khoảng cách lề phải
        ],
      ),
      body: Row(
        children: [
          // ==========================================
          // SIDEBAR: THANH MENU ĐIỀU HƯỚNG BÊN TRÁI
          // ==========================================
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.blue[50],
            selectedIconTheme: IconThemeData(color: Colors.blue[800], size: 28),
            unselectedIconTheme: IconThemeData(color: Colors.grey[700]),
            selectedLabelTextStyle: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: TextStyle(color: Colors.grey[700]),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Tài khoản'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Danh mục'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
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

          // Đường kẻ dọc phân cách giữa Menu và Nội dung
          const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),

          // ==========================================
          // KHU VỰC HIỂN THỊ NỘI DUNG CHÍNH
          // ==========================================
          Expanded(
            child: Container(
              color: Colors.grey[50], // Màu nền nhạt cho khu vực nội dung
              child: _views[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}