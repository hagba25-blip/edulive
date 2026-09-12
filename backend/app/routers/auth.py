from fastapi import APIRouter, HTTPException
from app.models import UserRegister, UserLogin, TokenOut, UserOut
from app.auth import hash_password, verify_password, create_access_token
from app.database import supabase

router = APIRouter(prefix="/auth", tags=["Authentification"])


@router.post("/register", response_model=TokenOut)
def register(payload: UserRegister):
    existing = supabase.table("users").select("id").eq("email", payload.email).execute()
    if existing.data:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")

    user_data = {
        "email": payload.email,
        "password_hash": hash_password(payload.password),
        "full_name": payload.full_name,
        "role": payload.role.value,
    }
    res = supabase.table("users").insert(user_data).execute()
    user = res.data[0]

    token = create_access_token({"sub": user["id"], "role": user["role"]})
    return TokenOut(access_token=token, user=UserOut(**user))


@router.post("/login", response_model=TokenOut)
def login(payload: UserLogin):
    res = supabase.table("users").select("*").eq("email", payload.email).execute()
    if not res.data:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    user = res.data[0]
    if not verify_password(payload.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    token = create_access_token({"sub": user["id"], "role": user["role"]})
    return TokenOut(access_token=token, user=UserOut(**user))
