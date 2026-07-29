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
                    'name': nameMap,
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
    final confirmed = await _showConfirm(l10n.deleteGroupTitle, l10n.deleteGroupConfirm);
    if (confirmed == true) {
      try {
        await supabase.from('modifier_groups').delete().eq('id', groupId);
        _fetchData();
      } catch (e) {
        _showError('${l10n.errorDeleteGroup}: $e');
      }
    }
  }

  // --- QUẢN LÝ LỰA CHỌN (MODIFIER) ---
  void _showModifierDialog(String groupId, {Map<String, dynamic>? modifier}) {
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
                _fetchData();
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

  Future<bool?> _showConfirm(String title, String body) {
    final l10n = ref.read(l10nProvider);
    return showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title), content: Text(body),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmDeleteBtn))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final String itemName = L10nUtils.getL10n(widget.menuItem['name'], locale);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text('${l10n.customization}: $itemName', overflow: TextOverflow.ellipsis)),
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
