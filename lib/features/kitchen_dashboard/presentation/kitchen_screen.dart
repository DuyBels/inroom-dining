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
    await supabase.from('tickets').update({'status': newStatus}).eq('id', ticketId);
  }

  // Hàm thêm thời gian Delay (+5 phút)
  Future<void> _addDelay(String ticketId, int currentDelay) async {
    await supabase.from('tickets').update({'delay_minutes': currentDelay + 5}).eq('id', ticketId);
  }

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách Ticket siêu thông minh đã qua thuật toán
    final smartTickets = ref.watch(smartKitchenTicketsProvider);

    // Tách làm 2 cột Kanban
    final pendingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'PENDING').toList();
    final cookingTickets = smartTickets.where((t) => t.rawTicket['status'] == 'COOKING').toList();

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('BẢNG ĐIỀU KHIỂN TRẠM BẾP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.orange[800],
        actions: [
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