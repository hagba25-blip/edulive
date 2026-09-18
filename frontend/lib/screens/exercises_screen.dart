import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ExercisesScreen extends StatefulWidget {
  final User user;
  final String classId;
  final String className;

  const ExercisesScreen({
    super.key,
    required this.user,
    required this.classId,
    required this.className,
  });

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<dynamic> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.exercisesForClass(widget.classId);
      setState(() => _exercises = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openCreateDialog() {
    final titleCtrl = TextEditingController();
    final questionCtrl = TextEditingController();
    final optionsCtrl = TextEditingController(); // séparées par des virgules pour un QCM
    final correctCtrl = TextEditingController();
    String type = 'qcm';
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvel exercice'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Titre')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'qcm', child: Text('QCM')),
                    DropdownMenuItem(value: 'open', child: Text('Question ouverte')),
                    DropdownMenuItem(value: 'true_false', child: Text('Vrai / Faux')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'qcm'),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: questionCtrl,
                  decoration: const InputDecoration(labelText: 'Question'),
                  maxLines: 2,
                ),
                if (type == 'qcm') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: optionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Options (séparées par des virgules)',
                      hintText: 'x, 2x, x², 2',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: correctCtrl,
                  decoration: InputDecoration(
                    labelText: type == 'true_false' ? 'Bonne réponse (vrai/faux)' : 'Bonne réponse',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                try {
                  final options = type == 'qcm'
                      ? optionsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                      : null;
                  await ApiService.createExercise(
                    classId: widget.classId,
                    title: titleCtrl.text.trim(),
                    type: type,
                    question: questionCtrl.text.trim(),
                    options: options,
                    correctAnswer: correctCtrl.text.trim().isEmpty ? null : correctCtrl.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _load();
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAnswerDialog(Map<String, dynamic> exercise) {
    final answerCtrl = TextEditingController();
    final type = exercise['type'];
    final options = (exercise['options'] as List?)?.cast<String>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(exercise['title'] ?? 'Exercice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise['question'] ?? ''),
            const SizedBox(height: 12),
            if (type == 'true_false')
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Vrai'),
                      value: 'vrai',
                      groupValue: answerCtrl.text,
                      onChanged: (v) => answerCtrl.text = v ?? '',
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Faux'),
                      value: 'faux',
                      groupValue: answerCtrl.text,
                      onChanged: (v) => answerCtrl.text = v ?? '',
                    ),
                  ),
                ],
              )
            else if (type == 'qcm' && options != null)
              ...options.map((o) => RadioListTile<String>(
                    title: Text(o),
                    value: o,
                    groupValue: answerCtrl.text,
                    onChanged: (v) => answerCtrl.text = v ?? '',
                  ))
            else
              TextField(
                controller: answerCtrl,
                decoration: const InputDecoration(labelText: 'Ta réponse'),
                maxLines: 3,
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiService.submitAnswer(exercise['id'], answerCtrl.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                messenger.showSnackBar(const SnackBar(content: Text('Réponse envoyée !')));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResults(String exerciseId) async {
    try {
      final results = await ApiService.exerciseResults(exerciseId);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Résultats'),
          content: SizedBox(
            width: double.maxFinite,
            child: results.isEmpty
                ? const Text('Aucune réponse pour le moment.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final r = results[i];
                      final student = r['users'];
                      final name = student != null ? student['full_name'] : 'Élève';
                      final correct = r['is_correct'];
                      return ListTile(
                        title: Text(name),
                        subtitle: Text('Réponse: ${r['answer'] ?? '-'}'),
                        trailing: correct == null
                            ? const Icon(Icons.help_outline, color: Colors.grey)
                            : Icon(
                                correct ? Icons.check_circle : Icons.cancel,
                                color: correct ? Colors.green : Colors.red,
                              ),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Exercices — ${widget.className}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _exercises.isEmpty
                  ? const Center(child: Text('Aucun exercice pour le moment'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _exercises.length,
                      itemBuilder: (context, i) {
                        final ex = _exercises[i];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              ex['type'] == 'qcm'
                                  ? Icons.checklist
                                  : ex['type'] == 'true_false'
                                      ? Icons.rule
                                      : Icons.edit_note,
                            ),
                            title: Text(ex['title'] ?? ''),
                            subtitle: Text(ex['question'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: widget.user.isTeacher
                                ? IconButton(
                                    icon: const Icon(Icons.bar_chart),
                                    tooltip: 'Voir les résultats',
                                    onPressed: () => _showResults(ex['id']),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: widget.user.isTeacher ? null : () => _openAnswerDialog(ex),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: widget.user.isTeacher
          ? FloatingActionButton(onPressed: _openCreateDialog, child: const Icon(Icons.add))
          : null,
    );
  }
}