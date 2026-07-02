import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../main.dart'; // Chứa biến supabase global
import '../../providers/admin_provider.dart';

class AccountFormDialog extends ConsumerStatefulWidget {
  // Nếu profile là null -> Chế độ Thêm mới
  // Nếu profile có dữ liệu -> Chế độ Sửa
  final Map<String, dynamic>? profile;

  const AccountFormDialog({super.key, this.profile});

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers cho các trường dữ liệu
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _roomController = TextEditingController();

  String _selectedRole = 'WAITER';
  String? _selectedStationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Nếu là chế độ Sửa (Edit), tự động điền dữ liệu cũ vào form
    if (widget.profile != null) {
      _nameController.text = widget.profile!['display_name'] ?? '';
      _selectedRole = widget.profile!['role'] ?? 'WAITER';
      _roomController.text = widget.profile!['room_number'] ?? '';
      _selectedStationId = widget.profile!['station_id'];
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  // Hàm xử lý khi bấm nút "Lưu"
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.profile == null) {
        // LUỒNG 1: THÊM MỚI (Gọi Edge Function)
        final response = await supabase.functions.invoke(
          'create-user',
          body: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text.trim(),
            'display_name': _nameController.text.trim(),
            'role': _selectedRole,
            'station_id': _selectedRole == 'STATION' ? _selectedStationId : null,
            'room_number': _selectedRole == 'ROOM' ? _roomController.text.trim() : null,
          },
        );

        if (response.status != 200) {
          throw Exception(response.data['error'] ?? 'Lỗi không xác định từ Server');
        }

        // SAU KHI TẠO AUTH THÀNH CÔNG, CẬP NHẬT THÊM EMAIL/PASS VÀO PROFILE ĐỂ ADMIN XEM
        final newUserId = response.data['user_id'];
        if (newUserId != null) {
          await supabase.from('profiles').update({
            'login_email': _emailController.text.trim(),
            'login_password': _passwordController.text.trim(),
          }).eq('id', newUserId);
        }

      } else {
        // LUỒNG 2: CẬP NHẬT
        final data = {
          'display_name': _nameController.text.trim(),
          'role': _selectedRole,
          'station_id': _selectedRole == 'STATION' ? _selectedStationId : null,
          'room_number': _selectedRole == 'ROOM' ? _roomController.text.trim() : null,
        };
        await supabase.from('profiles').update(data).eq('id', widget.profile!['id']);
      }

      // ==========================================
      // ĐÓNG POPUP
      // ==========================================
      if (mounted) {
        Navigator.pop(context); // Đóng cái form nhập liệu lại
        // Không cần invalidate vì profilesStreamProvider tự động cập nhật Realtime
      }

    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is FunctionException) errorMsg = e.details.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $errorMsg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe danh sách trạm bếp từ Riverpod
    final stationsAsync = ref.watch(stationsStreamProvider);

    return AlertDialog(
      title: Text(widget.profile == null ? 'Thêm Tài Khoản Mới' : 'Sửa Tài Khoản'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chỉ hiển thị ô Email và Mật khẩu khi đang ở chế độ THÊM MỚI
                if (widget.profile == null) ...[
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email đăng nhập', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || val.isEmpty || !val.contains('@') ? 'Vui lòng nhập email hợp lệ' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Mật khẩu (Tối thiểu 6 ký tự)', border: OutlineInputBorder()),
                    obscureText: true,
                    validator: (val) => val == null || val.length < 6 ? 'Mật khẩu phải từ 6 ký tự trở lên' : null,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị', border: OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 16),

                // Ô ĐẶT LẠI MẬT KHẨU (Chỉ hiện khi SỬA tài khoản)
                if (widget.profile != null) ...[
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Đổi mật khẩu mới (Để trống nếu không đổi)', 
                      border: OutlineInputBorder(),
                      helperText: 'Nhập mật khẩu mới nếu nhân viên quên.',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                ],

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Phân quyền', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin (Quản trị)')),
                    DropdownMenuItem(value: 'WAITER', child: Text('Waiter (Phục vụ)')),
                    DropdownMenuItem(value: 'STATION', child: Text('Station (Trạm bếp)')),
                    DropdownMenuItem(value: 'ROOM', child: Text('Room (Thiết bị phòng)')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedRole = val!;
                      // Reset các trường liên quan khi đổi role
                      if (_selectedRole != 'STATION') _selectedStationId = null;
                      if (_selectedRole != 'ROOM') _roomController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Thay đổi giao diện động dựa trên Role được chọn
                if (_selectedRole == 'ROOM')
                  TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(labelText: 'Số phòng (VD: 102)', border: OutlineInputBorder()),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập số phòng' : null,
                  ),

                if (_selectedRole == 'STATION')
                  stationsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, st) => Text('Lỗi tải trạm bếp: $e'),
                    data: (stations) => DropdownButtonFormField<String>(
                      value: _selectedStationId,
                      decoration: const InputDecoration(labelText: 'Chọn Trạm Bếp', border: OutlineInputBorder()),
                      items: stations.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text(s['name'])
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedStationId = val),
                      validator: (val) => val == null ? 'Vui lòng chọn trạm' : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy')
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}