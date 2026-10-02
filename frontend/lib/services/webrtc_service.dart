import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'room_socket_service.dart';

/// Encapsule une connexion WebRTC peer-to-peer avec un autre participant.
/// Pour une classe de +5 élèves, remplacer ce modèle mesh par un SFU
/// (ex: mediasoup, LiveKit, Janus) — le principe de signalisation via
/// RoomSocketService reste identique.
class WebRTCPeerConnection {
  final String peerId;
  final RoomSocketService socket;
  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;

  final void Function(MediaStream stream)? onRemoteStream;

  WebRTCPeerConnection({
    required this.peerId,
    required this.socket,
    this.onRemoteStream,
  });

  // IMPORTANT: un serveur STUN seul ne suffit pas quand les deux participants
  // sont sur des réseaux mobiles/4G (NAT strict ou symétrique) — il faut un
  // serveur TURN pour relayer l'audio dans ce cas, sinon la connexion échoue
  // silencieusement (aucun son dans aucun sens). Ici: serveurs STUN Google +
  // serveur TURN gratuit (Open Relay Project / Metered.ca) pour les tests.
  // Pour la production, prévoir un TURN dédié (Twilio, Xirsys, coturn...).
  static const Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'iceCandidatePoolSize': 10,
  };

  Future<void> init({bool video = false, MediaStream? localStream}) async {
    _pc = await createPeerConnection(_config);

    localStream ??= await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video,
    });
    this.localStream = localStream;
    for (final track in localStream.getTracks()) {
      await _pc!.addTrack(track, localStream);
    }

    _pc!.onIceCandidate = (candidate) {
      socket.sendIceCandidate(peerId, candidate.toMap());
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream!);
      }
    };
  }

  Future<void> createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    socket.sendWebRTCOffer(peerId, {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> handleRemoteOffer(Map<String, dynamic> sdp) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    socket.sendWebRTCAnswer(peerId, {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> handleRemoteAnswer(Map<String, dynamic> sdp) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
  }

  Future<void> addRemoteIceCandidate(Map<String, dynamic> candidate) async {
    await _pc!.addCandidate(RTCIceCandidate(
      candidate['candidate'],
      candidate['sdpMid'],
      candidate['sdpMLineIndex'],
    ));
  }

  void setMicEnabled(bool enabled) {
    localStream?.getAudioTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> dispose() async {
    // Le flux micro est partagé entre toutes les connexions de la salle
    // (géré et libéré par ClassroomScreen) — on ne le ferme pas ici.
    await _pc?.close();
  }
}
