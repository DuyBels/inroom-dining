import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';

class AdminHistoryView extends ConsumerStatefulWidget {
  const AdminHistoryView({super.key});

  @override
  ConsumerState<AdminHistoryView> createState() => _AdminHistoryViewState();
}

class _AdminHistoryViewState extends ConsumerState<AdminHistoryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch Sử Hoạt Động Toàn Hệ Thống',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[800],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue[800],
              tabs: const [
                Tab(icon: Icon(Icons.shopping_cart), text: 'Đơn hàng (Phòng)'),
                Tab(icon: Icon(Icons.restaurant), text: 'Bếp (Món ăn)'),
                Tab(icon: Icon(Icons.person_pin_circle), text: 'Nhân viên (Dịch vụ)'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderHistory(),
                _buildKitchenHistory(),
                _buildStaffActivityHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. LỊCH SỬ GỌI MÓN (CỦA PHÒNG)
  Widget _buildOrderHistory() {
    return _buildFutureList(
      future: supabase.from('orders').select('*, profiles:delivery_waiter_id(display_name)').order('created_at', ascending: false).limit(50),
      itemBuilder: (order) {
        final statusColor = _getOrderStatusColor(order['status']);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.1), child: Icon(Icons.room_service, color: statusColor)),
            title: Text('Phòng ${order['room_number']} - ${order['status']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thời gian: ${_formatDateTime(order['created_at'])}'),
                if (order['profiles'] != null) Text('Người giao: ${order['profiles']['display_name']}'),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showOrderDetails(order['id'], order['room_number']),
          ),
        );
      },
    );
  }

  // 2. LỊCH SỬ BẾP HOÀN THÀNH MÓN
  Widget _buildKitchenHistory() {
    return _buildFutureList(
      future: supabase.from('tickets').select('*, menu_items(name), kitchen_stations(name)').eq('status', 'DONE').order('finished_at', ascending: false).limit(50),
      itemBuilder: (ticket) {
        final itemName = L10nUtils.getL10n(ticket['menu_items']?['name'], 'vi');
        final stationName = L10nUtils.getL10n(ticket['kitchen_stations']?['name'], 'vi');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
            title: Text('${ticket['quantity']}x $itemName', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Trạm: $stationName | Hoàn thành: ${_formatDateTime(ticket['finished_at'])}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
              child: Text('Done', style: TextStyle(fontSize: 10, color: Colors.grey[800], fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  // 3. LỊCH SỬ HOẠT ĐỘNG CỦA NHÂN VIÊN (DỊCH VỤ PHÒNG)
  Widget _buildStaffActivityHistory() {
    return _buildFutureList(
      future: supabase.from('room_services').select('*, waiter:waiter_id(display_name)').order('created_at', ascending: false).limit(50),
      itemBuilder: (service) {
        final bool isCleaning = service['service_type'] == 'CLEANING';
        final name = service['waiter']?['display_name'] ?? 'Chưa rõ';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(isCleaning ? Icons.cleaning_services : Icons.support_agent, color: isCleaning ? Colors.blue : Colors.purple),
            title: Text('${isCleaning ? 'Dọn dẹp' : 'Hỗ trợ'} - Phòng ${service['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Người thực hiện: $name'),
                Text('Yêu cầu lúc: ${_formatDateTime(service['created_at'])}'),
                if (service['completed_at'] != null) Text('Hoàn tất lúc: ${_formatDateTime(service['completed_at'])}', style: const TextStyle(color: Colors.green)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper hiển thị chi tiết món ăn trong một đơn hàng
  void _showOrderDetails(String orderId, String room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chi tiết Đơn hàng - Phòng $room'),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from('tickets').select('*, menu_items(name)').eq('order_id', orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final tickets = snapshot.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: tickets.length,
                itemBuilder: (c, i) {
                  final t = tickets[i];
                  final name = L10nUtils.getL10n(t['menu_items']?['name'], 'vi');
                  return ListTile(
                    leading: Text('${t['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                    title: Text(name),
                    subtitle: Text('Trạng thái: ${t['status']}'),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
      ),
    );
  }

  // Helper Widget cho danh sách Future
  Widget _buildFutureList({required Future<List<Map<String, dynamic>>> future, required Widget Function(Map<String, dynamic>) itemBuilder}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
        final data = snapshot.data ?? [];
        if (data.isEmpty) return const Center(child: Text('Không có dữ liệu lịch sử.'));
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) => itemBuilder(data[index]),
        );
      },
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.orange;
      case 'PROCESSING': return Colors.blue;
      case 'READY_FOR_DELIVERY': return Colors.green;
      case 'DELIVERED': return Colors.grey;
      default: return Colors.blueGrey;
    }
  }
}
