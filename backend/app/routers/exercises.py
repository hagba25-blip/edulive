from fastapi import APIRouter, Depends, HTTPException

from app.models import ExerciseCreate, ExerciseSubmit
from app.auth import get_current_user, require_teacher
from app.database import supabase

router = APIRouter(prefix="/exercises", tags=["Exercices"])


@router.post("/")
def create_exercise(payload: ExerciseCreate, teacher: dict = Depends(require_teacher)):
    data = payload.model_dump(mode="json")
    data["created_by"] = teacher["id"]
    res = supabase.table("exercises").insert(data).execute()
    return res.data[0]


@router.get("/class/{class_id}")
def list_exercises(class_id: str, user: dict = Depends(get_current_user)):
    res = supabase.table("exercises").select("*").eq("class_id", class_id).execute()
    return res.data


@router.post("/submit")
def submit_answer(payload: ExerciseSubmit, student: dict = Depends(get_current_user)):
    ex = supabase.table("exercises").select("*").eq("id", payload.exercise_id).single().execute()
    if not ex.data:
        raise HTTPException(status_code=404, detail="Exercice introuvable")

    exercise = ex.data
    is_correct = None
    score = None

    # Correction automatique pour QCM et Vrai/Faux
    if exercise["type"] in ("qcm", "true_false") and exercise.get("correct_answer"):
        is_correct = payload.answer.strip().lower() == exercise["correct_answer"].strip().lower()
        score = 1.0 if is_correct else 0.0

    data = {
        "exercise_id": payload.exercise_id,
        "student_id": student["id"],
        "answer": payload.answer,
        "is_correct": is_correct,
        "score": score,
    }
    res = supabase.table("exercise_submissions").upsert(data, on_conflict="exercise_id,student_id").execute()
    return res.data[0]


@router.get("/{exercise_id}/results")
def get_results(exercise_id: str, teacher: dict = Depends(require_teacher)):
    """Suivi des résultats/progression des élèves pour un exercice donné."""
    res = supabase.table("exercise_submissions").select(
        "*, users:student_id(full_name, email)"
    ).eq("exercise_id", exercise_id).execute()
    return res.data
