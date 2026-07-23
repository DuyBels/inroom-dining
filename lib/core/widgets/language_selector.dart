import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../utils/l10n_utils.dart';

class LanguageSelector extends ConsumerWidget {
  final Color? color;
  const LanguageSelector({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    
    // Tìm thông tin ngôn ngữ hiện tại
    final currentLang = L10nUtils.supportedLanguages.firstWhere(
      (l) => l['code'] == currentLocale,
      orElse: () => L10nUtils.supportedLanguages.first,
    );

    return PopupMenuButton<String>(
      tooltip: 'Chọn ngôn ngữ / Select Language',
      offset: const Offset(0, 45),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: (color ?? Colors.white).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentLang['flag']!, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              currentLang['name']!,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: color ?? Colors.white),
          ],
        ),
      ),
      onSelected: (String code) {
        ref.read(localeProvider.notifier).setLocale(code);
      },
      itemBuilder: (BuildContext context) {
        return L10nUtils.supportedLanguages.map((lang) {
          final bool isSelected = lang['code'] == currentLocale;
          return PopupMenuItem<String>(
            value: lang['code'],
            child: Row(
              children: [
                Text(lang['flag']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(
                  lang['name']!,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue : Colors.black87,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check, color: Colors.blue, size: 16),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
