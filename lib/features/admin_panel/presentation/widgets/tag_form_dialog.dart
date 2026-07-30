import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
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
  final Map<String, TextEditingController> _nameControllers = {};

  // Mặc định chọn ALLERGY
  String _selectedType = 'ALLERGY';
  bool _isLoading = false;
  final Map<String, bool> _isTranslating = {};

  String _getNameInLang(String code, Map<String, dynamic> nameMap) {
    return nameMap[code]?.toString() ?? (code == 'vi' ? (nameMap['vi']?.toString() ?? '') : '');
  }

  @override
  void initState() {
    super.initState();
    final nameMap = widget.tag != null ? L10nUtils.decodeField(widget.tag!['name']) : <String, dynamic>{};
    
    for (var lang in L10nUtils.supportedLanguages) {
      final code = lang['code']!;
      _nameControllers[code] = TextEditingController(text: _getNameInLang(code, nameMap));
      _isTranslating[code] = false;
    }

    if (widget.tag != null) {
      _selectedType = widget.tag!['tag_type'] ?? 'ALLERGY';
    }
  }

  @override
  void dispose() {
    for (var c in _nameControllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _translateWithAI(String targetLang) async {
    final viName = _nameControllers['vi']?.text.trim() ?? '';
    if (viName.isEmpty) return;
    
    setState(() => _isTranslating[targetLang] = true);
    final l10n = ref.read(l10nProvider);
    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslateMap(_nameControllers, force: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating[targetLang] = false);
    }
  }

  Future<void> _saveTag() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslateMap(_nameControllers);

      if (!_formKey.currentState!.validate()) {
        setState(() => _isLoading = false);
        return;
      }

      final Map<String, String> nameData = {};
      _nameControllers.forEach((key, controller) {
        nameData[key] = controller.text.trim();
      });

      final data = {
        'name': nameData,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return AlertDialog(
      title: Text(widget.tag == null ? l10n.addTag : l10n.editTag),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...L10nUtils.supportedLanguages.map((lang) {
                final code = lang['code']!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameControllers[code],
                          decoration: InputDecoration(labelText: '${l10n.tagNameLang} (${lang['name']})', border: const OutlineInputBorder()),
                          validator: code == 'vi' ? (val) => val == null || val.trim().isEmpty ? l10n.validName : null : null,
                        ),
                      ),
                      if (code != 'vi') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isTranslating[code] == true ? null : () => _translateWithAI(code),
                          icon: _isTranslating[code] == true 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, color: Colors.purple),
                          tooltip: l10n.aiTranslateTooltip,
                        ),
                      ]
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(labelText: l10n.tagTypeLabel, border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'ALLERGY', child: Text(l10n.allergyType)),
                  DropdownMenuItem(value: 'WEATHER', child: Text(l10n.weatherType)),
                  DropdownMenuItem(value: 'TIME', child: Text(l10n.timeType)),
                  DropdownMenuItem(value: 'TASTE', child: Text(l10n.tasteType)),
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
            child: Text(l10n.cancel)
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveTag,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}