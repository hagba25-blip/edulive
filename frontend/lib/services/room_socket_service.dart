import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

/// Gère la connexion WebSocket unique à une salle de cours en direct.
/// Relaie les événements: tableau blanc, chat, main levée, micro, signalisation WebRTC.
class RoomSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(String sessionId) {
    final uri = Uri.parse('$kWsBaseUrl/ws/room/$sessionId?token=${ApiService.token}');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _messageController.add(data);
      },
      onError: (e) => _messageController.addError(e),
      onDone: () => print('WebSocket fermé'),
    );
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  // ---------- TABLEAU BLANC ----------
  void sendStroke(Map<String, dynamic> strokeJson) {
    _send({'type': 'whiteboard_draw', 'stroke': strokeJson});
  }

  void clearWhiteboard() {
    _send({'type': 'whiteboard_clear'});
  }

  // ---------- CHAT ----------
  void sendChatMessage(String content, {bool isPrivate = false, String? recipientId}) {
    _send({
      'type': 'chat_message',
      'content': content,
      'is_private': isPrivate,
      'recipient_id': recipientId,
    });
  }

  // ---------- MAIN LEVÉE / MICRO ----------
  void raiseHand() => _send({'type': 'raise_hand'});

  void grantMic(String targetUserId) => _send({'type': 'grant_mic', 'target_user_id': targetUserId});

  void revokeMic(String targetUserId) => _send({'type': 'revoke_mic', 'target_user_id': targetUserId});

  // ---------- SIGNALISATION WEBRTC ----------
  void sendWebRTCOffer(String targetUserId, Map<String, dynamic> sdp) {
    _send({'type': 'webrtc_offer', 'target_user_id': targetUserId, 'sdp': sdp});
  }

  void sendWebRTCAnswer(String targetUserId, Map<String, dynamic> sdp) {
    _send({'type': 'webrtc_answer', 'target_user_id': targetUserId, 'sdp': sdp});
  }

  void sendIceCandidate(String targetUserId, Map<String, dynamic> candidate) {
    _send({'type': 'webrtc_ice_candidate', 'target_user_id': targetUserId, 'candidate': candidate});
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
