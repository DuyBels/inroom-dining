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
          .from('item_modifier_groups')
          .select('modifier_groups(*, modifiers(*))')
          .eq('item_id', widget.menuItem['id']);
      
      final List<Map<String, dynamic>> groups = [];
      for (var row in res) {
        if (row['modifier_groups'] != null) {
          groups.add(Map<String, dynamic>.from(row['modifier_groups']));
        }
      }
      
      groups.sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
      
      setState(() => _groups = groups);
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
  Future<void> _showSelectExistingGroupDialog() async {
    final l10n = ref.read(l10nProvider);
    final locale = ref.read(localeProvider);
    
    Set<String> selectedGroupIds = {};
    bool isAdding = false;
    bool isLoadingTemplates = true;
    List<Map<String, dynamic>> availableGroups = [];

    Future<void> loadTemplates(StateSetter setDialogState) async {
      setDialogState(() => isLoadingTemplates = true);
      try {
        final res = await supabase.from('modifier_groups').select('*, modifiers(*)').order('created_at');
        final allGroups = List<Map<String, dynamic>>.from(res);
        final templates = allGroups.where((g) {
          final n = g['name'];
          if (n is Map && n.containsKey('is_template')) {
            return n['is_template'] == true;
          }
          return true; // Legacy groups act as templates
        }).toList();
        
        if (mounted) {
           setDialogState(() {
             availableGroups = templates;
             isLoadingTemplates = false;
           });
        }
      } catch (e) {
        if (mounted) {
           setDialogState(() => isLoadingTemplates = false);
           _showError('Lỗi tải danh sách: $e');
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoadingTemplates && availableGroups.isEmpty) {
            loadTemplates(setDialogState);
          }
          
          return AlertDialog(
            title: const Text('Chọn nhóm tùy chỉnh có sẵn'),
            content: SizedBox(
              width: 550,
              height: 500,
              child: isLoadingTemplates 
                  ? const Center(child: CircularProgressIndicator())
                  : availableGroups.isEmpty
                  ? const Center(child: Text('Không có nhóm mẫu nào.'))
                  : ListView.builder(
                      itemCount: availableGroups.length,
                      itemBuilder: (ctx, i) {
                        final group = availableGroups[i];
                        final groupName = L10nUtils.getL10n(group['name'], locale);
                        final List modifiers = group['modifiers'] ?? [];
                        final modCount = modifiers.length;
                        final isSelected = selectedGroupIds.contains(group['id']);
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Bắt buộc: ${group['min_select'] > 0 ? "Có" : "Không"} - Tối đa: ${group['max_select']} | $modCount tùy chọn'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  tooltip: 'Sửa mẫu này',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showGroupDialog(group: group, isCreatingTemplate: true);
                                  }
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  tooltip: 'Xóa mẫu này khỏi hệ thống',
                                  onPressed: () async {
                                    final confirm = await _showConfirm('Xóa mẫu chung', 'Bạn có chắc chắn muốn xóa vĩnh viễn mẫu chung này khỏi hệ thống? (Các món đang dùng bản sao sẽ không bị ảnh hưởng)');
                                    if (confirm == true) {
                                      try {
                                        await supabase.from('modifiers').delete().eq('group_id', group['id']);
                                        await supabase.from('modifier_groups').delete().eq('id', group['id']);
                                        loadTemplates(setDialogState);
                                      } catch (e) {
                                        _showError('Lỗi xóa mẫu: $e');
                                      }
                                    }
                                  },
                                ),
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedGroupIds.add(group['id']);
                                      } else {
                                        selectedGroupIds.remove(group['id']);
                                      }
                                    });
                                  }
                                ),
                              ],
                            ),
                            children: [
                              const Divider(),
                              ...modifiers.map((m) {
                                final price = num.tryParse(m['price'].toString()) ?? 0;
                                final formattedPrice = NumberFormat('#,###', 'vi_VN').format(price);
                                final String modName = L10nUtils.getL10n(m['name'], locale);
                                
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
                                      IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () {
                                        Navigator.pop(ctx);
                                        _showModifierDialog(group['id'], modifier: m, isTemplateContext: true);
                                      }),
                                      IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () async {
                                        final confirm = await _showConfirm(l10n.deleteOptionTitle, l10n.deleteOptionConfirm);
                                        if (confirm == true) {
                                          try {
                                            await supabase.from('modifiers').delete().eq('id', m['id']);
                                            loadTemplates(setDialogState);
                                          } catch (e) {
                                            _showError('${l10n.errorDeleteOption}: $e');
                                          }
                                        }
                                      }),
                                    ],
                                  ),
                                );
                              }).toList(),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showModifierDialog(group['id'], isTemplateContext: true);
                                  }, 
                                  icon: const Icon(Icons.add_circle_outline), 
                                  label: Text(l10n.addOption)
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showGroupDialog(isCreatingTemplate: true);
              }, 
              child: const Text('Tạo mẫu mới', style: TextStyle(color: Colors.green)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: selectedGroupIds.isEmpty || isAdding ? null : () async {
                setDialogState(() => isAdding = true);
                try {
                  for (final groupId in selectedGroupIds) {
                    final group = availableGroups.firstWhere((g) => g['id'] == groupId);
                    final newGroupData = {
                      'name': {
                        if (group['name'] is Map) ...group['name'],
                        'is_template': false
                      },
                      'min_select': group['min_select'],
                      'max_select': group['max_select']
                    };
                    final newGroup = await supabase.from('modifier_groups').insert(newGroupData).select().single();
                    
                    final modifiers = group['modifiers'] as List<dynamic>? ?? [];
                    if (modifiers.isNotEmpty) {
                      final newModifiersData = modifiers.map((m) => {
                        'group_id': newGroup['id'],
                        'name': m['name'],
                        'price': m['price'],
                        'is_available': m['is_available']
                      }).toList();
                      await supabase.from('modifiers').insert(newModifiersData);
                    }

                    await supabase.from('item_modifier_groups').insert({
                      'item_id': widget.menuItem['id'],
                      'modifier_group_id': newGroup['id'],
                    });
                  }
                  
                  if (ctx.mounted) Navigator.pop(ctx);
                  _fetchData();
                } catch (e) {
                  _showError('Lỗi khi thêm: $e');
                  setDialogState(() => isAdding = false);
                }
              },
              child: isAdding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Thêm (${selectedGroupIds.length})'),
            )
          ],
        );
      },
      ),
    );
  }

  void _showGroupDialog({Map<String, dynamic>? group, bool isCreatingTemplate = false}) {
    final l10n = ref.read(l10nProvider);
    final nameData = group?['name'];
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
    final minController = TextEditingController(text: group?['min_select']?.toString() ?? '0');
    final maxController = TextEditingController(text: group?['max_select']?.toString() ?? '1');

    // Mảng cờ trạng thái dịch cho từng ngôn ngữ
    Map<String, bool> isTranslatingMap = {};
    for (var lang in L10nUtils.supportedLanguages) {
      isTranslatingMap[lang['code']!] = false;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(group == null ? l10n.addGroupTitle : l10n.editGroupTitle),
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
                          decoration: InputDecoration(labelText: '${l10n.groupNameLang} (${lang['name']})'),
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
              TextField(controller: minController, decoration: InputDecoration(labelText: l10n.minSelectLabel), keyboardType: TextInputType.number),
              TextField(controller: maxController, decoration: InputDecoration(labelText: l10n.maxSelectLabel), keyboardType: TextInputType.number),
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
                    'name': { ...nameMap, 'is_template': isCreatingTemplate ? true : false },
                    'min_select': int.tryParse(minController.text.trim()) ?? 0,
                    'max_select': int.tryParse(maxController.text.trim()) ?? 1,
                  };

                  if (group == null) {
                    final insertedGroup = await supabase.from('modifier_groups').insert(data).select().single();
                    if (!isCreatingTemplate) {
                      await supabase.from('item_modifier_groups').insert({
                        'item_id': widget.menuItem['id'],
                        'modifier_group_id': insertedGroup['id'],
                      });
                    }
                  } else {
                    await supabase.from('modifier_groups').update(data).eq('id', group['id']);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  
                  if (isCreatingTemplate) {
                    _showSelectExistingGroupDialog();
                  } else {
                    _fetchData();
                  }
                } catch (e) {
                  _showError('${l10n.errorSaveGroup}: $e');
                } finally {
                  setDialogState(() => _isTranslating = false);
                }
              },
              child: Text(l10n.save),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGroup(String groupId) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await _showConfirm('Gỡ nhóm khỏi món này', 'Bạn có chắc muốn gỡ nhóm tùy chỉnh này khỏi món ăn hiện tại?');
    if (confirmed == true) {
      try {
        await supabase.from('item_modifier_groups').delete().match({
          'item_id': widget.menuItem['id'],
          'modifier_group_id': groupId,
        });
        _fetchData();
      } catch (e) {
        _showError('${l10n.errorDeleteGroup}: $e');
      }
    }
  }

  Future<void> _saveAsTemplate(Map<String, dynamic> group) async {
    final confirmed = await _showConfirm(
      'Lưu làm mẫu chung', 
      'Tạo một bản sao của nhóm này thành Mẫu Chung để dùng nhanh cho các món khác? (Thay đổi trên mẫu chung sẽ không ảnh hưởng món hiện tại)',
      confirmText: 'Xác nhận Thêm',
      confirmColor: Colors.blue,
    );
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    try {
      final newGroupData = {
        'name': {
          if (group['name'] is Map) ...group['name'],
          'is_template': true
        },
        'min_select': group['min_select'],
        'max_select': group['max_select']
      };
      final newGroup = await supabase.from('modifier_groups').insert(newGroupData).select().single();
      
      final modifiers = group['modifiers'] as List<dynamic>? ?? [];
      if (modifiers.isNotEmpty) {
        final newModifiersData = modifiers.map((m) => {
          'group_id': newGroup['id'],
          'name': m['name'],
          'price': m['price'],
          'is_available': m['is_available']
        }).toList();
        await supabase.from('modifiers').insert(newModifiersData);
      }
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thành mẫu chung thành công!'), backgroundColor: Colors.green));
    } catch (e) {
      _showError('Lỗi khi lưu mẫu: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- QUẢN LÝ LỰA CHỌN (MODIFIER) ---
  void _showModifierDialog(String groupId, {Map<String, dynamic>? modifier, bool isTemplateContext = false}) {
    final l10n = ref.read(l10nProvider);
    final nameData = modifier?['name'];
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
    final priceController = TextEditingController(text: modifier?['price']?.toString() ?? '0');

    // Mảng cờ trạng thái dịch cho từng ngôn ngữ
    Map<String, bool> isTranslatingMap = {};
    for (var lang in L10nUtils.supportedLanguages) {
      isTranslatingMap[lang['code']!] = false;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(modifier == null ? l10n.addOptionTitle : l10n.editOptionTitle),
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
                          decoration: InputDecoration(labelText: '${l10n.optionNameLang} (${lang['name']})'),
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
              TextField(controller: priceController, decoration: InputDecoration(labelText: l10n.extraPrice), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            ElevatedButton(onPressed: () async {
              setDialogState(() => _isTranslating = true);
              try {
                await ref.read(geminiServiceProvider).autoTranslateMap(nameControllers);
                if (nameControllers.values.every((c) => c.text.trim().isEmpty)) {
                  setDialogState(() => _isTranslating = false);
                  return;
                }
                
                final Map<String, String> nameMap = {};
                nameControllers.forEach((code, controller) => nameMap[code] = controller.text.trim());
                
                String cleanPrice = priceController.text.trim().replaceAll('.', '').replaceAll(',', '');
                final data = {
                  'group_id': groupId,
                  'name': nameMap,
                  'price': double.tryParse(cleanPrice) ?? 0.0,
                };
                if (modifier == null) {
                  await supabase.from('modifiers').insert(data);
                } else {
                  await supabase.from('modifiers').update(data).eq('id', modifier['id']);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                
                if (isTemplateContext) {
                  _showSelectExistingGroupDialog();
                } else {
                  _fetchData();
                }
              } catch (e) {
                _showError('${l10n.errorSaveOption}: $e');
              } finally {
                setDialogState(() => _isTranslating = false);
              }
            }, child: Text(l10n.save))
          ],
        ),
      ),
    );
  }

  Future<void> _deleteModifier(String modifierId) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await _showConfirm(l10n.deleteOptionTitle, l10n.deleteOptionConfirm);
    if (confirmed == true) {
      try {
        await supabase.from('modifiers').delete().eq('id', modifierId);
        _fetchData();
      } catch (e) {
        _showError('${l10n.errorDeleteOption}: $e');
      }
    }
  }

  Future<bool?> _showConfirm(String title, String body, {String? confirmText, Color confirmColor = Colors.red}) {
    final l10n = ref.read(l10nProvider);
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)), 
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white), 
          onPressed: () => Navigator.pop(ctx, true), 
          child: Text(confirmText ?? l10n.confirmDeleteBtn)
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final String itemName = L10nUtils.getL10n(widget.menuItem['name'], locale);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text('${l10n.customization}: $itemName', overflow: TextOverflow.ellipsis)),
          OutlinedButton.icon(
            onPressed: () => _showSelectExistingGroupDialog(), 
            icon: const Icon(Icons.list), 
            label: const Text('Chọn nhóm có sẵn')
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showGroupDialog(), 
            icon: const Icon(Icons.add), 
            label: Text(l10n.addNewGroup)
          ),
        ],
      ),
      content: SizedBox(
        width: 850, height: 650,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty 
            ? Center(child: Text(l10n.noCustomizations, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (ctx, i) {
                  final group = _groups[i];
                  final List modifiers = group['modifiers'] ?? [];
                  final String groupName = L10nUtils.getL10n(group['name'], locale);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      subtitle: Text('${l10n.requiredLabel}: ${group['min_select'] > 0 ? l10n.requiredYes : l10n.requiredNo} | ${l10n.maxSelect}: ${group['max_select']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.copy, size: 20, color: Colors.blue), tooltip: 'Lưu làm mẫu chung', onPressed: () => _saveAsTemplate(group)),
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
                          final String modName = L10nUtils.getL10n(m['name'], locale);

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
                          child: TextButton.icon(
                            onPressed: () => _showModifierDialog(group['id']), 
                            icon: const Icon(Icons.add_circle_outline), 
                            label: Text(l10n.addOption)
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.done))],
    );
  }
}
