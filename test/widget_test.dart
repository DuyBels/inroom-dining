import 'package:flutter_test/flutter_test.dart';
import 'package:inroom_dining/core/utils/l10n_utils.dart';
import 'package:inroom_dining/core/l10n/app_localizations.dart';

void main() {
  group('Multi-language L10nUtils Tests', () {
    test('getL10n extracts correct language from Map', () {
      final mapData = {'vi': 'Cơm chiên', 'en': 'Fried Rice'};
      expect(L10nUtils.getL10n(mapData, 'vi'), 'Cơm chiên');
      expect(L10nUtils.getL10n(mapData, 'en'), 'Fried Rice');
    });

    test('getL10n falls back to vi if requested locale missing', () {
      final mapData = {'vi': 'Cơm chiên'};
      expect(L10nUtils.getL10n(mapData, 'en'), 'Cơm chiên');
    });

    test('getL10n decodes JSON string correctly', () {
      final jsonStr = '{"vi": "Phở bò", "en": "Beef Noodle"}';
      expect(L10nUtils.getL10n(jsonStr, 'vi'), 'Phở bò');
      expect(L10nUtils.getL10n(jsonStr, 'en'), 'Beef Noodle');
    });

    test('removeDiacritics strips Vietnamese accents', () {
      expect(L10nUtils.removeDiacritics('Cơm Gà Hải Nam'), 'Com Ga Hai Nam');
    });
  });

  group('AppDictionary Tests', () {
    test('viDict and enDict are properly defined', () {
      expect(viDict.login, 'Đăng nhập');
      expect(enDict.login, 'Login');
    });
  });
}
