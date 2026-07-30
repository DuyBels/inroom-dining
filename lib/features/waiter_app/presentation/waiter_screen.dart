import 'dart:async';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/theme/waiter_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/staff_chat/presentation/widgets/staff_chat_drawer.dart';
import '../../staff_chat/providers/chat_provider.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/room_service_provider.dart';
import '../providers/waiter_provider.dart';

class WaiterScreen extends ConsumerStatefulWidget {
  final String? waiterId;
  const WaiterScreen({super.key, this.waiterId});
  @override
  ConsumerState<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends ConsumerState<WaiterScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0; // 0: Dịch vụ & Đơn hàng, 1: Lịch sử

  Future<void> _startDelivery(String orderId, String currentWaiterId) async {
    await supabase.from('orders').update({'delivery_waiter_id': currentWaiterId}).eq('id', orderId);
  }

  Future<void> _markAsDelivered(String orderId) async {
    await supabase.from('orders').update({'status': 'DELIVERED', 'delivered_at': DateTime.now().toUtc().toIso8601String()}).eq('id', orderId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${ref.read(l10nProvider).deliverySuccess}'), backgroundColor: WaiterTheme.readyGreen));
  }

  Future<void> _receiveService(String serviceId, String waiterId) async {
    try { await supabase.from('room_services').update({'status_id': ServiceStatus.processing, 'waiter_id': waiterId}).eq('id', serviceId); } catch (e) { debugPrint('Lỗi nhận dịch vụ: $e'); }
  }

  Future<void> _completeService(String serviceId) async {
    try { await supabase.from('room_services').update({'status_id': ServiceStatus.completed, 'completed_at': DateTime.now().toUtc().toIso8601String()}).eq('id', serviceId); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${ref.read(l10nProvider).taskDone}'), backgroundColor: WaiterTheme.readyGreen)); } catch (e) { debugPrint('Lỗi xong dịch vụ: $e'); }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}";
  }

  void _setupNotificationListeners() {
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(staffMessagesStreamProvider, (prev, next) {
      final messages = next.value;
      if (messages != null && messages.isNotEmpty) {
        final newMsg = messages.first;
        final myId = ref.read(currentUserProvider)?.id;
        final lastMsgId = prev?.value?.isNotEmpty == true ? prev!.value!.first['id'] : null;
        final isDrawerOpen = _scaffoldKey.currentState?.isEndDrawerOpen ?? false;
        final List readBy = newMsg['read_by'] ?? [];
        if (newMsg['sender_id'] != myId && newMsg['id'] != lastMsgId && !isDrawerOpen && !readBy.contains(myId)) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('💬 ${newMsg['sender_name']}: ${newMsg['message']}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blueGrey[900],
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: ref.read(l10nProvider).viewAction, textColor: Colors.amber, onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
          ));
        }
      }
    });

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeTicketsStreamProvider, (prev, next) {
      if (next.hasValue && prev?.hasValue == true) {
        for (var t in next.value!) {
          if (t['status'] == 'DONE' && !prev!.value!.any((p) => p['id'] == t['id'] && p['status'] == 'DONE')) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔔 ${ref.read(l10nProvider).dishReady}'), backgroundColor: WaiterTheme.readyGreen));
          }
        }
      }
    });

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeRoomServicesStreamProvider, (prev, next) {
      if (next.hasValue && prev?.hasValue == true) {
        for (var s in next.value!) {
          if (!prev!.value!.any((p) => p['id'] == s['id'])) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🧹 ${ref.read(l10nProvider).room} ${s['room_number']} ${ref.read(l10nProvider).roomServiceNotify}'), backgroundColor: WaiterTheme.serviceColor));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final waiterId = widget.waiterId;
    final profileAsync = ref.watch(userProfileProvider);
    if (waiterId == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('${ref.watch(l10nProvider).errorPrefix}: $e'))),
        data: (profile) {
          if (profile != null) { Future.microtask(() { if (mounted) context.go('/waiter/${profile['id']}'); }); return const Scaffold(body: Center(child: CircularProgressIndicator())); }
          return Scaffold(body: Center(child: Text(ref.watch(l10nProvider).pleaseLogin)));
        },
      );
    }

    _setupNotificationListeners();

    final l10n = ref.watch(l10nProvider);
    final waiterOrders = ref.watch(waiterOrdersProvider);
    final roomServicesAsync = ref.watch(activeRoomServicesStreamProvider);
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('${l10n.errorPrefix}: $e'))),
      data: (currentProfile) {
        if (currentProfile == null) return Scaffold(body: Center(child: Text(l10n.authError)));

        final tabTitles = [
          l10n.waiterTitle,
          l10n.historyTitle,
        ];

        final tabIcons = const [
          Icons.room_service_outlined,
          Icons.history_outlined,
        ];

        final selectedTabIcons = const [
          Icons.room_service,
          Icons.history,
        ];

        return Theme(
          data: WaiterTheme.themeData,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isDesktop = constraints.maxWidth >= 1024;

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
                          Navigator.pop(context);
                        },
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 20, 16, 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: WaiterTheme.primaryGreen,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.room_service, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.waiterTitle,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: WaiterTheme.textDarkGreen,
                                        ),
                                      ),
                                      Text(
                                        '${l10n.staffLabel}: ${currentProfile['display_name']}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: WaiterTheme.textMutedGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(indent: 16, endIndent: 16, height: 16),
                          ...List.generate(tabTitles.length, (index) {
                            return NavigationDrawerDestination(
                              icon: Icon(tabIcons[index]),
                              selectedIcon: Icon(selectedTabIcons[index], color: WaiterTheme.primaryGreen),
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
                      const Icon(Icons.room_service, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMobile ? tabTitles[_selectedIndex] : l10n.waiterTitle,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              '${l10n.staffLabel}: ${currentProfile['display_name']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: WaiterTheme.primaryGreen,
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
                              tooltip: l10n.chatGroup,
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
                                    border: Border.all(color: WaiterTheme.primaryGreen, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const LanguageSelector(),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: l10n.logout,
                      onPressed: () {
                        context.go('/login');
                        supabase.auth.signOut();
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
                        backgroundColor: WaiterTheme.surfaceWhite,
                        indicatorColor: WaiterTheme.lightGreenContainer,
                        selectedIconTheme: const IconThemeData(color: WaiterTheme.primaryGreen, size: 26),
                        unselectedIconTheme: const IconThemeData(color: WaiterTheme.textMutedGreen, size: 22),
                        selectedLabelTextStyle: const TextStyle(
                          color: WaiterTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          color: WaiterTheme.textMutedGreen,
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
                      const VerticalDivider(thickness: 1, width: 1, color: WaiterTheme.borderGreen),

                    // ==========================================
                    // KHU VỰC HIỂN THỊ NỘI DUNG CHÍNH
                    // ==========================================
                    Expanded(
                      child: Container(
                        color: WaiterTheme.bgExpressiveGreen,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: KeyedSubtree(
                            key: ValueKey<int>(_selectedIndex),
                            child: _selectedIndex == 0
                                ? _buildTasksView(roomServicesAsync, waiterOrders, menuItems, waiterId!, currentProfile, l10n)
                                : _buildHistoryView(l10n),
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
      },
    );
  }

  // ==========================================
  // VIEW: Trang công việc (Dịch vụ + Đơn hàng)
  // ==========================================
  Widget _buildTasksView(
    AsyncValue<List<Map<String, dynamic>>> roomServicesAsync,
    List<WaiterOrderModel> waiterOrders,
    List<MenuItemModel> menuItems,
    String waiterId,
    Map<String, dynamic> currentProfile,
    AppDictionary l10n,
  ) {
    return roomServicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${l10n.loadDataError}: $err', style: const TextStyle(color: Colors.red))),
      data: (roomServices) {
        if (waiterOrders.isEmpty && roomServices.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.room_service_outlined, size: 80, color: WaiterTheme.borderGreen),
                const SizedBox(height: 16),
                Text(l10n.noRequests, style: const TextStyle(fontSize: 18, color: WaiterTheme.textMutedGreen, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

            int crossAxisCount;
            double childAspectRatio;
            if (isMobile) {
              crossAxisCount = 1;
              childAspectRatio = 1.1;
            } else if (isTablet) {
              crossAxisCount = 2;
              childAspectRatio = 0.85;
            } else {
              crossAxisCount = 3;
              childAspectRatio = 0.82;
            }

            return GridView.builder(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: isMobile ? 12 : 20,
                mainAxisSpacing: isMobile ? 12 : 20,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: roomServices.length + waiterOrders.length,
              itemBuilder: (context, index) {
                if (index < roomServices.length) return _buildServiceCard(roomServices[index], waiterId, l10n);
                return _buildOrderCard(waiterOrders[index - roomServices.length], menuItems, waiterId, l10n);
              },
            );
          },
        );
      },
    );
  }

  // ==========================================
  // VIEW: Lịch sử
  // ==========================================
  Widget _buildHistoryView(AppDictionary l10n) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: WaiterTheme.surfaceWhite,
            child: TabBar(
              labelColor: WaiterTheme.primaryGreen,
              unselectedLabelColor: WaiterTheme.textMutedGreen,
              indicatorColor: WaiterTheme.primaryGreen,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: WaiterTheme.borderGreen,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delivery_dining, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.deliveryTab),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cleaning_services, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.cleaningTab),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHistoryList('orders', 'delivered_at', l10n),
                _buildHistoryList('room_services', 'completed_at', l10n),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD: Dịch vụ phòng (Dọn dẹp / Hỗ trợ)
  // ==========================================
  Widget _buildServiceCard(Map<String, dynamic> service, String currentWaiterId, AppDictionary l10n) {
    final bool isCleaning = service['service_type'] == 'CLEANING';
    final Color themeColor = isCleaning ? WaiterTheme.cleaningColor : WaiterTheme.serviceColor;
    final String? assignedId = service['waiter_id'];
    final bool isIAmDoing = assignedId == currentWaiterId;
    final bool isOtherDoing = assignedId != null && assignedId != currentWaiterId;

    return Card(
      elevation: isIAmDoing ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isIAmDoing ? WaiterTheme.cookingOrange : themeColor.withValues(alpha: 0.3),
          width: isIAmDoing ? 2.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isCleaning ? Icons.cleaning_services : Icons.person_search,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.room.toUpperCase()} ${service['room_number']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isCleaning ? Icons.cleaning_services : Icons.person_search,
                    size: 40,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isCleaning ? l10n.cleaningTask : l10n.supportTask,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: themeColor,
                  ),
                ),
                if (service['notes'] != null && service['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        '${l10n.notes}: ${service['notes']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                icon: Icon(
                  isOtherDoing
                      ? Icons.person
                      : (isIAmDoing ? Icons.check_circle : Icons.back_hand),
                  size: 20,
                ),
                label: Text(
                  isOtherDoing ? l10n.alreadyTaken : (isIAmDoing ? l10n.confirmDone : l10n.takeTask),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isOtherDoing
                      ? WaiterTheme.textMutedGreen
                      : (isIAmDoing ? WaiterTheme.cookingOrange : themeColor),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isOtherDoing
                    ? null
                    : (isIAmDoing
                        ? () => _completeService(service['id'])
                        : () => _receiveService(service['id'], currentWaiterId)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CARD: Đơn hàng cần giao
  // ==========================================
  Widget _buildOrderCard(WaiterOrderModel orderData, List<MenuItemModel> menuItems, String currentWaiterId, AppDictionary l10n) {
    final order = orderData.order;
    final tickets = orderData.tickets;
    final isFullyDone = orderData.isFullyDone;
    final String? assignedId = order['delivery_waiter_id'];
    final bool isIAmDoing = assignedId == currentWaiterId;
    final bool isOtherDoing = assignedId != null && assignedId != currentWaiterId;
    final locale = ref.watch(localeProvider);

    return Card(
      elevation: isFullyDone ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isIAmDoing
              ? WaiterTheme.cookingOrange
              : (isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.borderGreen),
          width: isIAmDoing ? 2.5 : (isFullyDone ? 2 : 0.8),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isFullyDone ? WaiterTheme.readyGreen.withValues(alpha: 0.08) : WaiterTheme.bgExpressiveGreen,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: WaiterTheme.borderGreen.withValues(alpha: 0.5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.textMutedGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${l10n.room.toUpperCase()} ${order['room_number']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.cookingOrange).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.cookingOrange).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFullyDone ? Icons.check_circle : Icons.local_fire_department,
                        size: 14,
                        color: isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.cookingOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFullyDone ? l10n.ready : l10n.cooking.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.cookingOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Notes
          if (order['notes'] != null && order['notes'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: WaiterTheme.deliveryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WaiterTheme.deliveryBlue.withValues(alpha: 0.15)),
                ),
                child: Text(
                  '${locale == "vi" ? "Ghi chú đơn" : "Order Notes"}: ${order['notes']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: WaiterTheme.deliveryBlue,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          // Ticket List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, idx) {
                final t = tickets[idx];
                final menuItem = menuItems.firstWhere(
                  (m) => m.id == t['item_id'],
                  orElse: () => MenuItemModel(id: '', price: 0, nameMap: {'vi': '...'}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false),
                );
                final bool isRemaked = t['status'] == 'REMAKED';
                final double itemTotal = isRemaked ? 0 : (menuItem.price + (t['selected_modifiers'] as List? ?? []).fold(0.0, (sum, m) => sum + (m['price'] ?? 0))) * (t['quantity'] ?? 1);

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: (isRemaked
                          ? WaiterTheme.cookingOrange
                          : (t['status'] == 'DONE' ? WaiterTheme.readyGreen : WaiterTheme.textMutedGreen)
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRemaked ? Icons.replay : (t['status'] == 'DONE' ? Icons.check_circle : Icons.timer),
                      color: isRemaked ? WaiterTheme.cookingOrange : (t['status'] == 'DONE' ? WaiterTheme.readyGreen : WaiterTheme.textMutedGreen),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${t['quantity']}x ${menuItem.getName(locale)}',
                    style: TextStyle(
                      decoration: isRemaked ? TextDecoration.lineThrough : null,
                      color: isRemaked ? WaiterTheme.textMutedGreen : WaiterTheme.textDarkGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: isRemaked
                      ? Text(l10n.remakeLabel, style: const TextStyle(color: WaiterTheme.cookingOrange, fontSize: 11, fontWeight: FontWeight.bold))
                      : null,
                  trailing: isRemaked
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: WaiterTheme.cookingOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(l10n.remakeLabel, style: const TextStyle(color: WaiterTheme.cookingOrange, fontWeight: FontWeight.bold, fontSize: 11)),
                        )
                      : Text(
                          NumberFormat('#,###', 'vi_VN').format(itemTotal),
                          style: const TextStyle(fontWeight: FontWeight.w600, color: WaiterTheme.textMutedGreen),
                        ),
                );
              },
            ),
          ),

          // Total Bill
          Builder(builder: (context) {
            double total = 0;
            for (var t in tickets) {
              if (t['status'] == 'REMAKED') continue; // Không tính tiền món đã nấu lại
              final m = menuItems.firstWhere((mi) => mi.id == t['item_id'], orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false));
              total += (m.price + (t['selected_modifiers'] as List? ?? []).fold(0.0, (sum, mod) => sum + (mod['price'] ?? 0))) * (t['quantity'] ?? 1);
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: WaiterTheme.lightGreenContainer.withValues(alpha: 0.3),
                border: Border(top: BorderSide(color: WaiterTheme.borderGreen.withValues(alpha: 0.5))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${l10n.totalBill}:', style: const TextStyle(fontWeight: FontWeight.bold, color: WaiterTheme.textDarkGreen)),
                  Text(
                    '${NumberFormat('#,###', 'vi_VN').format(total)} VND',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: WaiterTheme.readyGreen),
                  ),
                ],
              ),
            );
          }),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: Icon(
                  isOtherDoing
                      ? Icons.person
                      : (isIAmDoing ? Icons.check_circle : Icons.delivery_dining),
                  size: 20,
                ),
                label: Text(
                  isOtherDoing ? l10n.alreadyTaken : (isIAmDoing ? l10n.confirmDone : l10n.takeTask),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isOtherDoing
                      ? WaiterTheme.textMutedGreen
                      : (isIAmDoing ? WaiterTheme.cookingOrange : (isFullyDone ? WaiterTheme.readyGreen : WaiterTheme.textMutedGreen)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (isFullyDone && !isOtherDoing)
                    ? (isIAmDoing ? () => _markAsDelivered(order['id']) : () => _startDelivery(order['id'], currentWaiterId))
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HISTORY LIST
  // ==========================================
  Widget _buildHistoryList(String table, String timeField, AppDictionary l10n) {
    final String selectQuery = table == 'orders' ? '*, delivery:delivery_waiter_id(display_name)' : '*, waiter:waiter_id(display_name)';
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from(table).select(selectQuery).eq(table == 'orders' ? 'status' : 'status_id', table == 'orders' ? 'DELIVERED' : ServiceStatus.completed).order(timeField, ascending: false).limit(30),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  table == 'orders' ? Icons.delivery_dining_outlined : Icons.cleaning_services_outlined,
                  size: 64,
                  color: WaiterTheme.borderGreen,
                ),
                const SizedBox(height: 12),
                Text(l10n.noHistory, style: const TextStyle(color: WaiterTheme.textMutedGreen, fontSize: 16)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final item = data[idx];
            final name = table == 'orders' ? (item['delivery']?['display_name'] ?? '...') : (item['waiter']?['display_name'] ?? '...');
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (table == 'orders' ? WaiterTheme.readyGreen : WaiterTheme.serviceColor).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  table == 'orders' ? Icons.check_circle : Icons.cleaning_services,
                  color: table == 'orders' ? WaiterTheme.readyGreen : WaiterTheme.serviceColor,
                  size: 22,
                ),
              ),
              title: Text(
                '${l10n.room} ${item['room_number']}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: WaiterTheme.textDarkGreen),
              ),
              subtitle: Text(
                '${l10n.done}: ${_formatDateTime(item[timeField])} | ${l10n.staffLabel}: $name',
                style: const TextStyle(color: WaiterTheme.textMutedGreen, fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }
}
