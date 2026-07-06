import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'router/app_router.dart';

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget
{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref)
  {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'INT Bank',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      routerConfig: appRouter,
    );
  }
}
