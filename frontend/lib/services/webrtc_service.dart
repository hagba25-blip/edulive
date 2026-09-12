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

  static const Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  Future<void> init({bool video = false}) async {
    _pc = await createPeerConnection(_config);

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video,
    });
    for (final track in localStream!.getTracks()) {
      await _pc!.addTrack(track, localStream!);
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
    await localStream?.dispose();
    await _pc?.close();
  }
}
