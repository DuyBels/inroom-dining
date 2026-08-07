import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/utils/category_icon_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/admin_theme.dart';
import '../../../../main.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? category;

  const CategoryFormDialog({super.key, this.category});

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _nameControllers = {};
  String? _selectedIconName;
  bool _isLoading = false;
  final Map<String, bool> _isTranslating = {};

  String _getNameInLang(String code, Map<String, dynamic> nameMap) {
    return nameMap[code]?.toString() ?? (code == 'vi' ? (nameMap['vi']?.toString() ?? '') : '');
  }

  @override
  void initState() {
    super.initState();
    final nameMap = widget.category != null ? L10nUtils.decodeField(widget.category!['name']) : <String, dynamic>{};

    for (var lang in L10nUtils.supportedLanguages) {
      final code = lang['code']!;
      _nameControllers[code] = TextEditingController(text: _getNameInLang(code, nameMap));
      _isTranslating[code] = false;
    }

    if (widget.category != null) {
      _selectedIconName = widget.category!['icon_name']?.toString() ?? widget.category!['icon']?.toString();
    }

    _nameControllers['vi']?.addListener(_autoUpdateSuggestedIcon);
  }

  void _autoUpdateSuggestedIcon() {
    if (_selectedIconName == null || _selectedIconName!.isEmpty) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameControllers['vi']?.removeListener(_autoUpdateSuggestedIcon);
    for (var c in _nameControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _translateWithAI(String targetLang) async {
    final viName = _nameControllers['vi']?.text.trim() ?? '';
    if (viName.isEmpty) return;

    final l10n = ref.read(l10nProvider);
    setState(() => _isTranslating[targetLang] = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslateMap(_nameControllers, force: true);
      
      if (_selectedIconName == null) {
        setState(() {
          _selectedIconName = CategoryIconUtils.autoSuggestIconName(viName);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating[targetLang] = false);
    }
  }

  Future<void> _saveCategory() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslateMap(_nameControllers);

      if (!_formKey.currentState!.validate()) {
        setState(() => _isLoading = false);
        return;
      }

      final viName = _nameControllers['vi']?.text.trim() ?? '';
      final activeIconName = _selectedIconName ?? CategoryIconUtils.autoSuggestIconName(viName);

      final Map<String, String> nameData = {};
      
      _nameControllers.forEach((key, controller) {
        nameData[key] = controller.text.trim();
      });

      final data = {
        'name': nameData,
        'icon_name': activeIconName,
      };

      if (widget.category == null) {
        await supabase.from('categories').insert(data);
      } else {
        await supabase.from('categories').update(data).eq('id', widget.category!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final viName = _nameControllers['vi']?.text.trim() ?? '';
    final activeIconName = _selectedIconName ?? CategoryIconUtils.autoSuggestIconName(viName);


    return AlertDialog(
      title: Text(widget.category == null ? l10n.addCategory : l10n.editCategory, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkBlue)),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...L10nUtils.supportedLanguages.map((lang) {
                  final code = lang['code']!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameControllers[code],
                                decoration: InputDecoration(labelText: '${l10n.categoryNameLang} (${lang['name']})', border: const OutlineInputBorder()),
                                validator: code == 'vi' ? (val) => val == null || val.trim().isEmpty ? l10n.validName : null : null,
                              ),
                            ],
                          ),
                        ),
                        if (code != 'vi') ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: IconButton(
                              onPressed: _isTranslating[code] == true ? null : () => _translateWithAI(code),
                              icon: _isTranslating[code] == true
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.auto_awesome, color: Colors.purple),
                              tooltip: l10n.aiTranslateTooltip,
                            ),
                          ),
                        ]
                      ],
                    ),
                  );
                }),

              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveCategory,
          style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryBlue, foregroundColor: Colors.white),
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(l10n.save),
        ),
      ],
    );
  }
}