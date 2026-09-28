import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'classroom_screen.dart';
import '../models/models.dart';

class ClassDetailScreen extends StatefulWidget {
  final User currentUser;
  final String classId;

  const ClassDetailScreen({super.key, required this.currentUser, required this.classId});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  Map<String, dynamic>? _info;
  List<dynamic> _messages = [];
  bool _loading = true;
  final _publicMsgCtrl = TextEditingController();
  final _privateMsgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final info = await ApiService.classInfo(widget.classId);
      final messages = await ApiService.classMessages(widget.classId);
      setState(() {
        _info = info;
        _messages = messages;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendPublicMessage() async {
    final text = _publicMsgCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiService.postClassMessage(widget.classId, text, isPrivate: false);
      _publicMsgCtrl.clear();
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _sendPrivateMessage() async {
    final text = _privateMsgCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiService.postClassMessage(widget.classId, text, isPrivate: true);
      _privateMsgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message privé envoyé au créateur.')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _toggleReminder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_info!['is_reminded'] == true) {
        await ApiService.removeReminder(widget.classId);
        messenger.showSnackBar(const SnackBar(content: Text('Rappel annulé.')));
      } else {
        await ApiService.setReminder(widget.classId);
        messenger.showSnackBar(const SnackBar(content: Text('Tu seras notifié au démarrage !')));
      }
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _join() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ApiService.joinClass(_info!['invite_code']);
      if (!mounted) return;
      final liveSessionId = _info!['live_session_id'];
      if (liveSessionId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassroomScreen(
              user: widget.currentUser,
              sessionId: liveSessionId,
              title: _info!['name'],
            ),
          ),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text(res['message'] ?? 'Classe rejointe !')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _info == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final info = _info!;
    final isLive = info['is_live'] == true;
    final isReminded = info['is_reminded'] == true;

    return Scaffold(
      appBar: AppBar(title: Text(info['name'])),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(info['name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                if (isLive)
                  const Chip(
                    label: Text('LIVE', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${info['subject']} · par ${info['teacher_name']}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            if ((info['description'] ?? '').toString().isNotEmpty) ...[
              Text(info['description']),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.people, size: 16),
                  label: Text('${info['member_count']} participant(s)'),
                ),
                Chip(
                  avatar: Icon(info['is_paid'] == true ? Icons.payments : Icons.card_giftcard, size: 16),
                  label: Text(
                    info['is_paid'] == true ? '${info['price']} ${info['currency']}' : 'Gratuit',
                  ),
                  backgroundColor: info['is_paid'] == true ? Colors.green[100] : Colors.blue[50],
                ),
                if (!isLive && info['next_scheduled_at'] != null)
                  Chip(
                    avatar: const Icon(Icons.event, size: 16),
                    label: Text('Programmé: ${info['next_scheduled_at'].toString().substring(0, 16)}'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLive ? _join : null,
                    icon: const Icon(Icons.login),
                    label: Text(isLive ? 'Rejoindre' : 'Pas en direct'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleReminder,
                    icon: Icon(isReminded ? Icons.notifications_active : Icons.notifications_none),
                    label: Text(isReminded ? 'Programmé' : 'Programmer'),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Mur public', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _publicMsgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message public...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendPublicMessage),
              ],
            ),
            const SizedBox(height: 8),
            ..._messages.where((m) => m['is_private'] != true).map((m) {
              final sender = m['users'];
              final name = sender != null ? sender['full_name'] : 'Utilisateur';
              return Card(
                child: ListTile(
                  dense: true,
                  leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                  title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(m['content']),
                ),
              );
            }),
            if (widget.currentUser.id != info['teacher_id']) ...[
              const Divider(height: 32),
              const Text('Message privé au créateur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _privateMsgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Message visible seulement par le créateur...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.lock_outline), onPressed: _sendPrivateMessage),
                ],
              ),
            ],
            if (widget.currentUser.id == info['teacher_id']) ...[
              const Divider(height: 32),
              Row(
                children: const [
                  Icon(Icons.lock_outline, size: 18, color: Colors.deepPurple),
                  SizedBox(width: 6),
                  Text('Messages privés reçus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              if (_messages.where((m) => m['is_private'] == true).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucun message privé pour le moment', style: TextStyle(color: Colors.grey)),
                )
              else
                ..._messages.where((m) => m['is_private'] == true).map((m) {
                  final sender = m['users'];
                  final name = sender != null ? sender['full_name'] : 'Utilisateur';
                  return Card(
                    color: Colors.deepPurple[50],
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.lock, size: 16, color: Colors.deepPurple),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(m['content']),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
