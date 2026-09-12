from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException

from app.models import SessionCreate
from app.auth import get_current_user, require_teacher
from app.database import supabase

router = APIRouter(prefix="/sessions", tags=["Sessions live"])


@router.post("/")
def schedule_session(payload: SessionCreate, teacher: dict = Depends(require_teacher)):
    data = {
        "class_id": payload.class_id,
        "title": payload.title,
        "scheduled_at": payload.scheduled_at.isoformat() if payload.scheduled_at else None,
        "status": "scheduled",
    }
    res = supabase.table("course_sessions").insert(data).execute()
    # TODO: notifier tous les élèves de la classe (table notifications)
    return res.data[0]


@router.post("/{session_id}/start")
def start_session(session_id: str, teacher: dict = Depends(require_teacher)):
    res = supabase.table("course_sessions").update(
        {"status": "live", "started_at": datetime.utcnow().isoformat()}
    ).eq("id", session_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Session introuvable")
    return res.data[0]


@router.post("/{session_id}/end")
def end_session(session_id: str, teacher: dict = Depends(require_teacher)):
    res = supabase.table("course_sessions").update(
        {"status": "ended", "ended_at": datetime.utcnow().isoformat()}
    ).eq("id", session_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Session introuvable")
    return res.data[0]


@router.get("/class/{class_id}")
def list_sessions(class_id: str, user: dict = Depends(get_current_user)):
    res = supabase.table("course_sessions").select("*").eq("class_id", class_id).order(
        "created_at", desc=True
    ).execute()
    return res.data


@router.get("/{session_id}")
def get_session(session_id: str, user: dict = Depends(get_current_user)):
    res = supabase.table("course_sessions").select("*").eq("id", session_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Session introuvable")
    return res.data
