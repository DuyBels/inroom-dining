import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/staff_chat/presentation/widgets/staff_chat_drawer.dart';
import '../../staff_chat/providers/chat_provider.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';

// Import các giao diện tính năng con
import 'views/account_management_view.dart';
import 'views/station_management_view.dart';
import 'views/category_management_view.dart';
import 'views/menu_management_view.dart';
import 'views/tag_management_view.dart';
import 'views/admin_history_view.dart';

class AdminScreen extends ConsumerStatefulWidget {
  final String? adminId;
  const AdminScreen({super.key, this.adminId});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Trạng thái lưu tab đang được chọn (Mặc định là 0 - Quản lý tài khoản)
  int _selectedIndex = 0;

  // Danh sách các màn hình tính năng tương ứng với các mục ở thanh Menu
  final List<Widget> _views = [
    const AccountManagementView(),
    const StationManagementView(),
    const CategoryManagementView(),
    const MenuManagementView(),
    const TagManagementView(),
    const AdminHistoryView(),
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
      key: _scaffoldKey,
      endDrawer: const StaffChatDrawer(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
          const LanguageSelector(),
          const SizedBox(width: 8),
          Builder(
            builder: (ctx) {
              final hasUnread = ref.watch(hasUnreadMessagesProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 12, top: 12,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.blue[800]!, width: 1.5)),
                      ),
                    ),
                ],
              );
            },
          ),
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
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Lịch sử'),
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