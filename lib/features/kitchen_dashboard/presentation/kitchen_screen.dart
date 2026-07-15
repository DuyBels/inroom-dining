import 'dart:async';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../providers/kitchen_provider.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  final String? stationId; // Nhận từ URL

  const KitchenScreen({super.key, this.stationId});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Thay đổi từ 30s sang 1s để đếm ngược mượt mà
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
    try {
      final Map<String, dynamic> updates = {'status': newStatus};
      if (newStatus == 'DONE') {
        updates['finished_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await supabase.from('tickets').update(updates).eq('id', ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addDelay(String ticketId, int currentDelay) async {
    await supabase.from('tickets').update({'delay_minutes': currentDelay + 5}).eq('id', ticketId);
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return "$h:$m:$s $d/$mo/$y";
  }

  void _showHistoryDialog(String myStationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.history, color: Colors.green),
            const SizedBox(width: 10),
            const Text('LỊCH SỬ RIÊNG CỦA TRẠM', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('tickets')
                .select('*, menu_items(name), orders(room_number)')
                .eq('station_id', myStationId)
                .eq('status', 'DONE')
                .order('finished_at', ascending: false)
                .limit(30),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return const Center(child: Text('Chưa có lịch sử nấu tại trạm này.'));

              return ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final t = data[idx];
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                    title: Text('${t['quantity']}x ${t['menu_items']['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Phòng: ${t['orders']['room_number']}'),
                    trailing: Text(_formatDateTime(t['finished_at']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ĐÓNG'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationId = widget.stationId;

    // Nếu không có stationId trên URL, thử lấy mặc định từ profile
    if (stationId == null) {
      final defaultIdAsync = ref.watch(defaultStationIdProvider);
      return defaultIdAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (id) {
          if (id != null) {
             // Redirect sang URL có ID để tách biệt tab
             Future.microtask(() => context.go('/kitchen/$id'));
             return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(body: Center(child: Text('Tài khoản chưa được gán trạm.')));
        },
      );
    }

    final stationDetailAsync = ref.watch(stationDetailProvider(stationId));
    final smartTickets = ref.watch(smartKitchenTicketsProvider(stationId));
    final profileAsync = ref.watch(userProfileProvider);
    final l10n = ref.watch(l10nProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Lỗi tải Profile: $e'))),
      data: (profile) {
        if (profile == null || (profile['role'] != 'STATION' && profile['role'] != 'ADMIN')) {
          Future.microtask(() => context.go('/'));
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final chefName = profile['display_name'] ?? 'Đầu bếp';

        return stationDetailAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, s) => Scaffold(body: Center(child: Text('Lỗi tải trạm: $e'))),
          data: (station) {
            if (station == null) return const Scaffold(body: Center(child: Text('Trạm không tồn tại.')));

            final myStationName = station['name'];

            final pendingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'PENDING').toList();
            final cookingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'COOKING').toList();

            return Scaffold(
              backgroundColor: Colors.grey[200],
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text('${l10n.kitchenTitle}: $myStationName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                backgroundColor: Colors.orange[800],
                actions: [
                  // Nút Đổi Ngôn Ngữ
                  TextButton(
                    onPressed: () => ref.read(localeProvider.notifier).toggleLanguage(),
                    child: Text(
                      ref.watch(localeProvider) == 'vi' ? 'EN 🇺🇸' : 'VI 🇻🇳',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white),
                    onPressed: () => _showHistoryDialog(stationId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      ref.invalidate(userProfileProvider);
                      await supabase.auth.signOut();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: Row(
                children: [
                  Expanded(
                    child: _buildTicketColumn(
                      title: '${l10n.pendingColumn} (${pendingTickets.length})',
                      headerColor: Colors.blue[700]!,
                      tickets: pendingTickets,
                      isCookingColumn: false,
                    ),
                  ),
                  const VerticalDivider(width: 2, thickness: 2, color: Colors.black12),
                  Expanded(
                    child: _buildTicketColumn(
                      title: '${l10n.cookingColumn} (${cookingTickets.length})',
                      headerColor: Colors.orange[700]!,
                      tickets: cookingTickets,
                      isCookingColumn: true,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTicketColumn({required String title, required Color headerColor, required List<SmartTicket> tickets, required bool isCookingColumn}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: headerColor,
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ),
        Expanded(
          child: tickets.isEmpty
              ? Center(child: Text('Trống', style: TextStyle(color: Colors.grey[500], fontSize: 20)))
              : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              return _buildTicketCard(tickets[index], isCookingColumn);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(SmartTicket ticket, bool isCookingColumn) {
    final now = DateTime.now();
    final l10n = ref.watch(l10nProvider);
    
    // --- LOGIC ĐẾM NGƯỢC ---
    String timingMessage;
    Color timingColor;

    if (isCookingColumn) {
      // Khi đang nấu: Đếm ngược dựa trên thời gian bắt đầu thực tế + thời gian chuẩn bị
      final updatedAt = DateTime.parse(ticket.rawTicket['updated_at']).toLocal();
      final targetDoneTime = updatedAt.add(Duration(minutes: ticket.prepTime));
      final remaining = targetDoneTime.difference(now);

      if (remaining.isNegative) {
        timingMessage = 'QUÁ GIỜ: ${remaining.inMinutes.abs()}p';
        timingColor = Colors.red;
      } else {
        final m = remaining.inMinutes.toString().padLeft(2, '0');
        final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
        timingMessage = 'Xong sau: $m:$s';
        timingColor = Colors.orange;
      }
    } else {
      // Khi đang chờ:
      if (ticket.isOrderStarted || ticket.isInitialAnchor) {
        // Đã có món bắt đầu HOẶC đây chính là món lâu nhất cần nấu trước
        final diff = ticket.targetStartTime.difference(now);
        if (diff.isNegative) {
          timingMessage = 'NẤU NGAY! (Đồng bộ)';
          timingColor = Colors.red;
        } else {
          final m = diff.inMinutes.toString().padLeft(2, '0');
          final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
          timingMessage = 'Bắt đầu sau: $m:$s';
          timingColor = Colors.green;
        }
      } else {
        // Đây là món phụ, chưa đến lúc nấu và món chính cũng chưa bắt đầu
        timingMessage = 'Chờ bắt đầu món chính...';
        timingColor = Colors.blueGrey;
      }
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (!isCookingColumn && ticket.targetStartTime.difference(now).isNegative) 
              ? Colors.red 
              : Colors.transparent, 
          width: 2
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.orange[900], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text('${l10n.room.toUpperCase()} ${ticket.roomNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ),
                Text(timingMessage, style: TextStyle(color: timingColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Builder(builder: (context) {
              final locale = ref.watch(localeProvider);
              final String displayName = L10nUtils.getL10n(ticket.rawTicket['menu_items']?['name'] ?? ticket.itemName, locale);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('${ticket.rawTicket['quantity']}x $displayName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  Text(
                    '${NumberFormat('#,###', 'vi_VN').format(ticket.basePrice)} VND',
                    style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }),
            
            // Hiển thị Modifier Groups (Toppings)
            if (ticket.rawTicket['selected_modifiers'] != null && (ticket.rawTicket['selected_modifiers'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (ticket.rawTicket['selected_modifiers'] as List).map((m) {
                    final double modPrice = num.tryParse(m['price'].toString())?.toDouble() ?? 0.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '↳ ${m['group_name']}: ${m['modifier_name']}',
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (modPrice > 0)
                          Text('+${NumberFormat('#,###', 'vi_VN').format(modPrice)}', style: const TextStyle(color: Colors.blueAccent, fontSize: 14)),
                      ],
                    );
                  }).toList(),
                ),
              ),

            if (ticket.rawTicket['notes'] != null && ticket.rawTicket['notes'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Ghi chú: ${ticket.rawTicket['notes']}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 16)),
              ),

            // TỔNG TIỀN CỦA MÓN
            Builder(builder: (context) {
              final double modifiersTotal = (ticket.rawTicket['selected_modifiers'] as List? ?? [])
                  .fold(0.0, (sum, m) => sum + (num.tryParse(m['price'].toString())?.toDouble() ?? 0.0));
              final double itemTotal = (ticket.basePrice + modifiersTotal) * (ticket.rawTicket['quantity'] ?? 1);
              return Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${l10n.totalItem}: ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(
                      '${NumberFormat('#,###', 'vi_VN').format(itemTotal)} VND',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              );
            }),

            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.grey, size: 20),
                    const SizedBox(width: 4),
                    Text('T.Gian: ${ticket.prepTime}p', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.more_time, size: 18),
                      label: Text(ticket.delayMinutes > 0 ? '+${ticket.delayMinutes}p Delay' : 'Delay'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => _addDelay(ticket.rawTicket['id'], ticket.delayMinutes),
                    ),
                  ],
                ),
                if (!isCookingColumn)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.local_fire_department),
                    label: Text(l10n.startCooking),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    onPressed: () async {
                      final now = DateTime.now();
                      final bool isEarly = now.isBefore(ticket.targetStartTime);

                      // Lấy danh sách toàn bộ món và menu để kiểm tra món chính
                      final allTickets = ref.read(activeTicketsStreamProvider).value ?? [];
                      final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
                      final orderId = ticket.rawTicket['order_id'];

                      bool hasUnfinishedPrimary = false;
                      for (var t in allTickets) {
                        // Tìm món trong cùng đơn, không phải chính nó và chưa xong
                        if (t['order_id'] == orderId && t['id'] != ticket.rawTicket['id'] && t['status'] != 'DONE') {
                          final item = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {});
                          final pTime = item['prep_time_minutes'] ?? 0;
                          // Nếu món đó nấu lâu hơn món hiện tại -> Món đó là món chính/món nấu trước
                          if (pTime > ticket.prepTime) {
                            hasUnfinishedPrimary = true;
                            break;
                          }
                        }
                      }

                      if (isEarly || hasUnfinishedPrimary) {
                        String message = isEarly 
                            ? "Chưa đến thời gian nấu món này để đảm bảo đồng bộ với các món khác."
                            : "Món chính (món nấu trước) của đơn hàng này vẫn chưa nấu xong.";

                        bool? proceed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            title: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Cảnh báo xác nhận'),
                              ],
                            ),
                            content: Text('$message\n\nBạn có chắc chắn muốn bắt đầu nấu ngay bây giờ không?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('BỎ QUA', style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('VẪN NẤU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (proceed != true) return;
                      }

                      _updateTicketStatus(ticket.rawTicket['id'], 'COOKING');
                    },
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: Text(l10n.cookingDone),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: () => _updateTicketStatus(ticket.rawTicket['id'], 'DONE'),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }
}
