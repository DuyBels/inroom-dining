import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart'; // Chứa stationsStreamProvider

class StationFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? station;

  const StationFormDialog({super.key, this.station});

  @override
  ConsumerState<StationFormDialog> createState() => _StationFormDialogState();
}

class _StationFormDialogState extends ConsumerState<StationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      _nameController.text = widget.station!['name'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveStation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
      };

      if (widget.station == null) {
        // Thêm mới
        await supabase.from('kitchen_stations').insert(data);
      } else {
        // Cập nhật
        await supabase.from('kitchen_stations').update(data).eq('id', widget.station!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(stationsStreamProvider); // Tải lại danh sách
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.station == null ? 'Thêm Trạm Bếp Mới' : 'Sửa Trạm Bếp'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Tên trạm bếp (VD: Bếp Á, Bếp Âu, Quầy Bar)',
                    border: OutlineInputBorder()
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên trạm bếp' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveStation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}