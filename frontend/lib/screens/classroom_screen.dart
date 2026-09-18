import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/room_socket_service.dart';
import '../services/webrtc_service.dart';
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

class _ClassroomScreenState extends State<ClassroomScreen> with SingleTickerProviderStateMixin {
  late RoomSocketService _socket;
  late TabController _sideTabController; // pour la vue bureau (Participants | Chat)
  final _whiteboardKey = GlobalKey<WhiteboardWidgetState>();
  final _chatKey = GlobalKey<ChatWidgetState>();
  final _participantsKey = GlobalKey<ParticipantsWidgetState>();

  bool _micOn = false;
  bool _handRaised = false;
  int _tabIndex = 0; // pour la disposition en onglets sur mobile
  int _unreadChat = 0;
  int _unreadParticipants = 0;

  MediaStream? _localStream;
  final Map<String, WebRTCPeerConnection> _peers = {};

  @override
  void initState() {
    super.initState();
    _sideTabController = TabController(length: 2, vsync: this);
    _sideTabController.addListener(() {
      if (_sideTabController.indexIsChanging) return;
      setState(() {
        if (_sideTabController.index == 0) {
          _unreadParticipants = 0;
        } else {
          _unreadChat = 0;
        }
      });
    });
    _socket = RoomSocketService();
    _socket.connect(widget.sessionId);
    _socket.messages.listen(_onMessage);
    _loadChatHistory();
    _initLocalMedia();
  }

