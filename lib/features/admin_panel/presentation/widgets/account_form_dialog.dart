import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
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
    final l10n = ref.read(l10nProvider);
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
          throw Exception(response.data['error'] ?? l10n.serverError);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $errorMsg'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe danh sách trạm bếp từ Riverpod
    final stationsAsync = ref.watch(stationsStreamProvider);
    final l10n = ref.watch(l10nProvider);

    return AlertDialog(
      title: Text(widget.profile == null ? l10n.addAccountTitle : l10n.editAccountTitle),
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
                    decoration: InputDecoration(labelText: l10n.loginEmail, border: const OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || val.isEmpty || !val.contains('@') ? l10n.validEmail : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: l10n.passwordMinLength, border: const OutlineInputBorder()),
                    obscureText: true,
                    validator: (val) => val == null || val.length < 6 ? l10n.validPassword : null,
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.displayName, border: const OutlineInputBorder()),
                  validator: (val) => val == null || val.trim().isEmpty ? l10n.validName : null,
                ),
                const SizedBox(height: 16),

                // Ô ĐẶT LẠI MẬT KHẨU (Chỉ hiện khi SỬA tài khoản)
                if (widget.profile != null) ...[
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.changePasswordLabel, 
                      border: const OutlineInputBorder(),
                      helperText: l10n.changePasswordHelper,
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                ],

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(labelText: l10n.roleLabel, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'ADMIN', child: Text(l10n.adminRole)),
                    DropdownMenuItem(value: 'WAITER', child: Text(l10n.waiterRole)),
                    DropdownMenuItem(value: 'STATION', child: Text(l10n.stationRole)),
                    DropdownMenuItem(value: 'ROOM', child: Text(l10n.roomDeviceLabel)),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedRole = val!;
                      if (_selectedRole != 'STATION') _selectedStationId = null;
                      if (_selectedRole != 'ROOM') _roomController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (_selectedRole == 'ROOM')
                  TextFormField(
                    controller: _roomController,
                    decoration: InputDecoration(labelText: l10n.roomNumberInput, border: const OutlineInputBorder()),
                    validator: (val) => val == null || val.trim().isEmpty ? l10n.validRoom : null,
                  ),

                if (_selectedRole == 'STATION')
                  stationsAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, st) => Text('${l10n.loadStationError}: $e'),
                    data: (stations) => DropdownButtonFormField<String>(
                      value: stations.any((s) => s['id'].toString() == _selectedStationId) ? _selectedStationId : null,
                      decoration: InputDecoration(labelText: l10n.selectStationLabel, border: const OutlineInputBorder()),
                      items: stations.map((s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text(L10nUtils.getL10n(s['name'], ref.watch(localeProvider)))
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedStationId = val),
                      validator: (val) => val == null ? l10n.validStation : null,
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
            child: Text(l10n.cancel)
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}