import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/room_socket_service.dart';
import '../widgets/whiteboard_widget.dart';
import '../widgets/chat_widget.dart';
import '../widgets/participants_widget.dart';

class ClassroomScreen extends StatefulWidget {
  final User user;
  final String sessionId;
  final String title;

  const ClassroomScreen({
    super.key,
    required this.user,
    required this.sessionId,
    required this.title,
  });

  @override
  State<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  late RoomSocketService _socket;
  final _whiteboardKey = GlobalKey<WhiteboardWidgetState>();
  final _chatKey = GlobalKey<ChatWidgetState>();
  final _participantsKey = GlobalKey<ParticipantsWidgetState>();

  bool _micOn = false;
  bool _handRaised = false;
  int _tabIndex = 0; // pour la disposition en onglets sur mobile

  @override
  void initState() {
    super.initState();
    _socket = RoomSocketService();
    _socket.connect(widget.sessionId);
    _socket.messages.listen(_onMessage);
  }

  void _onMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'whiteboard_sync':
        final strokes = (data['strokes'] as List).map((s) => Stroke.fromJson(s)).toList();
        _whiteboardKey.currentState?.receiveSync(strokes);
        break;
      case 'whiteboard_draw':
        _whiteboardKey.currentState?.receiveStroke(Stroke.fromJson(data['stroke']));
        break;
      case 'whiteboard_clear':
        _whiteboardKey.currentState?.clearAll();
        break;
      case 'chat_message':
        if (data['sender_id'] != widget.user.id) {
          _chatKey.currentState?.receiveMessage(
            ChatMessage(senderId: data['sender_id'], content: data['content']),
          );
        }
        break;
      case 'participant_joined':
        _participantsKey.currentState?.addParticipant(data['user_id']);
        break;
      case 'participant_left':
        _participantsKey.currentState?.removeParticipant(data['user_id']);
        break;
      case 'hand_raised':
        _participantsKey.currentState?.setHandRaised(data['user_id']);
        if (data['user_id'] != widget.user.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✋ ${data['user_id'].substring(0, 6)} demande la parole')),
          );
        }
        break;
      case 'mic_status':
        _participantsKey.currentState?.setMicStatus(data['user_id'], data['enabled']);
        break;
      case 'mic_granted':
        setState(() => _micOn = true);
        break;
      case 'mic_revoked':
        setState(() => _micOn = false);
        break;
      // 'webrtc_offer' / 'webrtc_answer' / 'webrtc_ice_candidate' seraient
      // routés ici vers WebRTCPeerConnection pour établir l'audio/vidéo.
    }
  }

  void _toggleHand() {
    setState(() => _handRaised = !_handRaised);
    if (_handRaised) _socket.raiseHand();
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.user.isTeacher;
    final canDraw = isTeacher || _micOn; // élève autorisé à parler peut aussi dessiner

    final tabs = [
      WhiteboardWidget(key: _whiteboardKey, socket: _socket, canDraw: canDraw),
      ParticipantsWidget(key: _participantsKey, socket: _socket, isTeacher: isTeacher),
      ChatWidget(key: _chatKey, socket: _socket, currentUserId: widget.user.id),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            const Chip(
              label: Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: Colors.red,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          if (isWide) {
            // Disposition bureau: tableau blanc à gauche, participants + chat à droite
            return Row(
              children: [
                Expanded(flex: 3, child: tabs[0]),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      const TabBar(tabs: [Tab(text: 'Participants'), Tab(text: 'Chat')]),
                      Expanded(
                        child: DefaultTabController(
                          length: 2,
                          child: TabBarView(children: [tabs[1], tabs[2]]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          // Disposition mobile: onglets Tableau | Participants | Chat
          return tabs[_tabIndex];
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width > 800
          ? _controlBar(isTeacher)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _controlBar(isTeacher),
                NavigationBar(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (i) => setState(() => _tabIndex = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.draw), label: 'Tableau'),
                    NavigationDestination(icon: Icon(Icons.people), label: 'Participants'),
                    NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _controlBar(bool isTeacher) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[900],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_micOn ? Icons.mic : Icons.mic_off, color: Colors.white),
            onPressed: isTeacher ? () => setState(() => _micOn = !_micOn) : null,
          ),
          if (!isTeacher)
            IconButton(
              icon: Icon(Icons.back_hand, color: _handRaised ? Colors.orange : Colors.white),
              onPressed: _toggleHand,
            ),
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.white),
            onPressed: () {
              // TODO: file_picker pour partager un document/PDF/image
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
