import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'classroom_screen.dart';
import 'exercises_screen.dart';
import 'class_students_screen.dart';

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

  static const List<String> _subjects = [
    'Mathématiques',
    'Physique',
    'Chimie',
    'Français',
    'Anglais',
    'Histoire',
    'Géographie',
    'SVT',
    'Informatique',
    'Économie',
    'Autre',
  ];

  void _showCreateOrJoinDialog() {
    final isTeacher = widget.user.isTeacher;
    final nameCtrl = TextEditingController();
    String selectedSubject = _subjects.first;
    final customSubjectCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context); // capturé AVANT l'ouverture du dialog

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isTeacher ? 'Créer une classe' : 'Rejoindre une classe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: isTeacher
                ? [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom (ex: Seconde S)')),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubject,
                      isExpanded: true,
                      items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setDialogState(() => selectedSubject = v ?? _subjects.first),
                      decoration: const InputDecoration(labelText: 'Matière'),
                    ),
                    if (selectedSubject == 'Autre') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customSubjectCtrl,
                        decoration: const InputDecoration(labelText: 'Précise la matière'),
                      ),
                    ],
                  ]
                : [
                    TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: "Code d'invitation")),
                  ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  if (isTeacher) {
                    final subject = selectedSubject == 'Autre' && customSubjectCtrl.text.trim().isNotEmpty
                        ? customSubjectCtrl.text.trim()
                        : selectedSubject;
                    await ApiService.createClass(nameCtrl.text, subject);
                  } else {
                    await ApiService.joinClass(codeCtrl.text.trim().toUpperCase());
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _loadClasses();
                  messenger.showSnackBar(const SnackBar(content: Text('Classe rejointe avec succès !')));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Valider'),
            ),
          ],
        ),
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
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.user.isTeacher)
                                  IconButton(
                                    icon: const Icon(Icons.group_outlined),
                                    tooltip: 'Gérer les élèves',
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClassStudentsScreen(
                                          classId: c.id,
                                          className: c.name,
                                        ),
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.assignment_outlined),
                                  tooltip: 'Exercices',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExercisesScreen(
                                        user: widget.user,
                                        classId: c.id,
                                        className: c.name,
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () async {
                              try {
                                String sessionId;

                                if (widget.user.isTeacher) {
                                  // Réutilise la session live déjà en cours pour cette classe si elle existe,
                                  // sinon en crée une nouvelle et la démarre.
                                  final sessions = await ApiService.sessionsForClass(c.id);
                                  final liveSession = sessions.cast<Map<String, dynamic>?>().firstWhere(
                                        (s) => s?['status'] == 'live',
                                        orElse: () => null,
                                      );
                                  if (liveSession != null) {
                                    sessionId = liveSession['id'];
                                  } else {
                                    final session = await ApiService.createSession(c.id, 'Cours - ${c.name}');
                                    await ApiService.startSession(session['id']);
                                    sessionId = session['id'];
                                  }
                                } else {
                                  // L'élève doit rejoindre la session déjà démarrée par l'enseignant.
                                  final sessions = await ApiService.sessionsForClass(c.id);
                                  final liveSession = sessions.cast<Map<String, dynamic>?>().firstWhere(
                                        (s) => s?['status'] == 'live',
                                        orElse: () => null,
                                      );
                                  if (liveSession == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Aucun cours en direct pour l'instant. Attends que l'enseignant démarre.")),
                                      );
                                    }
                                    return;
                                  }
                                  sessionId = liveSession['id'];
                                }

                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClassroomScreen(
                                      user: widget.user,
                                      sessionId: sessionId,
                                      title: c.name,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erreur: $e')),
                                  );
                                }
                              }
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