import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegisterMode = false;
  String _role = 'student';
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = _isRegisterMode
          ? await ApiService.register(
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text,
              fullName: _nameCtrl.text.trim(),
              role: _role,
            )
          : await ApiService.login(_emailCtrl.text.trim(), _passCtrl.text);

      await ApiService.saveToken(result['access_token']);
      await ApiService.saveUserData(result['user']);
      final user = User.fromJson(result['user']);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 72, color: Colors.indigo),
                const SizedBox(height: 8),
                const Text('EduLive', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const Text('Cours particuliers en direct'),
                const SizedBox(height: 24),
                if (_isRegisterMode)
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person)),
                  ),
                if (_isRegisterMode) const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock)),
                ),
                if (_isRegisterMode) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'student', label: Text('👨‍🎓 Élève')),
                      ButtonSegment(value: 'teacher', label: Text('👨‍🏫 Enseignant')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) => setState(() => _role = s.first),
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isRegisterMode ? "S'inscrire" : 'Se connecter'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(_isRegisterMode
                      ? 'Déjà un compte ? Se connecter'
                      : "Pas de compte ? S'inscrire"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}