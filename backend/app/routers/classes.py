import random
import string
from fastapi import APIRouter, Depends, HTTPException

from app.models import ClassCreate, ClassOut, JoinClass
from app.auth import get_current_user, require_teacher
from app.database import supabase

router = APIRouter(prefix="/classes", tags=["Classes"])


def generate_invite_code(length: int = 6) -> str:
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=length))


@router.post("/", response_model=ClassOut)
def create_class(payload: ClassCreate, teacher: dict = Depends(require_teacher)):
    code = generate_invite_code()
    data = {
        "name": payload.name,
        "subject": payload.subject,
        "teacher_id": teacher["id"],
        "invite_code": code,
    }
    res = supabase.table("classes").insert(data).execute()
    return res.data[0]


@router.get("/mine")
def list_my_classes(user: dict = Depends(get_current_user)):
    """Renvoie les classes de l'enseignant OU les classes où l'élève est inscrit."""
    if user["role"] == "teacher":
        res = supabase.table("classes").select("*").eq("teacher_id", user["id"]).execute()
        return res.data
    else:
        members = supabase.table("class_members").select("class_id").eq("student_id", user["id"]).execute()
        class_ids = [m["class_id"] for m in members.data]
        if not class_ids:
            return []
        res = supabase.table("classes").select("*").in_("id", class_ids).execute()
        return res.data


@router.post("/join")
def join_class(payload: JoinClass, student: dict = Depends(get_current_user)):
    if student["role"] != "student":
        raise HTTPException(status_code=403, detail="Réservé aux élèves")

    cls = supabase.table("classes").select("*").eq("invite_code", payload.invite_code).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Code d'invitation invalide")

    class_id = cls.data[0]["id"]
    try:
        supabase.table("class_members").insert(
            {"class_id": class_id, "student_id": student["id"]}
        ).execute()
    except Exception:
        raise HTTPException(status_code=400, detail="Vous êtes déjà inscrit à cette classe")

    return {"message": "Inscription réussie", "class": cls.data[0]}


@router.get("/{class_id}/students")
def list_students(class_id: str, teacher: dict = Depends(require_teacher)):
    members = supabase.table("class_members").select("student_id, joined_at").eq("class_id", class_id).execute()
    student_ids = [m["student_id"] for m in members.data]
    if not student_ids:
        return []
    res = supabase.table("users").select("id, full_name, email, avatar_url").in_("id", student_ids).execute()
    return res.data
