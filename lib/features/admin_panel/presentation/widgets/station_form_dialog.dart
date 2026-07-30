import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/l10n/app_localizations.dart';
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
  final Map<String, TextEditingController> _nameControllers = {};
  bool _isLoading = false;
  final Map<String, bool> _isTranslating = {};

  String _getNameInLang(String code, Map<String, dynamic> nameMap) {
    return nameMap[code]?.toString() ?? (code == 'vi' ? (nameMap['vi']?.toString() ?? '') : '');
  }

  @override
  void initState() {
    super.initState();
    final nameMap = widget.station != null ? L10nUtils.decodeField(widget.station!['name']) : <String, dynamic>{};
    
    for (var lang in L10nUtils.supportedLanguages) {
      final code = lang['code']!;
      _nameControllers[code] = TextEditingController(text: _getNameInLang(code, nameMap));
      _isTranslating[code] = false;
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
    
    final l10n = ref.read(l10nProvider);
    setState(() => _isTranslating[targetLang] = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      await gemini.autoTranslateMap(_nameControllers, force: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorTranslate}: $e')));
    } finally {
      if (mounted) setState(() => _isTranslating[targetLang] = false);
    }
  }

  Future<void> _saveStation() async {
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
      title: Text(widget.station == null ? l10n.addStation : l10n.editStation),
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
                          decoration: InputDecoration(labelText: '${l10n.stationNameLang} (${lang['name']})', border: const OutlineInputBorder()),
                          validator: code == 'vi' ? (val) => val == null || val.trim().isEmpty ? l10n.validStationName : null : null,
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveStation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}