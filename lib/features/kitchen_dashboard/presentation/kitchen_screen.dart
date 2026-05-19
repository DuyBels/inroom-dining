import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../providers/kitchen_provider.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  // Timer để cập nhật UI đếm ngược thời gian mỗi phút
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

  // Hàm cập nhật trạng thái món
  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final Map<String, dynamic> updates = {'status': newStatus};
      
      // Nếu là nấu xong, ghi lại mốc thời gian UTC
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

  // Hàm thêm thời gian Delay (+5 phút)
  Future<void> _addDelay(String ticketId, int currentDelay) async {
    await supabase.from('tickets').update({'delay_minutes': currentDelay + 5}).eq('id', ticketId);
  }

  // Hàm hỗ trợ format thời gian
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

  // Hàm hiển thị Lịch sử nấu xong
  void _showHistoryDialog() {
    // Lấy stationId từ provider đã load sẵn
    final myStationId = ref.read(currentStationIdProvider).value;
    if (myStationId == null) return;

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
                .eq('station_id', myStationId) // LỌC ĐÚNG TRẠM ĐANG ĐĂNG NHẬP
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
    // Lắng nghe trạng thái loading của các provider gốc
    final ticketsAsync = ref.watch(activeTicketsStreamProvider);
    final stationAsync = ref.watch(currentStationProvider);

    if (ticketsAsync.isLoading || stationAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final stationData = stationAsync.value;
    final myStationId = stationData?['id'];
    final myStationName = stationData?['name'] ?? 'Không xác định';

    if (myStationId == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.red, title: const Text('LỖI PHÂN QUYỀN')),
        body: const Center(child: Text('Tài khoản này chưa được gán Trạm Bếp.\nHãy liên hệ Admin.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18))),
      );
    }

    // Lấy danh sách Ticket siêu thông minh đã qua thuật toán
    final smartTickets = ref.watch(smartKitchenTicketsProvider);

    // Tách làm 2 cột Kanban
    final pendingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'PENDING').toList();
    final cookingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'COOKING').toList();

    // ==========================================
    // LOGIC THÔNG BÁO KHI CÓ MÓN MỚI (REALTIME)
    // ==========================================
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeTicketsStreamProvider, (previous, next) {
      if (previous != null && previous.hasValue && next.hasValue && myStationId != null) {
        final prevTickets = previous.value!;
        final nextTickets = next.value!;

        for (var newTicket in nextTickets) {
          // Nếu món thuộc trạm này và là món mới hoàn toàn (chưa có trong danh sách cũ)
          if (newTicket['station_id'] == myStationId) {
            final isNew = !prevTickets.any((t) => t['id'] == newTicket['id']);
            if (isNew) {
              // Lấy tên món từ SmartTickets để hiển thị thông báo
              final itemName = smartTickets.firstWhere(
                (element) => element.rawTicket['id'] == newTicket['id'],
                orElse: () => SmartTicket(rawTicket: {}, itemName: 'Món mới', roomNumber: '?', prepTime: 0, delayMinutes: 0, targetStartTime: DateTime.now())
              ).itemName;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.restaurant_menu, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(child: Text('CÓ ĐƠN MỚI: $itemName - Phòng ${newTicket['order_id'].toString().substring(0,4)}...', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  backgroundColor: Colors.blue[900],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                )
              );
            }
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BẾP: $myStationName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Đang dùng: ${supabase.auth.currentUser?.email}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.orange[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Lịch sử nấu',
            onPressed: _showHistoryDialog,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // CỘT 1: DANH SÁCH CHỜ CHẾ BIẾN
          Expanded(
            child: _buildTicketColumn(
              title: 'CHỜ CHẾ BIẾN (${pendingTickets.length})',
              headerColor: Colors.blue[700]!,
              tickets: pendingTickets,
              isCookingColumn: false,
            ),
          ),
          const VerticalDivider(width: 2, thickness: 2, color: Colors.black12),

          // CỘT 2: DANH SÁCH ĐANG NẤU
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
    // Tính toán xem còn bao lâu thì phải nấu
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
            if (ticket.rawTicket['notes'] != null && ticket.rawTicket['notes'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Ghi chú: ${ticket.rawTicket['notes']}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 16)),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // CỤM THÔNG TIN & DELAY
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

                // CỤM NÚT ACTION (CHUYỂN TRẠNG THÁI)
                if (!isCookingColumn)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.local_fire_department),
                    label: const Text('BẮT ĐẦU NẤU', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => _updateTicketStatus(ticket.rawTicket['id'], 'COOKING'),
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('NẤU XONG', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
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
