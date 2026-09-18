import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.loadToken();
  final savedUser = await ApiService.getSavedUserData();
  runApp(EduLiveApp(savedUser: savedUser));
}

class EduLiveApp extends StatelessWidget {
  final Map<String, dynamic>? savedUser;
  const EduLiveApp({super.key, this.savedUser});

  @override
  Widget build(BuildContext context) {
    // Si un compte est déjà enregistré (jeton + infos sauvegardés localement),
    // on saute directement au tableau de bord — sinon, écran de connexion.
    final Widget home = (ApiService.token != null && savedUser != null)
        ? DashboardScreen(user: User.fromJson(savedUser!))
        : const LoginScreen();

    return MaterialApp(
      title: 'EduLive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: home,
    );
  }
}