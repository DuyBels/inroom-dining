import 'dart:async';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
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
          const Icon(Icons.replay, color: Colors.deepOrange),
          const SizedBox(width: 10),
          Text(l10n.remakeTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remakeSelectReason, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ...reasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    side: const BorderSide(color: Colors.deepOrange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx, reason),
                  child: Text(reason, style: const TextStyle(fontSize: 16, color: Colors.deepOrange)),
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
        'delay_minutes': 0,
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
            backgroundColor: Colors.green,
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
        title: Row(children: [const Icon(Icons.history, color: Colors.green), const SizedBox(width: 10), Text(l10n.historyTitle, style: const TextStyle(fontWeight: FontWeight.bold))]),
        content: SizedBox(
          width: 600, height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return Center(child: Text(l10n.noOptions));
              return ListView.separated(
                itemCount: data.length, separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final t = data[idx];
                  final String itemName = L10nUtils.getL10n(t['menu_items']?['name'], locale);
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                    title: Text('${t['quantity']}x $itemName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${l10n.room}: ${t['orders']?['room_number'] ?? "?"}'),
                    trailing: Text(_formatDateTime(t['finished_at']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
          if (id != null) { Future.microtask(() => context.go('/kitchen/$id')); return const Scaffold(body: Center(child: CircularProgressIndicator())); }
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
          Future.microtask(() => context.go('/'));
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

            return Scaffold(
              key: _scaffoldKey,
              endDrawer: const StaffChatDrawer(),
              backgroundColor: Colors.grey[200],
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(myStationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.orange[800],
                actions: [
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
                                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.orange[800]!, width: 1.5)),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const LanguageSelector(),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: () => _showHistoryDialog(stationId)),
                  IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
                    ref.invalidate(userProfileProvider);
                    await supabase.auth.signOut();
                    if (context.mounted) context.go('/login');
                  }),
                  const SizedBox(width: 16),
                ],
              ),
              body: Row(
                children: [
                  Expanded(child: _buildTicketColumn(title: '${l10n.pendingColumn} (${pendingTickets.length})', headerColor: Colors.blue[700]!, tickets: pendingTickets, isCookingColumn: false)),
                  const VerticalDivider(width: 2, thickness: 2, color: Colors.black12),
                  Expanded(child: _buildTicketColumn(title: '${l10n.cookingColumn} (${cookingTickets.length})', headerColor: Colors.orange[700]!, tickets: cookingTickets, isCookingColumn: true)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTicketColumn({required String title, required Color headerColor, required List<SmartTicket> tickets, required bool isCookingColumn}) {
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(16), color: headerColor, child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      Expanded(child: tickets.isEmpty ? Center(child: Text(ref.watch(l10nProvider).empty, style: TextStyle(color: Colors.grey[500], fontSize: 20))) : ListView.builder(padding: const EdgeInsets.all(12), itemCount: tickets.length, itemBuilder: (context, index) => _buildTicketCard(tickets[index], isCookingColumn))),
    ]);
  }

  Widget _buildTicketCard(SmartTicket ticket, bool isCookingColumn) {
    final now = DateTime.now();
    final l10n = ref.watch(l10nProvider);
    String timingMessage; Color timingColor;

    if (isCookingColumn) {
      final updatedAt = DateTime.parse(ticket.rawTicket['updated_at']).toLocal();
      final remaining = updatedAt.add(Duration(minutes: ticket.prepTime)).difference(now);
      if (remaining.isNegative) { timingMessage = '${l10n.overtime}: ${remaining.inMinutes.abs()}p'; timingColor = Colors.red; }
      else { timingMessage = '${l10n.finishIn}: ${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}'; timingColor = Colors.orange; }
    } else {
      if (ticket.isOrderStarted || ticket.isInitialAnchor) {
        final diff = ticket.targetStartTime.difference(now);
        if (diff.isNegative) { timingMessage = l10n.cookNow; timingColor = Colors.red; }
        else { timingMessage = '${l10n.startIn}: ${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}'; timingColor = Colors.green; }
      } else { timingMessage = l10n.waitPrimary; timingColor = Colors.blueGrey; }
    }

    return Card(
      elevation: 4, margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: (!isCookingColumn && ticket.targetStartTime.isBefore(now)) ? Colors.red : Colors.transparent, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.orange[900], borderRadius: BorderRadius.circular(8)), child: Text('${l10n.room.toUpperCase()} ${ticket.roomNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
              Text(timingMessage, style: TextStyle(color: timingColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${ticket.rawTicket['quantity']}x ${ticket.itemName}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
              Text('${NumberFormat('#,###', 'vi_VN').format(ticket.basePrice)} VND', style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
            ]),
            if (ticket.rawTicket['selected_modifiers'] != null) Column(crossAxisAlignment: CrossAxisAlignment.start, children: (ticket.rawTicket['selected_modifiers'] as List).map((m) => Text('↳ ${L10nUtils.getL10n(m['group_name'], ref.watch(localeProvider))}: ${L10nUtils.getL10n(m['modifier_name'], ref.watch(localeProvider))}', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))).toList()),
            if (ticket.orderNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${ref.watch(localeProvider) == "vi" ? "Ghi chú đơn" : "Order Notes"}: ${ticket.orderNotes}', style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
              ),
            if (ticket.rawTicket['notes']?.toString().isNotEmpty ?? false) Text('${l10n.notePrefix}: ${ticket.rawTicket['notes']}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
            Padding(padding: const EdgeInsets.only(top: 12), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('${l10n.totalItem}: ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), Text('${NumberFormat('#,###', 'vi_VN').format((ticket.basePrice + (ticket.rawTicket['selected_modifiers'] as List? ?? []).fold(0.0, (sum, m) => sum + (num.tryParse(m['price'].toString())?.toDouble() ?? 0.0))) * ticket.rawTicket['quantity'])} VND', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))])),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [const Icon(Icons.timer, color: Colors.grey, size: 20), Text(' ${ticket.prepTime}p'), const SizedBox(width: 16), if (ticket.isRemake) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(6)), child: Text(l10n.remakeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)))]),
              if (!isCookingColumn) ElevatedButton.icon(icon: const Icon(Icons.local_fire_department), label: Text(l10n.startCooking), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), onPressed: () async {
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
              }) else Row(children: [
                ElevatedButton.icon(icon: const Icon(Icons.replay), label: Text(l10n.remakeBtn), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white), onPressed: () => _remakeTicket(ticket)),
                const SizedBox(width: 8),
                ElevatedButton.icon(icon: const Icon(Icons.check_circle), label: Text(l10n.cookingDone), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () => _updateTicketStatus(ticket.rawTicket['id'], 'DONE')),
              ]),
            ])
          ],
        ),
      ),
    );
  }
}
