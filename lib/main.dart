import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  final supportsLocalSqlite =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  if (supportsLocalSqlite) {
    await LocalDatabase.database;
  }
  await dotenv.load(fileName: '.env', isOptional: false);

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabasePublishableKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'];
  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabasePublishableKey == null ||
      supabasePublishableKey.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY in .env.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUri: true,
    ),
  );

  runApp(const ProviderScope(child: IndustryHubApp()));
}

class IndustryHubApp extends StatefulWidget {
  const IndustryHubApp({super.key});

  @override
  State<IndustryHubApp> createState() => _IndustryHubAppState();
}

class _IndustryHubAppState extends State<IndustryHubApp> {
  late final AuthStateRefreshNotifier _authRefreshNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authRefreshNotifier = AuthStateRefreshNotifier();
    _router = createAppRouter(refreshListenable: _authRefreshNotifier);
  }

  @override
  void dispose() {
    _router.dispose();
    _authRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IndustryHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
