from fastapi import APIRouter, Depends, HTTPException

from app.auth import get_current_user
from app.database import supabase

router = APIRouter(prefix="/users", tags=["Utilisateurs"])


@router.get("/{user_id}")
def get_user(user_id: str, current: dict = Depends(get_current_user)):
    """Infos publiques minimales d'un utilisateur (nom affiché, rôle) —
    utilisé pour afficher les vrais noms dans le chat et la liste des participants."""
    res = supabase.table("users").select("id, full_name, role, avatar_url").eq("id", user_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return res.data[0]