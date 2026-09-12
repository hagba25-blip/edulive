import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'classroom_screen.dart';

class DashboardScreen extends StatefulWidget {
  final User user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<SchoolClass> _classes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _loading = true);
    final raw = await ApiService.myClasses();
    setState(() {
      _classes = raw.map((c) => SchoolClass.fromJson(c)).toList();
      _loading = false;
    });
  }

  void _showCreateOrJoinDialog() {
    final isTeacher = widget.user.isTeacher;
    final nameCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isTeacher ? 'Créer une classe' : 'Rejoindre une classe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: isTeacher
              ? [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Seconde S)')),
                  TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Matière')),
                ]
              : [
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Code d'invitation")),
                ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                if (isTeacher) {
                  await ApiService.createClass(nameCtrl.text, subjectCtrl.text);
                } else {
                  await ApiService.joinClass(codeCtrl.text.trim());
                }
                if (context.mounted) Navigator.pop(context);
                _loadClasses();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${widget.user.fullName} 👋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadClasses,
              child: _classes.isEmpty
                  ? const Center(child: Text('Aucune classe pour le moment'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _classes.length,
                      itemBuilder: (context, i) {
                        final c = _classes[i];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.book)),
                            title: Text(c.name),
                            subtitle: Text('${c.subject} · Code: ${c.inviteCode}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              // Enseignant: crée une session live puis démarre le cours.
                              // Élève: rejoindrait une session déjà "live" existante (à lister ici).
                              final session = widget.user.isTeacher
                                  ? await ApiService.createSession(c.id, 'Cours - ${c.name}')
                                  : null;
                              if (session != null) {
                                await ApiService.startSession(session['id']);
                              }
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClassroomScreen(
                                    user: widget.user,
                                    sessionId: session != null ? session['id'] : c.id,
                                    title: c.name,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOrJoinDialog,
        child: Icon(widget.user.isTeacher ? Icons.add : Icons.group_add),
      ),
    );
  }
}
