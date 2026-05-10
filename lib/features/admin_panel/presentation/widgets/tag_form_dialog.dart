import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../providers/tag_provider.dart';

class TagFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? tag;

  const TagFormDialog({super.key, this.tag});

  @override
  ConsumerState<TagFormDialog> createState() => _TagFormDialogState();
}

class _TagFormDialogState extends ConsumerState<TagFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Mặc định chọn ALLERGY
  String _selectedType = 'ALLERGY';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      _nameController.text = widget.tag!['name'] ?? '';
      _selectedType = widget.tag!['tag_type'] ?? 'ALLERGY';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveTag() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'tag_type': _selectedType,
      };

      if (widget.tag == null) {
        // Thêm mới
        await supabase.from('tags').insert(data);
      } else {
        // Cập nhật
        await supabase.from('tags').update(data).eq('id', widget.tag!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        ref.invalidate(tagsStreamProvider); // Bắt buộc làm mới bảng dữ liệu
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
      title: Text(widget.tag == null ? 'Thêm Thẻ Mới' : 'Sửa Thông Tin Thẻ'),
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
                    labelText: 'Tên thẻ (VD: Có đậu phộng, Trời mưa)',
                    border: OutlineInputBorder()
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên thẻ' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Phân loại', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ALLERGY', child: Text('Dị ứng (ALLERGY)')),
                  DropdownMenuItem(value: 'WEATHER', child: Text('Thời tiết (WEATHER)')),
                  DropdownMenuItem(value: 'TIME', child: Text('Buổi trong ngày (TIME)')),
                  DropdownMenuItem(value: 'TASTE', child: Text('Khẩu vị / Loại bếp (TASTE)')),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy')
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTag,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Lưu'),
        ),
      ],
    );
  }
}