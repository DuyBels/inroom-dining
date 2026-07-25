import 'dart:html' as html;
import 'dart:js' as js;
import 'package:supabase_flutter/supabase_flutter.dart';

class MySessionStorage extends LocalStorage {
  const MySessionStorage() : super();

  String get _tabKey {
    String currentName = html.window.name ?? '';
    if (currentName.isEmpty || !currentName.startsWith('dining_pos_')) {
      currentName = 'dining_pos_${DateTime.now().microsecondsSinceEpoch}';
      html.window.name = currentName; 
    }
    return 'sb_session_$currentName';
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> retrieveSession() async {
    return html.window.sessionStorage[_tabKey];
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    html.window.sessionStorage[_tabKey] = persistSessionString;
  }

  @override
  Future<String?> removePersistedSession() async {
    html.window.sessionStorage.remove(_tabKey);
    return null;
  }

  @override
  Future<bool> hasAccessToken() async {
    return html.window.sessionStorage.containsKey(_tabKey);
  }

  @override
  Future<String?> accessToken() async => null;
}

LocalStorage? getIsolatedLocalStorage() => const MySessionStorage();

void disableBroadcastChannel() {
  js.context['BroadcastChannel'] = null;
}

String? getSavedLocale() {
  try {
    return html.window.localStorage['app_locale'];
  } catch (_) {
    return null;
  }
}

void saveSavedLocale(String code) {
  try {
    html.window.localStorage['app_locale'] = code;
  } catch (_) {}
}

