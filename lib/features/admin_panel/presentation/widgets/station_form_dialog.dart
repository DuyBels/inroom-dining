import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart'; 

class StationFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? station;

  const StationFormDialog({super.key, this.station});

  @override
  ConsumerState<StationFormDialog> createState() => _StationFormDialogState();
}

class _StationFormDialogState extends ConsumerState<StationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameViController = TextEditingController();
  final _nameEnController = TextEditingController();
  bool _isLoading = false;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    if (widget.station != null) {
      final nameMap = L10nUtils.decodeField(widget.station!['name']);
      _nameViController.text = nameMap['vi']?.toString() ?? '';
      _nameEnController.text = nameMap['en']?.toString() ?? '';
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

  Future<void> _saveStation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': {
          'vi': _nameViController.text.trim(),
          'en': _nameEnController.text.trim(),
        },
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
        // Đã xóa ref.invalidate vì stationsStreamProvider là StreamProvider, 
        // nó sẽ tự động cập nhật khi DB thay đổi (Realtime).
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
                      decoration: const InputDecoration(labelText: 'Tên trạm (VI)', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tên trạm' : null,
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
                      decoration: const InputDecoration(labelText: 'Tên trạm (EN)', border: OutlineInputBorder()),
                    ),
                  ),
                ],
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