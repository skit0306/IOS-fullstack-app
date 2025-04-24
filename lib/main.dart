import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:p1/firebase_options.dart';
import 'theme/theme.dart';
import 'theme/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:p1/auth/auth_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Putonghua Learning App',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeNotifier.themeMode,
          home: AuthCheck(),
          builder: (context, child) {
            return Theme(
              data: themeNotifier.themeMode == ThemeMode.dark
                  ? darkTheme
                  : lightTheme,
              child: child!,
            );
          },
        );
      },
    );
  }
}
