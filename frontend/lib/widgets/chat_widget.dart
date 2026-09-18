import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/room_socket_service.dart';

class ChatWidget extends StatefulWidget {
  final RoomSocketService socket;
  final String currentUserId;
  const ChatWidget({super.key, required this.socket, required this.currentUserId});

  @override
  State<ChatWidget> createState() => ChatWidgetState();
}

class ChatWidgetState extends State<ChatWidget> {
  final List<ChatMessage> _messages = [];
  final Map<String, String> _names = {};
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  void _resolveName(String id) {
    if (_names.containsKey(id) || id == widget.currentUserId) return;
    _names[id] = id.substring(0, 8);
    ApiService.getUserName(id).then((name) {
      if (mounted) setState(() => _names[id] = name);
    });
  }

  /// Charge l'historique déjà stocké en base (appelé une fois à la connexion).
  void receiveHistory(List<dynamic> history) {
    setState(() {
      _messages.clear();
      for (final m in history) {
        _messages.add(ChatMessage(senderId: m['sender_id'], content: m['content']));
        _resolveName(m['sender_id']);
      }
    });
    _scrollToBottom();
  }

  void receiveMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
    _resolveName(msg.senderId);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    widget.socket.sendChatMessage(text);
    receiveMessage(ChatMessage(senderId: widget.currentUserId, content: text));
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (context, i) {
              final m = _messages[i];
              final isMe = m.senderId == widget.currentUserId;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.indigo[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Text(
                          _names[m.senderId] ?? m.senderId.substring(0, 8),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      Text(m.content),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un message...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: _send),
            ],
          ),
        ),
      ],
    );
  }
}