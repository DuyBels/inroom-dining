import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../main.dart';

class ModifierManagementDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> menuItem;
  const ModifierManagementDialog({super.key, required this.menuItem});

  @override
  ConsumerState<ModifierManagementDialog> createState() => _ModifierManagementDialogState();
}

class _ModifierManagementDialogState extends ConsumerState<ModifierManagementDialog> {
  bool _isLoading = false;
  bool _isTranslating = false;
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('modifier_groups')
          .select('*, modifiers(*)')
          .eq('item_id', widget.menuItem['id'])
          .order('created_at', ascending: true);
      
      setState(() => _groups = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // --- QUẢN LÝ NHÓM (GROUP) ---
  void _showGroupDialog({Map<String, dynamic>? group}) {
    final nameData = group?['name'];
    final nameViController = TextEditingController();
    final nameEnController = TextEditingController();

    if (nameData is Map) {
      nameViController.text = nameData['vi']?.toString() ?? '';
      nameEnController.text = nameData['en']?.toString() ?? '';
    } else {
      nameViController.text = nameData?.toString() ?? '';
    }

    final minController = TextEditingController(text: group?['min_select']?.toString() ?? '0');
    final maxController = TextEditingController(text: group?['max_select']?.toString() ?? '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(group == null ? 'Thêm Nhóm Tùy Chọn' : 'Sửa Nhóm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: nameViController, decoration: const InputDecoration(labelText: 'Tên nhóm (VI)'))),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isTranslating ? null : () async {
                      if (nameViController.text.isEmpty) return;
                      setDialogState(() => _isTranslating = true);
                      try {
                        final result = await ref.read(geminiServiceProvider).translate(nameViController.text);
                        nameEnController.text = result;
                      } finally {
                        setDialogState(() => _isTranslating = false);
                      }
                    },
                    icon: _isTranslating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.purple),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: nameEnController, decoration: const InputDecoration(labelText: 'Tên nhóm (EN)'))),
                ],
              ),
              TextField(controller: minController, decoration: const InputDecoration(labelText: 'Chọn tối thiểu (1: Bắt buộc, 0: Tùy chọn)'), keyboardType: TextInputType.number),
              TextField(controller: maxController, decoration: const InputDecoration(labelText: 'Chọn tối đa'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (nameViController.text.isEmpty) return;
                try {
                  final data = {
                    'name': {
                      'vi': nameViController.text.trim(),
                      'en': nameEnController.text.trim(),
                    },
                    'min_select': int.tryParse(minController.text.trim()) ?? 0,
                    'max_select': int.tryParse(maxController.text.trim()) ?? 1,
                    'item_id': widget.menuItem['id'],
                  };

                  if (group == null) {
                    await supabase.from('modifier_groups').insert(data);
                  } else {
                    await supabase.from('modifier_groups').update(data).eq('id', group['id']);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  _showError('Lỗi khi lưu nhóm: $e');
                }
              },
              child: const Text('Lưu'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGroup(String groupId) async {
    final confirmed = await _showConfirm('Xóa Nhóm?', 'Mọi lựa chọn bên trong nhóm này cũng sẽ bị xóa. Bạn chắc chắn chứ?');
    if (confirmed == true) {
      try {
        await supabase.from('modifier_groups').delete().eq('id', groupId);
        _fetchData();
      } catch (e) {
        _showError('Lỗi khi xóa nhóm: $e');
      }
    }
  }

  // --- QUẢN LÝ LỰA CHỌN (MODIFIER) ---
  void _showModifierDialog(String groupId, {Map<String, dynamic>? modifier}) {
    final nameData = modifier?['name'];
    final nameViController = TextEditingController();
    final nameEnController = TextEditingController();

    if (nameData is Map) {
      nameViController.text = nameData['vi']?.toString() ?? '';
      nameEnController.text = nameData['en']?.toString() ?? '';
    } else {
      nameViController.text = nameData?.toString() ?? '';
    }

    final priceController = TextEditingController(text: modifier?['price']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(modifier == null ? 'Thêm Lựa Chọn' : 'Sửa Lựa Chọn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: TextField(controller: nameViController, decoration: const InputDecoration(labelText: 'Tên (VI)'))),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isTranslating ? null : () async {
                      if (nameViController.text.isEmpty) return;
                      setDialogState(() => _isTranslating = true);
                      try {
                        final result = await ref.read(geminiServiceProvider).translate(nameViController.text);
                        nameEnController.text = result;
                      } finally {
                        setDialogState(() => _isTranslating = false);
                      }
                    },
                    icon: _isTranslating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.purple),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: nameEnController, decoration: const InputDecoration(labelText: 'Tên (EN)'))),
                ],
              ),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Giá cộng thêm'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(onPressed: () async {
              try {
                String cleanPrice = priceController.text.trim().replaceAll('.', '').replaceAll(',', '');
                final data = {
                  'group_id': groupId,
                  'name': {
                    'vi': nameViController.text.trim(),
                    'en': nameEnController.text.trim(),
                  },
                  'price': double.tryParse(cleanPrice) ?? 0.0,
                };
                if (modifier == null) {
                  await supabase.from('modifiers').insert(data);
                } else {
                  await supabase.from('modifiers').update(data).eq('id', modifier['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchData();
              } catch (e) {
                _showError('Lỗi khi lưu lựa chọn: $e');
              }
            }, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteModifier(String modifierId) async {
    final confirmed = await _showConfirm('Xóa Lựa Chọn?', 'Bạn muốn xóa vĩnh viễn lựa chọn này?');
    if (confirmed == true) {
      try {
        await supabase.from('modifiers').delete().eq('id', modifierId);
        _fetchData();
      } catch (e) {
        _showError('Lỗi khi xóa lựa chọn: $e');
      }
    }
  }

  Future<bool?> _showConfirm(String title, String body) {
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(body),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận Xóa'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final String itemName = L10nUtils.getL10n(widget.menuItem['name'], 'vi');
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('Tùy chỉnh: $itemName', overflow: TextOverflow.ellipsis)),
          ElevatedButton.icon(onPressed: () => _showGroupDialog(), icon: const Icon(Icons.add), label: const Text('Thêm nhóm mới')),
        ],
      ),
      content: SizedBox(
        width: 850, height: 650,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty 
            ? const Center(child: Text('Chưa có tùy chỉnh nào cho món này.\nNhấn "Thêm nhóm mới" để bắt đầu.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (ctx, i) {
                  final group = _groups[i];
                  final List modifiers = group['modifiers'] ?? [];
                  final String groupName = L10nUtils.getL10n(group['name'], 'vi');

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      subtitle: Text('Bắt buộc: ${group['min_select'] > 0 ? 'Có' : 'Không'} | Chọn tối đa: ${group['max_select']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showGroupDialog(group: group)),
                          IconButton(icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red), onPressed: () => _deleteGroup(group['id'])),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: [
                        const Divider(),
                        ...modifiers.map((m) {
                          final price = num.tryParse(m['price'].toString()) ?? 0;
                          final formattedPrice = NumberFormat('#,###', 'vi_VN').format(price);
                          final String modName = L10nUtils.getL10n(m['name'], 'vi');

                          return ListTile(
                            dense: true,
                            title: Text(modName),
                            subtitle: price > 0 
                                ? Text('+$formattedPrice VND', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                : null,
                            leading: const Icon(Icons.subdirectory_arrow_right, size: 16),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _showModifierDialog(group['id'], modifier: m)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _deleteModifier(m['id'])),
                              ],
                            ),
                          );
                        }).toList(),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextButton.icon(onPressed: () => _showModifierDialog(group['id']), icon: const Icon(Icons.add_circle_outline), label: const Text('Thêm lựa chọn')),
                        )
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Xong'))],
    );
  }
}
