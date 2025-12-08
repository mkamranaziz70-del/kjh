import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // important for Web
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 👉 Detect if the device is mobile or wide-screen
        bool isMobile = constraints.maxWidth < 600;

        return MaterialApp(
          title: 'MMEmpire',
          debugShowCheckedModeBanner: false,

          // 👉 Global responsive density
          theme: ThemeData(
            useMaterial3: true,
            visualDensity: isMobile
                ? VisualDensity
                      .standard // proper spacing for mobile
                : VisualDensity.comfortable, // desktop/web spacing
          ),

          home: LoginScreen(),
        );
      },
    );
  }
}
