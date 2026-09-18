import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/room_socket_service.dart';

class ParticipantsWidget extends StatefulWidget {
  final RoomSocketService socket;
  final bool isTeacher;
  const ParticipantsWidget({super.key, required this.socket, required this.isTeacher});

  @override
  State<ParticipantsWidget> createState() => ParticipantsWidgetState();
}

class ParticipantsWidgetState extends State<ParticipantsWidget> {
  final Set<String> _participants = {};
  final Set<String> _handsRaised = {};
  final Set<String> _micEnabled = {};
  final Map<String, String> _names = {};

  void _resolveName(String id) {
    if (_names.containsKey(id)) return;
    _names[id] = id.substring(0, 8); // placeholder immédiat pendant le chargement
    ApiService.getUserName(id).then((name) {
      if (mounted) setState(() => _names[id] = name);
    });
  }

  void addParticipant(String id) => setState(() {
        _participants.add(id);
        _resolveName(id);
      });
  void removeParticipant(String id) => setState(() {
        _participants.remove(id);
        _handsRaised.remove(id);
        _micEnabled.remove(id);
      });
  void setHandRaised(String id) => setState(() => _handsRaised.add(id));
  void setMicStatus(String id, bool enabled) => setState(() {
        if (enabled) {
          _micEnabled.add(id);
        } else {
          _micEnabled.remove(id);
        }
      });

  @override
  Widget build(BuildContext context) {
    final ids = _participants.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: ids.length,
      itemBuilder: (context, i) {
        final id = ids[i];
        final handUp = _handsRaised.contains(id);
        final micOn = _micEnabled.contains(id);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(_names[id] ?? id.substring(0, 8)),
          trailing: Wrap(
            spacing: 4,
            children: [
              if (handUp) const Icon(Icons.back_hand, color: Colors.orange, size: 18),
              Icon(micOn ? Icons.mic : Icons.mic_off, size: 18, color: micOn ? Colors.green : Colors.grey),
              if (widget.isTeacher)
                IconButton(
                  icon: Icon(micOn ? Icons.mic_off : Icons.mic, size: 18),
                  tooltip: micOn ? 'Retirer la parole' : 'Autoriser la parole',
                  onPressed: () {
                    if (micOn) {
                      widget.socket.revokeMic(id);
                    } else {
                      widget.socket.grantMic(id);
                    }
                    setMicStatus(id, !micOn);
                    setState(() => _handsRaised.remove(id));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}