import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/models/category_model.dart';
import '../../../../main.dart';

class CategoryVariantManagementDialog extends ConsumerStatefulWidget {
  final CategoryModel category;
  
  const CategoryVariantManagementDialog({super.key, required this.category});

  @override
  ConsumerState<CategoryVariantManagementDialog> createState() => _CategoryVariantManagementDialogState();
}

class _CategoryVariantManagementDialogState extends ConsumerState<CategoryVariantManagementDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _variants = [];
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('category_variants')
          .select()
          .eq('category_id', widget.category.id)
          .order('created_at', ascending: true);
          
      if (mounted) {
        setState(() {
          _variants = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Lỗi tải dữ liệu: $e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showVariantDialog({Map<String, dynamic>? variant}) {
    final l10n = ref.read(l10nProvider);
    final locale = ref.read(localeProvider);
    final nameData = variant?['name'];
    
    final Map<String, TextEditingController> nameControllers = {};
    for (var lang in L10nUtils.supportedLanguages) {
      final code = lang['code']!;
      String text = '';
      if (nameData is Map) {
        text = nameData[code]?.toString() ?? '';
      } else if (code == 'vi') {
        text = nameData?.toString() ?? '';
      }
      nameControllers[code] = TextEditingController(text: text);
    }

    Map<String, bool> isTranslatingMap = {};
    for (var lang in L10nUtils.supportedLanguages) {
      isTranslatingMap[lang['code']!] = false;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(variant == null ? (locale == 'vi' ? 'Thêm nhóm tùy chọn' : 'Add Variant') : (locale == 'vi' ? 'Sửa nhóm tùy chọn' : 'Edit Variant')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...L10nUtils.supportedLanguages.map((lang) {
                final code = lang['code']!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameControllers[code],
                          decoration: InputDecoration(labelText: '${locale == 'vi' ? 'Tên nhóm tùy chọn' : 'Variant Name'} (${lang['name']})'),
                        ),
                      ),
                      if (code != 'vi') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: isTranslatingMap[code] == true ? null : () async {
                            setDialogState(() => isTranslatingMap[code] = true);
                            try {
                              await ref.read(geminiServiceProvider).autoTranslateMap(nameControllers, force: true);
                            } finally {
                              setDialogState(() => isTranslatingMap[code] = false);
                            }
                          },
                          icon: isTranslatingMap[code] == true 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.purple),
                        ),
                      ]
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () async {
                setDialogState(() => _isTranslating = true);
                try {
                  await ref.read(geminiServiceProvider).autoTranslateMap(nameControllers);
                  if (nameControllers.values.every((c) => c.text.trim().isEmpty)) {
                    setDialogState(() => _isTranslating = false);
                    return;
                  }
                  
                  final Map<String, String> nameMap = {};
                  nameControllers.forEach((code, controller) => nameMap[code] = controller.text.trim());

                  final data = {
                    'name': nameMap,
                    'category_id': widget.category.id,
                  };

                  if (variant == null) {
                    await supabase.from('category_variants').insert(data);
                  } else {
                    await supabase.from('category_variants').update(data).eq('id', variant['id']);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  _showError('Lỗi lưu dữ liệu: $e');
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => _isTranslating = false);
                  }
                }
              },
              child: Text(l10n.save),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVariant(String id) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirm),
        content: const Text('Bạn có chắc chắn muốn xoá nhóm tùy chọn này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete, style: const TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await supabase.from('category_variants').delete().eq('id', id);
        _fetchData();
      } catch (e) {
        _showError('Lỗi xoá dữ liệu: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${locale == 'vi' ? 'Quản lý nhóm tùy chọn của' : 'Manage Variants for'} ${widget.category.getName(locale)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(locale == 'vi' ? 'Thêm nhóm tùy chọn' : 'Add Variant'),
                      onPressed: () => _showVariantDialog(),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _variants.isEmpty 
                    ? const Center(child: Text('Chưa có nhóm tùy chọn nào.'))
                    : ListView.separated(
                        itemCount: _variants.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (context, index) {
                          final variant = _variants[index];
                          final nameMap = L10nUtils.decodeField(variant['name']);
                          final displayName = nameMap[locale] ?? nameMap['vi'] ?? 'Không có tên';
                          
                          return ListTile(
                            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showVariantDialog(variant: variant)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteVariant(variant['id'])),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
      ),
    );
  }
}
