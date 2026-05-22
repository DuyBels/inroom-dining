import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';

// Import các giao diện tính năng con
import 'views/account_management_view.dart';
import 'views/station_management_view.dart';
import 'views/category_management_view.dart';
import 'views/menu_management_view.dart';
import 'views/tag_management_view.dart';

class AdminScreen extends ConsumerStatefulWidget {
  final String? adminId;
  const AdminScreen({super.key, this.adminId});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  // Trạng thái lưu tab đang được chọn (Mặc định là 0 - Quản lý tài khoản)
  int _selectedIndex = 0;

  // Danh sách các màn hình tính năng tương ứng với các mục ở thanh Menu
  final List<Widget> _views = [
    const AccountManagementView(),
    const StationManagementView(),
    const CategoryManagementView(),
    const MenuManagementView(),
    const TagManagementView(),
  ];

  @override
  Widget build(BuildContext context) {
    final adminId = widget.adminId;
    final profileAsync = ref.watch(userProfileProvider);

    // 1. Kiểm tra trạng thái Redirect (Nếu chưa có ID trên URL)
    if (adminId == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (profile) {
          if (profile != null && profile['role'] == 'ADMIN') {
            final id = profile['id'];
            Future.microtask(() => context.go('/admin/$id'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(
            body: Center(
              child: Text('Bạn không có quyền quản trị.'),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bảng Điều Khiển Admin',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text('Admin ID: ${adminId.substring(0, 8)}...', style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        actions: [
          // Nút Đăng xuất
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              ref.invalidate(userProfileProvider);
              await supabase.auth.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 16),
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
            selectedLabelTextStyle: TextStyle(
              color: Colors.blue[800],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Tài khoản'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.countertops_outlined),
                selectedIcon: Icon(Icons.countertops),
                label: Text('Trạm bếp'),
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
              color: Colors.grey[50],
              child: _views[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}