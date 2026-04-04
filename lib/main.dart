import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'api/firebase_api.dart';
import 'firebase_options.dart';
import 'constants.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseApi().initNotifications();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Start with the default platform text theme, then map it to Inter
    final defaultTheme = Theme.of(context).textTheme;
    final interTheme = GoogleFonts.interTextTheme(defaultTheme);

    // Provide a helper to map w500 to everything
    final w500interTextTheme = interTheme.copyWith(
      displayLarge: interTheme.displayLarge?.copyWith(fontWeight: FontWeight.w500),
      displayMedium: interTheme.displayMedium?.copyWith(fontWeight: FontWeight.w500),
      displaySmall: interTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
      headlineLarge: interTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w500),
      headlineMedium: interTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
      headlineSmall: interTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
      titleLarge: interTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
      titleMedium: interTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      titleSmall: interTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
      bodyLarge: interTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: interTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      bodySmall: interTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: interTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
      labelMedium: interTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      labelSmall: interTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
    );

    return MaterialApp(
      title: 'DocuSys Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily,
        textTheme: w500interTextTheme,
        useMaterial3: true,
      ),
      home: const AuthCheck(),
    );
  }
}


class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');

    await Future.delayed(const Duration(milliseconds: 500)); // Splash effect

    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      // SYNC: Update FCM token even on auto-login
      FirebaseApi.syncToken().catchError((e) => debugPrint("Auto-sync error: $e"));

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a1, a2) => const NotificationsScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, a1, a2) => const LoginScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: primaryRed,
      body: Center(
        child: CircularProgressIndicator(color: primaryYellow),
      ),
    );
  }
}
