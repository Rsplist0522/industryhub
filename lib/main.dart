import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/local_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportsLocalSqlite = defaultTargetPlatform == TargetPlatform.android ||
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

  final appRouter = createAppRouter();
  runApp(
    ProviderScope(
      child: IndustryHubApp(router: appRouter),
    ),
  );
}

class IndustryHubApp extends StatelessWidget {
  const IndustryHubApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'IndustryHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
