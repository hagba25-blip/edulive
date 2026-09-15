from typing import Dict, List
from fastapi import WebSocket
import json


class ConnectionManager:
    """
    Gère les connexions WebSocket regroupées par session_id (une "salle" = un cours live).
    Chaque salle contient plusieurs clients (enseignant + élèves).
    """

    def __init__(self):
        # session_id -> { user_id: WebSocket }
        self.rooms: Dict[str, Dict[str, WebSocket]] = {}
        # session_id -> historique des traits du tableau blanc (pour les nouveaux arrivants)
        self.whiteboard_state: Dict[str, list] = {}

    async def connect(self, session_id: str, user_id: str, websocket: WebSocket):
        await websocket.accept()
        self.rooms.setdefault(session_id, {})
        existing_participants = list(self.rooms[session_id].keys())  # avant d'ajouter le nouvel arrivant

        self.rooms[session_id][user_id] = websocket
        self.whiteboard_state.setdefault(session_id, [])

        # Envoie l'état actuel du tableau blanc au nouvel arrivant
        await websocket.send_json({
            "type": "whiteboard_sync",
            "strokes": self.whiteboard_state[session_id],
        })

        # Envoie la liste des participants déjà présents au nouvel arrivant
        await websocket.send_json({
            "type": "participants_sync",
            "participants": existing_participants,
        })

        # Prévient les autres qu'un nouveau participant est arrivé
        await self.broadcast(session_id, {
            "type": "participant_joined",
            "user_id": user_id,
        }, exclude=user_id)

    def disconnect(self, session_id: str, user_id: str):
        if session_id in self.rooms and user_id in self.rooms[session_id]:
            del self.rooms[session_id][user_id]
            if not self.rooms[session_id]:
                del self.rooms[session_id]

    async def broadcast(self, session_id: str, message: dict, exclude: str = None):
        if session_id not in self.rooms:
            return
        dead = []
        for uid, ws in self.rooms[session_id].items():
            if uid == exclude:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(uid)
        for uid in dead:
            self.disconnect(session_id, uid)

    async def send_to(self, session_id: str, user_id: str, message: dict):
        ws = self.rooms.get(session_id, {}).get(user_id)
        if ws:
            await ws.send_json(message)

    def record_stroke(self, session_id: str, stroke: dict):
        self.whiteboard_state.setdefault(session_id, []).append(stroke)

    def clear_whiteboard(self, session_id: str):
        self.whiteboard_state[session_id] = []

    def erase_element(self, session_id: str, element_id: str):
        """Retire un seul élément (trait/texte/forme) de l'historique, sans tout effacer."""
        strokes = self.whiteboard_state.get(session_id, [])
        self.whiteboard_state[session_id] = [s for s in strokes if s.get("id") != element_id]

    def participants(self, session_id: str) -> List[str]:
        return list(self.rooms.get(session_id, {}).keys())


manager = ConnectionManager()