import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../providers/kitchen_provider.dart';
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
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
                title: Text('BẾP: $myStationName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                backgroundColor: Colors.orange[800],
                actions: [
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
                      title: 'CHỜ CHẾ BIẾN (${pendingTickets.length})',
                      headerColor: Colors.blue[700]!,
                      tickets: pendingTickets,
                      isCookingColumn: false,
                    ),
                  ),
                  const VerticalDivider(width: 2, thickness: 2, color: Colors.black12),
                  Expanded(
                    child: _buildTicketColumn(
                      title: 'ĐANG NẤU (${cookingTickets.length})',
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
    final diffMinutes = ticket.targetStartTime.difference(now).inMinutes;

    String timingMessage;
    Color timingColor;

    if (isCookingColumn) {
      timingMessage = 'Đang trên bếp...';
      timingColor = Colors.orange;
    } else {
      if (diffMinutes <= 0) {
        timingMessage = 'NẤU NGAY! (Đồng bộ)';
        timingColor = Colors.red;
      } else {
        timingMessage = 'Khoan nấu. Đợi $diffMinutes phút nữa...';
        timingColor = Colors.green;
      }
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: diffMinutes <= 0 && !isCookingColumn ? Colors.red : Colors.transparent, width: 2),
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
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                  child: Text('Phòng ${ticket.roomNumber}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Text(timingMessage, style: TextStyle(color: timingColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Text('${ticket.rawTicket['quantity']}x ${ticket.itemName}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            
            // Hiển thị Topping
            if (ticket.rawTicket['selected_toppings'] != null && (ticket.rawTicket['selected_toppings'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Topping: ${(ticket.rawTicket['selected_toppings'] as List).map((e) => '${e['quantity'] ?? 1}x ${e['name']}').join(', ')}',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),

            if (ticket.rawTicket['notes'] != null && ticket.rawTicket['notes'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Ghi chú: ${ticket.rawTicket['notes']}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 16)),
              ),
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
                    label: const Text('BẮT ĐẦU NẤU'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    onPressed: () => _updateTicketStatus(ticket.rawTicket['id'], 'COOKING'),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('NẤU XONG'),
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
