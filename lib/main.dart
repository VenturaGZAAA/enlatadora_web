import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:enlatadora_web/screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  MyApp({super.key});

  final TextTheme textTheme = TextTheme(
    titleLarge: GoogleFonts.caveat(fontSize: 32.0, fontWeight: FontWeight.bold),
    headlineLarge: GoogleFonts.caveat(
      fontSize: 25.0,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Dashboard',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlueAccent,
          brightness: Brightness.light,
        ),
        textTheme: textTheme,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        textTheme: textTheme,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(rootTopico: 'home/test/'),
    );
  }
}
