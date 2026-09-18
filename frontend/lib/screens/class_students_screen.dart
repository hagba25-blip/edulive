import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ClassStudentsScreen extends StatefulWidget {
  final String classId;
  final String className;

  const ClassStudentsScreen({super.key, required this.classId, required this.className});

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  List<dynamic> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.classStudents(widget.classId);
      setState(() => _students = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> student) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer cet élève ?'),
        content: Text(
          '${student['full_name']} ne pourra plus accéder à cette classe tant qu\'il ne la rejoindra pas de nouveau avec le code d\'invitation.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.removeStudent(widget.classId, student['id']);
      messenger.showSnackBar(SnackBar(content: Text('${student['full_name']} a été retiré de la classe.')));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Élèves — ${widget.className}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _students.isEmpty
                  ? const Center(child: Text('Aucun élève inscrit pour le moment'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _students.length,
                      itemBuilder: (context, i) {
                        final s = _students[i];
                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(s['full_name'] ?? ''),
                            subtitle: Text(s['email'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                              tooltip: 'Retirer de la classe',
                              onPressed: () => _confirmRemove(s),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}