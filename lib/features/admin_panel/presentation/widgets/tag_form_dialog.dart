import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
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
  final _nameViController = TextEditingController();
  final _nameEnController = TextEditingController();

  // Mặc định chọn ALLERGY
  String _selectedType = 'ALLERGY';
  bool _isLoading = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    if (widget.tag != null) {
      final nameMap = L10nUtils.decodeField(widget.tag!['name']);
      _nameViController.text = nameMap['vi']?.toString() ?? '';
      _nameEnController.text = nameMap['en']?.toString() ?? '';
      _selectedType = widget.tag!['tag_type'] ?? 'ALLERGY';
    }
  }

  @override
  void dispose() {
    _nameViController.dispose();
    _nameEnController.dispose();
    super.dispose();
  }

  Future<void> _translateWithAI() async {
    if (_nameViController.text.isEmpty) return;
    setState(() => _isTranslating = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      final result = await gemini.translate(_nameViController.text);
      _nameEnController.text = result;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi dịch: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _saveTag() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': {
          'vi': _nameViController.text.trim(),
          'en': _nameEnController.text.trim(),
        },
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
        // Tự động cập nhật qua Stream, không cần invalidate
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
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameViController,
                      decoration: const InputDecoration(labelText: 'Tên thẻ (VI)', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isTranslating ? null : _translateWithAI,
                    icon: _isTranslating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.purple),
                    tooltip: 'AI Dịch sang tiếng Anh',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _nameEnController,
                      decoration: const InputDecoration(labelText: 'Tên thẻ (EN)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
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