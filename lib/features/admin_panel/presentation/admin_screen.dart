import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import 'package:inroom_dining/features/staff_chat/presentation/widgets/staff_chat_drawer.dart';
import '../../staff_chat/providers/chat_provider.dart';
import '../../../core/l10n/app_localizations.dart';
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
import 'views/qr_generator_view.dart';

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
  final List<Widget> _views = const [
    AccountManagementView(),
    StationManagementView(),
    CategoryManagementView(),
    MenuManagementView(),
    TagManagementView(),
    AdminHistoryView(),
    QrGeneratorView(),
  ];

  @override
  Widget build(BuildContext context) {
    final adminId = widget.adminId;
    final profileAsync = ref.watch(userProfileProvider);
    final l10n = ref.watch(l10nProvider);

    // 1. Kiểm tra trạng thái Redirect (Nếu chưa có ID trên URL)
    if (adminId == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('${l10n.errorPrefix}: $e'))),
        data: (profile) {
          if (profile != null && profile['role'] == 'ADMIN') {
            final id = profile['id'];
            Future.microtask(() => context.go('/admin/$id'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return Scaffold(
            body: Center(
              child: Text(l10n.noPermission),
            ),
          );
        },
      );
    }

    return Theme(
      data: AdminTheme.themeData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
          final isDesktop = constraints.maxWidth >= 1024;

          final tabTitles = [
            l10n.accountsTab,
            l10n.stationsTab,
            l10n.categoriesTab,
            l10n.menuTab,
            l10n.tagsTab,
            l10n.adminHistoryTab,
            l10n.qrCodeTab,
          ];

          final tabIcons = const [
            Icons.people_outline,
            Icons.countertops_outlined,
            Icons.category_outlined,
            Icons.restaurant_menu_outlined,
            Icons.local_offer_outlined,
            Icons.history_outlined,
            Icons.qr_code_2_outlined,
          ];

          final selectedTabIcons = const [
            Icons.people,
            Icons.countertops,
            Icons.category,
            Icons.restaurant_menu,
            Icons.local_offer,
            Icons.history,
            Icons.qr_code_2,
          ];

          return Scaffold(
            key: _scaffoldKey,
            endDrawer: const StaffChatDrawer(),
            // Drawer cho màn hình điện thoại (Mobile)
            drawer: isMobile
                ? NavigationDrawer(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                      Navigator.pop(context); // Đóng drawer sau khi chọn tab
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 20, 16, 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdminTheme.primaryWood,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.adminPanelTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AdminTheme.textDarkWood,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(indent: 16, endIndent: 16, height: 16),
                      ...List.generate(tabTitles.length, (index) {
                        return NavigationDrawerDestination(
                          icon: Icon(tabIcons[index]),
                          selectedIcon: Icon(selectedTabIcons[index], color: AdminTheme.primaryWood),
                          label: Text(tabTitles[index]),
                        );
                      }),
                    ],
                  )
                : null,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              leading: isMobile
                  ? IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: 'Menu',
                    )
                  : null,
              title: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    isMobile ? tabTitles[_selectedIndex] : l10n.adminPanelTitle,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              backgroundColor: AdminTheme.primaryWood,
              elevation: 2,
              actions: [
                Builder(
                  builder: (ctx) {
                    final hasUnread = ref.watch(hasUnreadMessagesProvider);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                          tooltip: 'Trò chuyện nhân viên',
                          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.amber[400],
                                shape: BoxShape.circle,
                                border: Border.all(color: AdminTheme.primaryWood, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const LanguageSelector(),
                const SizedBox(width: 4),
                // Nút Đăng xuất
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: l10n.logout,
                  onPressed: () async {
                    ref.invalidate(userProfileProvider);
                    await supabase.auth.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Row(
              children: [
                // ==========================================
                // SIDEBAR: THANH MENU BÊN TRÁI (cho Desktop & Tablet)
                // ==========================================
                if (!isMobile)
                  NavigationRail(
                    extended: isDesktop,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: isDesktop ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
                    backgroundColor: AdminTheme.surfaceWhite,
                    indicatorColor: AdminTheme.lightWoodCream,
                    selectedIconTheme: const IconThemeData(color: AdminTheme.primaryWood, size: 26),
                    unselectedIconTheme: const IconThemeData(color: AdminTheme.textMutedWood, size: 22),
                    selectedLabelTextStyle: const TextStyle(
                      color: AdminTheme.primaryWood,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: AdminTheme.textMutedWood,
                      fontSize: 12,
                    ),
                    destinations: List.generate(tabTitles.length, (index) {
                      return NavigationRailDestination(
                        icon: Icon(tabIcons[index]),
                        selectedIcon: Icon(selectedTabIcons[index]),
                        label: Text(tabTitles[index]),
                      );
                    }),
                  ),

                // Đường kẻ dọc phân cách giữa Menu và Nội dung
                if (!isMobile)
                  const VerticalDivider(thickness: 1, width: 1, color: AdminTheme.borderWood),

                // ==========================================
                // KHU VỰC HIỂN THỊ NỘI DUNG CHÍNH
                // ==========================================
                Expanded(
                  child: Container(
                    color: AdminTheme.bgWarmWhite,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey<int>(_selectedIndex),
                        child: _views[_selectedIndex],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}