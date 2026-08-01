import 'dart:async';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/theme/kitchen_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/staff_chat/presentation/widgets/staff_chat_drawer.dart';
import '../../staff_chat/providers/chat_provider.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../main.dart';
import '../providers/kitchen_provider.dart';
import '../../admin_panel/providers/admin_provider.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  final String? stationId;
  const KitchenScreen({super.key, this.stationId});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _timer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedColumnIndex = 0; // 0: Pending, 1: Cooking (cho mobile NavigationRail)

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    final l10n = ref.read(l10nProvider);
    try {
      final Map<String, dynamic> updates = {'status': newStatus};
      if (newStatus == 'DONE') updates['finished_at'] = DateTime.now().toUtc().toIso8601String();
      await supabase.from('tickets').update(updates).eq('id', ticketId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.updateError}: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _remakeTicket(SmartTicket ticket) async {
    final l10n = ref.read(l10nProvider);
    final reasons = [
      l10n.remakeReasonBurnt,
      l10n.remakeReasonDamaged,
      l10n.remakeReasonCustomerChanged,
      l10n.remakeReasonOther,
    ];

    final selectedReason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KitchenTheme.cookingOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.replay, color: KitchenTheme.cookingOrange),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(l10n.remakeTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remakeSelectReason, style: const TextStyle(fontSize: 16, color: KitchenTheme.textMutedOrange)),
            const SizedBox(height: 16),
            ...reasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    side: const BorderSide(color: KitchenTheme.cookingOrange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(ctx, reason),
                  child: Text(reason, style: const TextStyle(fontSize: 15, color: KitchenTheme.cookingOrange, fontWeight: FontWeight.w600)),
                ),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        ],
      ),
    );

    if (selectedReason == null) return;

    try {
      final raw = ticket.rawTicket;
      // 1. Đánh dấu ticket cũ là REMAKED và lưu lý do
      await supabase.from('tickets').update({
        'status': 'REMAKED',
        'remake_reason': selectedReason,
        'finished_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', raw['id']);

      // 2. Tạo ĐƠN HÀNG MỚI (bill riêng) cho món nấu lại
      final orderRes = await supabase.from('orders').insert({
        'room_number': ticket.roomNumber,
        'status': 'PENDING',
      }).select('id').single();
      final newOrderId = orderRes['id'];

      // 3. Tạo ticket mới trong đơn hàng mới
      final now = DateTime.now().toUtc().toIso8601String();
      await supabase.from('tickets').insert({
        'order_id': newOrderId,
        'item_id': raw['item_id'],
        'station_id': raw['station_id'],
        'quantity': raw['quantity'],
        'unit_price': 0, // Món làm lại không tính thêm tiền
        'notes': raw['notes'],
        'selected_modifiers': raw['selected_modifiers'],
        'status': 'PENDING',
        'is_remake': true,
        'remake_of': raw['id'],
        'created_at': now,
        'updated_at': now,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(l10n.remakeSuccess),
            ]),
            backgroundColor: KitchenTheme.doneGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.updateError}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')} ${dt.day}/${dt.month}";
  }

  void _showHistoryDialog(String myStationId) {
    final l10n = ref.read(l10nProvider);
    final locale = ref.read(localeProvider);
    
    // Khởi tạo Future ngay tại đây để nó không bị khởi tạo lại khi rebuild
    final historyFuture = supabase
        .from('tickets')
        .select('*, menu_items(name), orders(room_number)')
        .eq('station_id', myStationId)
        .eq('status', 'DONE')
        .order('finished_at', ascending: false)
        .limit(30);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KitchenTheme.doneGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history, color: KitchenTheme.doneGreen),
          ),
          const SizedBox(width: 12),
          Text(l10n.historyTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: 600, height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return Center(child: Text(l10n.noOptions, style: const TextStyle(color: KitchenTheme.textMutedOrange)));
              return ListView.separated(
                itemCount: data.length, separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final t = data[idx];
                  final String itemName = L10nUtils.getL10n(t['menu_items']?['name'], locale);
                  return ListTile(
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: KitchenTheme.doneGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check, color: KitchenTheme.doneGreen, size: 20),
                    ),
                    title: Text('${t['quantity']}x $itemName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${l10n.room}: ${t['orders']?['room_number'] ?? "?"}', style: const TextStyle(color: KitchenTheme.textMutedOrange)),
                    trailing: Text(_formatDateTime(t['finished_at']), style: const TextStyle(color: KitchenTheme.textMutedOrange, fontSize: 12)),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationId = widget.stationId;
    final l10n = ref.watch(l10nProvider);
    if (stationId == null) {
      final defaultIdAsync = ref.watch(defaultStationIdProvider);
      return defaultIdAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('${l10n.errorPrefix}: $e'))),
        data: (id) {
          if (id != null) { Future.microtask(() { if (mounted) context.go('/kitchen/$id'); }); return const Scaffold(body: Center(child: CircularProgressIndicator())); }
          return Scaffold(body: Center(child: Text(l10n.stationNotAssigned)));
        },
      );
    }

    final smartTickets = ref.watch(smartKitchenTicketsProvider(stationId));
    final profileAsync = ref.watch(userProfileProvider);
    final stationDetailAsync = ref.watch(stationDetailProvider(stationId));

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('${l10n.errorPrefix}: $e'))),
      data: (profile) {
        if (profile == null || (profile['role'] != 'STATION' && profile['role'] != 'ADMIN')) {
          Future.microtask(() { if (mounted) context.go('/'); });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return stationDetailAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, s) => Scaffold(body: Center(child: Text('${l10n.loadStationError}: $e'))),
          data: (station) {
            if (station == null) return Scaffold(body: Center(child: Text(l10n.stationNotExist)));

            final locale = ref.watch(localeProvider);
            final String myStationName = L10nUtils.getL10n(station['name'], locale);
            
            final pendingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'PENDING').toList();
            final cookingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'COOKING').toList();

            return Theme(
              data: KitchenTheme.themeData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

                  final tabTitles = [
                    '${l10n.pendingColumn} (${pendingTickets.length})',
                    '${l10n.cookingColumn} (${cookingTickets.length})',
                  ];

                  final tabIcons = const [
                    Icons.pending_actions_outlined,
                    Icons.local_fire_department_outlined,
                  ];

                  final selectedTabIcons = const [
                    Icons.pending_actions,
                    Icons.local_fire_department,
                  ];

                  return Scaffold(
                    key: _scaffoldKey,
                    endDrawer: const StaffChatDrawer(),
                    // Drawer cho màn hình điện thoại (Mobile)
                    drawer: isMobile
                        ? NavigationDrawer(
                            selectedIndex: _selectedColumnIndex,
                            onDestinationSelected: (int index) {
                              setState(() {
                                _selectedColumnIndex = index;
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
                                        color: KitchenTheme.primaryOrange,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.soup_kitchen, color: Colors.white, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            myStationName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: KitchenTheme.textDarkOrange,
                                            ),
                                          ),
                                          Text(
                                            l10n.kitchenTitle,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: KitchenTheme.textMutedOrange,
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
                                  selectedIcon: Icon(selectedTabIcons[index], color: KitchenTheme.primaryOrange),
                                  label: Text(tabTitles[index]),
                                );
                              }),
                              const Divider(indent: 16, endIndent: 16, height: 24),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: ListTile(
                                  leading: const Icon(Icons.history, color: KitchenTheme.doneGreen),
                                  title: Text(l10n.historyTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showHistoryDialog(stationId);
                                  },
                                ),
                              ),
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
                          const Icon(Icons.soup_kitchen, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMobile ? tabTitles[_selectedColumnIndex] : myStationName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                if (!isMobile)
                                  Text(
                                    l10n.kitchenTitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: KitchenTheme.primaryOrange,
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
                                        border: Border.all(color: KitchenTheme.primaryOrange, width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const LanguageSelector(),
                        const SizedBox(width: 4),
                        if (!isMobile)
                          IconButton(
                            icon: const Icon(Icons.history, color: Colors.white),
                            tooltip: l10n.historyTitle,
                            onPressed: () => _showHistoryDialog(stationId),
                          ),
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
                        // SIDEBAR: NavigationRail cho Tablet
                        // ==========================================
                        if (isTablet)
                          NavigationRail(
                            selectedIndex: _selectedColumnIndex,
                            onDestinationSelected: (int index) {
                              setState(() {
                                _selectedColumnIndex = index;
                              });
                            },
                            labelType: NavigationRailLabelType.selected,
                            backgroundColor: KitchenTheme.surfaceWhite,
                            indicatorColor: KitchenTheme.lightOrangeContainer,
                            selectedIconTheme: const IconThemeData(color: KitchenTheme.primaryOrange, size: 26),
                            unselectedIconTheme: const IconThemeData(color: KitchenTheme.textMutedOrange, size: 22),
                            selectedLabelTextStyle: const TextStyle(
                              color: KitchenTheme.primaryOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            unselectedLabelTextStyle: const TextStyle(
                              color: KitchenTheme.textMutedOrange,
                              fontSize: 11,
                            ),
                            destinations: List.generate(tabTitles.length, (index) {
                              return NavigationRailDestination(
                                icon: Icon(tabIcons[index]),
                                selectedIcon: Icon(selectedTabIcons[index]),
                                label: Text(tabTitles[index]),
                              );
                            }),
                            trailing: Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.history, color: KitchenTheme.textMutedOrange),
                                    tooltip: l10n.historyTitle,
                                    onPressed: () => _showHistoryDialog(stationId),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),

                        // Đường kẻ dọc
                        if (isTablet)
                          const VerticalDivider(thickness: 1, width: 1, color: KitchenTheme.borderOrange),

                        // ==========================================
                        // KHU VỰC HIỂN THỊ NỘI DUNG CHÍNH
                        // ==========================================
                        Expanded(
                          child: Container(
                            color: KitchenTheme.bgExpressiveOrange,
                            child: isMobile || isTablet
                                // Mobile & Tablet: Hiển thị 1 cột tại một thời điểm
                                ? AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: KeyedSubtree(
                                      key: ValueKey<int>(_selectedColumnIndex),
                                      child: _selectedColumnIndex == 0
                                          ? _buildTicketList(
                                              title: tabTitles[0],
                                              headerColor: KitchenTheme.pendingBlue,
                                              tickets: pendingTickets,
                                              isCookingColumn: false,
                                              showHeader: !isMobile,
                                            )
                                          : _buildTicketList(
                                              title: tabTitles[1],
                                              headerColor: KitchenTheme.cookingOrange,
                                              tickets: cookingTickets,
                                              isCookingColumn: true,
                                              showHeader: !isMobile,
                                            ),
                                    ),
                                  )
                                // Desktop: Hiển thị 2 cột song song
                                : Row(
                                    children: [
                                      Expanded(
                                        child: _buildTicketList(
                                          title: tabTitles[0],
                                          headerColor: KitchenTheme.pendingBlue,
                                          tickets: pendingTickets,
                                          isCookingColumn: false,
                                          showHeader: true,
                                        ),
                                      ),
                                      const VerticalDivider(width: 1, thickness: 1, color: KitchenTheme.borderOrange),
                                      Expanded(
                                        child: _buildTicketList(
                                          title: tabTitles[1],
                                          headerColor: KitchenTheme.cookingOrange,
                                          tickets: cookingTickets,
                                          isCookingColumn: true,
                                          showHeader: true,
                                        ),
                                      ),
                                    ],
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
      },
    );
  }

  Widget _buildTicketList({
    required String title,
    required Color headerColor,
    required List<SmartTicket> tickets,
    required bool isCookingColumn,
    required bool showHeader,
  }) {
    final l10n = ref.watch(l10nProvider);
    return Column(
      children: [
        // Header Bar M3 Expressive
        if (showHeader)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
            ),
            child: Row(
              children: [
                Icon(
                  isCookingColumn ? Icons.local_fire_department : Icons.pending_actions,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Ticket List
        Expanded(
          child: tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCookingColumn ? Icons.local_fire_department_outlined : Icons.pending_actions_outlined,
                        size: 64,
                        color: KitchenTheme.borderOrange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.empty,
                        style: const TextStyle(
                          color: KitchenTheme.textMutedOrange,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildTicketCard(tickets[index], isCookingColumn),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(SmartTicket ticket, bool isCookingColumn) {
    final now = DateTime.now();
    final l10n = ref.watch(l10nProvider);
    String timingMessage; Color timingColor; IconData timingIcon;

    if (isCookingColumn) {
      final updatedAt = DateTime.parse(ticket.rawTicket['updated_at']).toLocal();
      final remaining = updatedAt.add(Duration(minutes: ticket.prepTime)).difference(now);
      if (remaining.isNegative) {
        timingMessage = '${l10n.overtime}: ${remaining.inMinutes.abs()}p';
        timingColor = KitchenTheme.overtimeRed;
        timingIcon = Icons.warning_amber;
      } else {
        timingMessage = '${l10n.finishIn}: ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
        timingColor = KitchenTheme.cookingOrange;
        timingIcon = Icons.timer;
      }
    } else {
      if (ticket.isOrderStarted || ticket.isInitialAnchor) {
        final diff = ticket.targetStartTime.difference(now);
        if (diff.isNegative) {
          timingMessage = l10n.cookNow;
          timingColor = KitchenTheme.overtimeRed;
          timingIcon = Icons.priority_high;
        } else {
          timingMessage = '${l10n.startIn}: ${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
          timingColor = KitchenTheme.doneGreen;
          timingIcon = Icons.schedule;
        }
      } else {
        timingMessage = l10n.waitPrimary;
        timingColor = KitchenTheme.textMutedOrange;
        timingIcon = Icons.hourglass_top;
      }
    }

    final bool isUrgent = !isCookingColumn && ticket.targetStartTime.isBefore(now);

    return Card(
      elevation: isUrgent ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isUrgent ? KitchenTheme.overtimeRed : KitchenTheme.borderOrange,
          width: isUrgent ? 2 : 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Room Badge + Timing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: KitchenTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${l10n.room.toUpperCase()} ${ticket.roomNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: timingColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: timingColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(timingIcon, color: timingColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        timingMessage,
                        style: TextStyle(
                          color: timingColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Item Name + Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${ticket.rawTicket['quantity']}x ${ticket.itemName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: KitchenTheme.textDarkOrange,
                    ),
                  ),
                ),
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(ticket.basePrice)} VND',
                  style: const TextStyle(
                    fontSize: 15,
                    color: KitchenTheme.textMutedOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Modifiers
            if (ticket.rawTicket['selected_modifiers'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (ticket.rawTicket['selected_modifiers'] as List).map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '↳ ${L10nUtils.getL10n(m['group_name'], ref.watch(localeProvider))}: ${L10nUtils.getL10n(m['modifier_name'], ref.watch(localeProvider))}',
                        style: const TextStyle(color: KitchenTheme.pendingBlue, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Order Notes
            if (ticket.orderNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KitchenTheme.pendingBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KitchenTheme.pendingBlue.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    '${ref.watch(localeProvider) == "vi" ? "Ghi chú đơn" : "Order Notes"}: ${ticket.orderNotes}',
                    style: const TextStyle(color: KitchenTheme.pendingBlue, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

            // Item Notes
            if (ticket.rawTicket['notes']?.toString().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: KitchenTheme.overtimeRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KitchenTheme.overtimeRed.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    '${l10n.notePrefix}: ${ticket.rawTicket['notes']}',
                    style: const TextStyle(color: KitchenTheme.overtimeRed, fontStyle: FontStyle.italic),
                  ),
                ),
              ),

            // Total
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${l10n.totalItem}: ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: KitchenTheme.textMutedOrange)),
                  Text(
                    '${NumberFormat('#,###', 'vi_VN').format((ticket.basePrice + (ticket.rawTicket['selected_modifiers'] as List? ?? []).fold(0.0, (sum, m) => sum + (num.tryParse(m['price'].toString())?.toDouble() ?? 0.0))) * ticket.rawTicket['quantity'])} VND',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: KitchenTheme.doneGreen),
                  ),
                ],
              ),
            ),

            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: KitchenTheme.borderOrange),
            ),

            // Footer: Prep Time + Remake Badge + Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: KitchenTheme.textMutedOrange, size: 20),
                    const SizedBox(width: 4),
                    Text(' ${ticket.prepTime}p', style: const TextStyle(color: KitchenTheme.textMutedOrange, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    if (ticket.isRemake)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: KitchenTheme.cookingOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: KitchenTheme.cookingOrange.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          l10n.remakeLabel,
                          style: const TextStyle(
                            color: KitchenTheme.cookingOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (!isCookingColumn)
                  FilledButton.icon(
                    icon: const Icon(Icons.local_fire_department, size: 20),
                    label: Text(l10n.startCooking),
                    style: FilledButton.styleFrom(
                      backgroundColor: KitchenTheme.cookingOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final allTickets = ref.read(activeTicketsStreamProvider).value ?? [];
                      final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
                      final bool isEarly = now.isBefore(ticket.targetStartTime);
                      bool hasUnfinishedPrimary = allTickets.any((t) => t['order_id'] == ticket.rawTicket['order_id'] && t['id'] != ticket.rawTicket['id'] && t['status'] != 'DONE' && (menuItems.firstWhere((m) => m.id == t['item_id'], orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false)).prepTime > ticket.prepTime));
                      if (isEarly || hasUnfinishedPrimary) {
                        bool? proceed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(l10n.warningTitle), content: Text('${isEarly ? l10n.notCookingTime : l10n.primaryNotDone}\n${l10n.continueQuestion}'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.stillCook))]));
                        if (proceed != true) return;
                      }
                      _updateTicketStatus(ticket.rawTicket['id'], 'COOKING');
                    },
                  )
                else
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.replay, size: 20),
                        label: Text(l10n.remakeBtn),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KitchenTheme.cookingOrange,
                          side: const BorderSide(color: KitchenTheme.cookingOrange, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _remakeTicket(ticket),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: Text(l10n.cookingDone),
                        style: FilledButton.styleFrom(
                          backgroundColor: KitchenTheme.doneGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _updateTicketStatus(ticket.rawTicket['id'], 'DONE'),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