  /// Crée le flux micro local une seule fois (partagé avec toutes les connexions WebRTC).
  /// L'enseignant démarre avec le micro activé, l'élève démarre coupé.
  Future<void> _initLocalMedia() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      final micOn = widget.user.isTeacher;
      for (final track in stream.getAudioTracks()) {
        track.enabled = micOn;
      }
      setState(() {
        _localStream = stream;
        _micOn = micOn;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'accéder au micro: $e")),
        );
      }
    }
  }

  /// Établit (ou récupère) la connexion WebRTC avec un participant donné.
  /// [initiator] = true si c'est nous qui envoyons l'offre (cas: on vient de rejoindre
  /// et on découvre des participants déjà présents).
  Future<WebRTCPeerConnection> _ensurePeer(String peerId, {required bool initiator}) async {
    final existing = _peers[peerId];
    if (existing != null) return existing;

    final pc = WebRTCPeerConnection(peerId: peerId, socket: _socket);
    _peers[peerId] = pc;
    await pc.init(localStream: _localStream);
    if (initiator) {
      await pc.createOffer();
    }
    return pc;
  }

  void _removePeer(String peerId) {
    _peers.remove(peerId)?.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      final history = await ApiService.chatHistory(widget.sessionId);
      _chatKey.currentState?.receiveHistory(history);
    } catch (_) {
      // Pas grave si l'historique ne charge pas, le direct continuera de fonctionner.
    }
  }

  void _onMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'whiteboard_sync':
        final elements = (data['strokes'] as List).map((s) => BoardElement.fromJson(s)).toList();
        _whiteboardKey.currentState?.receiveSync(elements);
        break;
      case 'whiteboard_draw':
        _whiteboardKey.currentState?.receiveElement(BoardElement.fromJson(data['stroke']));
        break;
      case 'whiteboard_clear':
        _whiteboardKey.currentState?.clearAll();
        break;
      case 'whiteboard_erase':
        _whiteboardKey.currentState?.receiveErase(data['id']);
        break;
      case 'chat_message':
        if (data['sender_id'] != widget.user.id) {
          _chatKey.currentState?.receiveMessage(
            ChatMessage(senderId: data['sender_id'], content: data['content']),
          );
          if (!_isChatVisible()) setState(() => _unreadChat++);
        }
        break;
      case 'participants_sync':
        final ids = (data['participants'] as List).cast<String>();
        for (final id in ids) {
          _participantsKey.currentState?.addParticipant(id);
          _ensurePeer(id, initiator: true); // on vient d'arriver: c'est nous qui appelons
        }
        break;
      case 'participant_joined':
        _participantsKey.currentState?.addParticipant(data['user_id']);
        if (!_isParticipantsVisible()) setState(() => _unreadParticipants++);
        // On ne fait rien côté WebRTC ici: le nouvel arrivant va lui-même nous envoyer une offre.
        break;
      case 'participant_left':
        _participantsKey.currentState?.removeParticipant(data['user_id']);
        _removePeer(data['user_id']);
        break;
      case 'hand_raised':
        _participantsKey.currentState?.setHandRaised(data['user_id']);
        if (data['user_id'] != widget.user.id) {
          if (!_isParticipantsVisible()) setState(() => _unreadParticipants++);
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
        _localStream?.getAudioTracks().forEach((t) => t.enabled = true);
        break;
      case 'mic_revoked':
        setState(() => _micOn = false);
        _localStream?.getAudioTracks().forEach((t) => t.enabled = false);
        break;
      case 'webrtc_offer':
        _ensurePeer(data['from'], initiator: false).then((pc) => pc.handleRemoteOffer(data['sdp']));
        break;
      case 'webrtc_answer':
        _peers[data['from']]?.handleRemoteAnswer(data['sdp']);
        break;
      case 'webrtc_ice_candidate':
        _peers[data['from']]?.addRemoteIceCandidate(data['candidate']);
        break;
    }
  }

  Future<void> _confirmAndLeave(bool isTeacher) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isTeacher ? 'Terminer le cours ?' : 'Quitter le cours ?'),
        content: Text(
          isTeacher
              ? 'Cela mettra fin au cours en direct pour tous les participants.'
              : 'Tu peux revenir rejoindre le cours tant que l\'enseignant ne l\'a pas terminé.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isTeacher ? 'Terminer' : 'Quitter'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (isTeacher) {
      try {
        await ApiService.endSession(widget.sessionId);
      } catch (_) {
        // Même si l'appel échoue (ex: réseau), on laisse quand même l'enseignant sortir.
      }
    }

    if (mounted) Navigator.pop(context);
  }

  void _toggleHand() {
    setState(() => _handRaised = !_handRaised);
    if (_handRaised) _socket.raiseHand();
  }

  /// true si l'onglet Chat est actuellement visible (bureau ou mobile).
  bool _isChatVisible() {
    final isWide = _lastIsWide;
    if (isWide) return _sideTabController.index == 1;
    return _tabIndex == 2;
  }

  /// true si l'onglet Participants est actuellement visible (bureau ou mobile).
  bool _isParticipantsVisible() {
    final isWide = _lastIsWide;
    if (isWide) return _sideTabController.index == 0;
    return _tabIndex == 1;
  }

  bool _lastIsWide = false;

  @override
  void dispose() {
    _socket.dispose();
    for (final pc in _peers.values) {
      pc.dispose();
    }
    _localStream?.dispose();
    _sideTabController.dispose();
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
          _lastIsWide = isWide;
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
                      TabBar(
                        controller: _sideTabController,
                        tabs: [
                          Tab(
                            icon: Badge(
                              label: Text('$_unreadParticipants'),
                              isLabelVisible: _unreadParticipants > 0,
                              child: const Icon(Icons.people),
                            ),
                            text: 'Participants',
                          ),
                          Tab(
                            icon: Badge(
                              label: Text('$_unreadChat'),
                              isLabelVisible: _unreadChat > 0,
                              child: const Icon(Icons.chat),
                            ),
                            text: 'Chat',
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(controller: _sideTabController, children: [tabs[1], tabs[2]]),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          // Disposition mobile: onglets Tableau | Participants | Chat.
          // IndexedStack garde les 3 widgets vivants en mémoire (au lieu de les
          // détruire/recréer), pour ne pas perdre le tableau/chat en changeant d'onglet.
          return IndexedStack(index: _tabIndex, children: tabs);
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
                  onDestinationSelected: (i) => setState(() {
                    _tabIndex = i;
                    if (i == 1) _unreadParticipants = 0;
                    if (i == 2) _unreadChat = 0;
                  }),
                  destinations: [
                    const NavigationDestination(icon: Icon(Icons.draw), label: 'Tableau'),
                    NavigationDestination(
                      icon: Badge(
                        label: Text('$_unreadParticipants'),
                        isLabelVisible: _unreadParticipants > 0,
                        child: const Icon(Icons.people),
                      ),
                      label: 'Participants',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        label: Text('$_unreadChat'),
                        isLabelVisible: _unreadChat > 0,
                        child: const Icon(Icons.chat),
                      ),
                      label: 'Chat',
                    ),
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
            onPressed: isTeacher
                ? () {
                    setState(() => _micOn = !_micOn);
                    _localStream?.getAudioTracks().forEach((t) => t.enabled = _micOn);
                  }
                : null,
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
            onPressed: () => _confirmAndLeave(isTeacher),
          ),
        ],
      ),
    );
  }
}
