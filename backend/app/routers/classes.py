import random
import string
import json
from fastapi import APIRouter, Depends, HTTPException

from app.models import ClassCreate, ClassOut, JoinClass, ClassMessageCreate
from app.auth import get_current_user, require_teacher
from app.database import supabase

router = APIRouter(prefix="/classes", tags=["Classes"])


def generate_invite_code(length: int = 6) -> str:
    return "".join(random.choices(string.ascii_uppercase + string.digits, k=length))


def _is_class_live(class_id: str) -> bool:
    res = supabase.table("course_sessions").select("id").eq("class_id", class_id).eq(
        "status", "live"
    ).execute()
    return len(res.data) > 0


def _member_count(class_id: str) -> int:
    res = supabase.table("class_members").select("id").eq("class_id", class_id).execute()
    return len(res.data)


@router.post("/", response_model=ClassOut)
def create_class(payload: ClassCreate, teacher: dict = Depends(require_teacher)):
    code = generate_invite_code()
    data = {
        "name": payload.name,
        "subject": payload.subject,
        "description": payload.description,
        "teacher_id": teacher["id"],
        "invite_code": code,
        "is_private": payload.is_private,
        "is_paid": payload.is_paid,
        "price": payload.price if payload.is_paid else 0,
        "currency": payload.currency,
    }
    res = supabase.table("classes").insert(data).execute()

    if payload.is_paid and payload.payout_phone:
        try:
            supabase.table("users").update({"payout_phone": payload.payout_phone}).eq("id", teacher["id"]).execute()
        except Exception:
            pass  # colonne payout_phone pas encore créée: on ignore plutôt que de faire échouer la création

    return res.data[0]


@router.get("/mine")
def list_my_classes(user: dict = Depends(get_current_user)):
    """Renvoie les classes de l'enseignant OU les classes où l'utilisateur (élève ou enseignant) est inscrit."""
    if user["role"] == "teacher":
        res = supabase.table("classes").select("*").eq("teacher_id", user["id"]).execute()
        owned = res.data
    else:
        owned = []

    members = supabase.table("class_members").select("class_id").eq("student_id", user["id"]).execute()
    joined_ids = [m["class_id"] for m in members.data]
    joined = []
    if joined_ids:
        res2 = supabase.table("classes").select("*").in_("id", joined_ids).execute()
        joined = res2.data

    seen = set()
    result = []
    for c in owned + joined:
        if c["id"] not in seen:
            seen.add(c["id"])
            result.append(c)
    return result


@router.get("/public")
def list_public_classes(user: dict = Depends(get_current_user)):
    """Toutes les classes publiques (payantes ou gratuites), tous enseignants confondus,
    visibles depuis l'écran d'accueil de n'importe quel compte. Les classes privées
    n'apparaissent jamais ici (uniquement accessibles avec le code d'invitation)."""
    res = supabase.table("classes").select("*").execute()
    # Une classe est publique sauf si elle est explicitement marquée privée
    # (inclut les anciennes classes créées avant l'ajout de la colonne is_private).
    classes = [c for c in res.data if not c.get("is_private")]

    teacher_ids = list({c["teacher_id"] for c in classes})
    teachers = {}
    if teacher_ids:
        t_res = supabase.table("users").select("id, full_name").in_("id", teacher_ids).execute()
        teachers = {t["id"]: t["full_name"] for t in t_res.data}

    result = []
    for c in classes:
        result.append({
            **c,
            "teacher_name": teachers.get(c["teacher_id"], "Enseignant"),
            "is_live": _is_class_live(c["id"]),
            "member_count": _member_count(c["id"]),
        })
    return result


