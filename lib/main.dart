import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; 
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js; 
import 'core/routing/app_router.dart';

// 1. Class Storage Cô lập: Ép mỗi tab dùng một "ngăn chứa" riêng biệt
class MySessionStorage extends LocalStorage {
  const MySessionStorage() : super();

  // Hàm lấy ID Tab duy nhất
  String get _tabKey {
    if (!kIsWeb) return 'supabase_auth_token';
    
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
    if (kIsWeb) return html.window.sessionStorage[_tabKey];
    return null;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    if (kIsWeb) html.window.sessionStorage[_tabKey] = persistSessionString;
  }

  @override
  Future<String?> removePersistedSession() async {
    if (kIsWeb) html.window.sessionStorage.remove(_tabKey);
    return null;
  }

  @override
  Future<bool> hasAccessToken() async {
    if (kIsWeb) return html.window.sessionStorage.containsKey(_tabKey);
    return false;
  }

  @override
  Future<String?> accessToken() async => null;
}

final supabase = Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. "CẮT DÂY LIÊN LẠC" GIỮA CÁC TAB
  if (kIsWeb) {
    // Vô hiệu hóa tính năng tự động đồng bộ tài khoản của trình duyệt
    // Điều này chặn đứng việc đăng nhập ở tab này làm tab kia nhảy theo
    js.context['BroadcastChannel'] = null;
  }

  await dotenv.load(fileName: ".env");

  String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // Ép dùng MySessionStorage để cô lập dữ liệu trên từng Tab
      localStorage: kIsWeb ? const MySessionStorage() : null,
    ),
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Smart Menu App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
