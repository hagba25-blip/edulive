from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from jose import jwt, JWTError

from app.config import settings
from app.database import supabase
from app.websocket.manager import manager

router = APIRouter()


def get_user_id_from_token(token: str) -> str:
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        return payload["sub"]
    except JWTError:
        return None


@router.websocket("/ws/room/{session_id}")
async def room_websocket(websocket: WebSocket, session_id: str, token: str = Query(...)):
    """
    Un seul canal WebSocket par utilisateur connecté à une session live.
    Types de messages échangés (champ "type") :

      Tableau blanc:
        whiteboard_draw   { type, stroke: {points, color, width, tool} }
        whiteboard_clear  { type }

      Chat:
        chat_message      { type, content, is_private, recipient_id }

      Main levée / micro:
        raise_hand        { type }
        grant_mic         { type, target_user_id }   (envoyé par l'enseignant)
        revoke_mic        { type, target_user_id }   (envoyé par l'enseignant)

      Signalisation WebRTC (audio/vidéo peer-to-peer ou vers un SFU):
        webrtc_offer       { type, target_user_id, sdp }
        webrtc_answer       { type, target_user_id, sdp }
        webrtc_ice_candidate { type, target_user_id, candidate }
    """
    user_id = get_user_id_from_token(token)
    if not user_id:
        await websocket.close(code=4001)
        return

    await manager.connect(session_id, user_id, websocket)

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            # ---------- TABLEAU BLANC ----------
            if msg_type == "whiteboard_draw":
                stroke = data.get("stroke")
                manager.record_stroke(session_id, stroke)
                await manager.broadcast(session_id, {
                    "type": "whiteboard_draw",
                    "stroke": stroke,
                    "from": user_id,
                }, exclude=user_id)

            elif msg_type == "whiteboard_clear":
                manager.clear_whiteboard(session_id)
                await manager.broadcast(session_id, {"type": "whiteboard_clear"}, exclude=user_id)

            # ---------- CHAT ----------
            elif msg_type == "chat_message":
                content = data.get("content", "")
                is_private = data.get("is_private", False)
                recipient_id = data.get("recipient_id")

                # Persistance en base
                supabase.table("chat_messages").insert({
                    "session_id": session_id,
                    "sender_id": user_id,
                    "content": content,
                    "is_private": is_private,
                    "recipient_id": recipient_id,
                }).execute()

                payload = {
                    "type": "chat_message",
                    "sender_id": user_id,
                    "content": content,
                    "is_private": is_private,
                }
                if is_private and recipient_id:
                    await manager.send_to(session_id, recipient_id, payload)
                    await websocket.send_json(payload)  # écho pour l'expéditeur
                else:
                    await manager.broadcast(session_id, payload)

            # ---------- MAIN LEVÉE ----------
            elif msg_type == "raise_hand":
                await manager.broadcast(session_id, {
                    "type": "hand_raised",
                    "user_id": user_id,
                })

            # ---------- GESTION DU MICRO (enseignant uniquement, à valider côté métier) ----------
            elif msg_type == "grant_mic":
                target = data.get("target_user_id")
                await manager.send_to(session_id, target, {"type": "mic_granted"})
                await manager.broadcast(session_id, {"type": "mic_status", "user_id": target, "enabled": True})

            elif msg_type == "revoke_mic":
                target = data.get("target_user_id")
                await manager.send_to(session_id, target, {"type": "mic_revoked"})
                await manager.broadcast(session_id, {"type": "mic_status", "user_id": target, "enabled": False})

            # ---------- SIGNALISATION WEBRTC (relayée telle quelle vers le destinataire) ----------
            elif msg_type in ("webrtc_offer", "webrtc_answer", "webrtc_ice_candidate"):
                target = data.get("target_user_id")
                data["from"] = user_id
                await manager.send_to(session_id, target, data)

    except WebSocketDisconnect:
        manager.disconnect(session_id, user_id)
        await manager.broadcast(session_id, {"type": "participant_left", "user_id": user_id})