@router.get("/{class_id}/info")
def class_info(class_id: str, user: dict = Depends(get_current_user)):
    """Infos détaillées d'une classe: description, prix/gratuit, statut live ou prochaine
    séance programmée, nombre de participants — utilisées par l'écran 'Voir les infos'."""
    cls = supabase.table("classes").select("*").eq("id", class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    c = cls.data[0]

    teacher = supabase.table("users").select("full_name").eq("id", c["teacher_id"]).execute()
    teacher_name = teacher.data[0]["full_name"] if teacher.data else "Enseignant"

    sessions = supabase.table("course_sessions").select("*").eq("class_id", class_id).order(
        "created_at", desc=True
    ).execute()
    live_session = next((s for s in sessions.data if s["status"] == "live"), None)
    next_scheduled = next((s for s in sessions.data if s["status"] == "scheduled"), None)

    reminder = supabase.table("class_reminders").select("id").eq("class_id", class_id).eq(
        "user_id", user["id"]
    ).execute()

    return {
        **c,
        "teacher_name": teacher_name,
        "member_count": _member_count(class_id),
        "is_live": live_session is not None,
        "live_session_id": live_session["id"] if live_session else None,
        "next_scheduled_at": next_scheduled["scheduled_at"] if next_scheduled else None,
        "is_reminded": len(reminder.data) > 0,
    }


@router.post("/join")
def join_class(payload: JoinClass, user: dict = Depends(get_current_user)):
    """N'importe quel compte (élève OU enseignant) peut rejoindre une classe comme participant,
    y compris un enseignant qui veut suivre le cours d'un autre enseignant."""
    cls = supabase.table("classes").select("*").eq("invite_code", payload.invite_code).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Code d'invitation invalide")

    class_data = cls.data[0]
    class_id = class_data["id"]

    if class_data["teacher_id"] == user["id"]:
        raise HTTPException(status_code=400, detail="C'est votre propre classe")

    if class_data.get("is_paid"):
        raise HTTPException(
            status_code=402,
            detail=json.dumps({
                "message": f"Cette classe est payante ({class_data['price']} {class_data['currency']}).",
                "class_id": class_id,
                "class_name": class_data["name"],
                "price": class_data["price"],
                "currency": class_data["currency"],
            }),
        )

    try:
        supabase.table("class_members").insert(
            {"class_id": class_id, "student_id": user["id"]}
        ).execute()
    except Exception:
        raise HTTPException(status_code=400, detail="Vous êtes déjà inscrit à cette classe")

    try:
        supabase.table("notifications").insert({
            "user_id": class_data["teacher_id"],
            "title": "Nouvel inscrit",
            "body": f"{user['full_name']} a rejoint {class_data['name']}.",
        }).execute()
    except Exception:
        pass

    return {"message": "Inscription réussie", "class": class_data}


@router.get("/{class_id}/students")
def list_students(class_id: str, teacher: dict = Depends(require_teacher)):
    members = supabase.table("class_members").select("student_id, joined_at").eq("class_id", class_id).execute()
    student_ids = [m["student_id"] for m in members.data]
    if not student_ids:
        return []
    res = supabase.table("users").select("id, full_name, email, avatar_url").in_("id", student_ids).execute()
    return res.data


@router.delete("/{class_id}/students/{student_id}")
def remove_student(class_id: str, student_id: str, teacher: dict = Depends(require_teacher)):
    cls = supabase.table("classes").select("teacher_id").eq("id", class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    if cls.data[0]["teacher_id"] != teacher["id"]:
        raise HTTPException(status_code=403, detail="Cette classe ne vous appartient pas")

    supabase.table("class_members").delete().eq("class_id", class_id).eq("student_id", student_id).execute()
    return {"message": "Élève retiré de la classe"}


@router.get("/{class_id}/revenue")
def class_revenue(class_id: str, teacher: dict = Depends(require_teacher)):
    cls = supabase.table("classes").select("teacher_id, currency").eq("id", class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    if cls.data[0]["teacher_id"] != teacher["id"]:
        raise HTTPException(status_code=403, detail="Cette classe ne vous appartient pas")

    payments = supabase.table("payments").select(
        "*, users:student_id(full_name, email)"
    ).eq("class_id", class_id).eq("status", "success").order("confirmed_at", desc=True).execute()

    total = sum(float(p["amount"]) for p in payments.data)
    return {
        "total": total,
        "currency": cls.data[0]["currency"],
        "transactions": payments.data,
    }


# ---------------------------------------------------------------------------
# MUR DE MESSAGES (public + privé au créateur)
# ---------------------------------------------------------------------------

@router.post("/{class_id}/messages")
def post_class_message(class_id: str, payload: ClassMessageCreate, user: dict = Depends(get_current_user)):
    cls = supabase.table("classes").select("id, teacher_id, name").eq("id", class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    class_row = cls.data[0]

    data = {
        "class_id": class_id,
        "sender_id": user["id"],
        "content": payload.content,
        "is_private": payload.is_private,
    }
    res = supabase.table("class_messages").insert(data).execute()

    # Notifie le créateur de la classe (sauf s'il s'agit de lui-même qui écrit)
    if class_row["teacher_id"] != user["id"]:
        kind = "message privé" if payload.is_private else "message public"
        supabase.table("notifications").insert({
            "user_id": class_row["teacher_id"],
            "title": "Nouveau message",
            "body": f"{user['full_name']} a laissé un {kind} sur {class_row['name']}.",
        }).execute()

    return res.data[0]


@router.get("/{class_id}/messages")
def get_class_messages(class_id: str, user: dict = Depends(get_current_user)):
    """Messages publics visibles par tous + messages privés visibles seulement par
    leur auteur ou par l'enseignant propriétaire de la classe."""
    cls = supabase.table("classes").select("teacher_id").eq("id", class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    is_owner = cls.data[0]["teacher_id"] == user["id"]

    res = supabase.table("class_messages").select(
        "*, users:sender_id(full_name)"
    ).eq("class_id", class_id).order("created_at").execute()

    visible = [
        m for m in res.data
        if not m["is_private"] or is_owner or m["sender_id"] == user["id"]
    ]
    return visible


# ---------------------------------------------------------------------------
# "PROGRAMMER" UNE CLASSE (rappel / notification)
# ---------------------------------------------------------------------------

@router.post("/{class_id}/remind")
def set_reminder(class_id: str, user: dict = Depends(get_current_user)):
    cls = supabase.table("classes").select("id").eq("id", class_id).execute()
    if not cls.data:
        raise HTTPException(status_code=404, detail="Classe introuvable")
    try:
        supabase.table("class_reminders").insert({"class_id": class_id, "user_id": user["id"]}).execute()
    except Exception:
        pass  # déjà programmé, rien à faire
    return {"message": "Tu seras notifié quand cette classe démarre."}


@router.delete("/{class_id}/remind")
def remove_reminder(class_id: str, user: dict = Depends(get_current_user)):
    supabase.table("class_reminders").delete().eq("class_id", class_id).eq("user_id", user["id"]).execute()
    return {"message": "Rappel annulé"}

