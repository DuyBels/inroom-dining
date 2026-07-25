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
    if (_nameViController.text.trim().isEmpty && _nameEnController.text.trim().isEmpty) return;
    setState(() => _isTranslating = true);
    final l10n = ref.read(l10nProvider);
    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslatePair(viController: _nameViController, enController: _nameEnController, force: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _saveTag() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _isLoading = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslatePair(viController: _nameViController, enController: _nameEnController);

      if (!_formKey.currentState!.validate()) {
        setState(() => _isLoading = false);
        return;
      }

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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameViController,
                      decoration: InputDecoration(labelText: '${l10n.tagNameLang} (VI)', border: const OutlineInputBorder()),
                      validator: (val) => val == null || val.trim().isEmpty ? l10n.validName : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isTranslating ? null : _translateWithAI,
                    icon: _isTranslating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Colors.purple),
                    tooltip: l10n.aiTranslateTooltip,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _nameEnController,
                      decoration: InputDecoration(labelText: '${l10n.tagNameLang} (EN)', border: const OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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