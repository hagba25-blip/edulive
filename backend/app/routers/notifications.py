from fastapi import APIRouter, Depends

from app.auth import get_current_user
from app.database import supabase

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("/mine")
def list_my_notifications(user: dict = Depends(get_current_user)):
    res = supabase.table("notifications").select("*").eq("user_id", user["id"]).order(
        "created_at", desc=True
    ).limit(50).execute()
    return res.data


@router.post("/{notification_id}/read")
def mark_as_read(notification_id: str, user: dict = Depends(get_current_user)):
    supabase.table("notifications").update({"is_read": True}).eq("id", notification_id).eq(
        "user_id", user["id"]
    ).execute()
    return {"message": "ok"}


@router.post("/read-all")
def mark_all_as_read(user: dict = Depends(get_current_user)):
    supabase.table("notifications").update({"is_read": True}).eq("user_id", user["id"]).eq(
        "is_read", False
    ).execute()
    return {"message": "ok"}
