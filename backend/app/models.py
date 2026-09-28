from pydantic import BaseModel, EmailStr
from typing import Optional, List, Any
from datetime import datetime
from enum import Enum


class UserRole(str, Enum):
    teacher = "teacher"
    student = "student"
    admin = "admin"


class UserRegister(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: UserRole


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserOut(BaseModel):
    id: str
    email: str
    full_name: str
    role: UserRole
    avatar_url: Optional[str] = None


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class ClassCreate(BaseModel):
    name: str
    subject: str
    description: Optional[str] = None
    is_private: bool = False
    is_paid: bool = False
    price: float = 0
    currency: str = "XOF"
    payout_phone: Optional[str] = None  # numéro mobile money de l'enseignant (avec code pays, ex: +228...)


class ClassOut(BaseModel):
    id: str
    name: str
    subject: str
    teacher_id: str
    invite_code: str
    is_paid: bool = False
    price: float = 0
    currency: str = "XOF"


class ClassMessageCreate(BaseModel):
    content: str
    is_private: bool = False  # False = mur public (visible à tous), True = seulement pour le créateur


class JoinClass(BaseModel):
    invite_code: str


class SessionCreate(BaseModel):
    class_id: str
    title: str
    scheduled_at: Optional[datetime] = None


class SessionOut(BaseModel):
    id: str
    class_id: str
    title: str
    status: str
    scheduled_at: Optional[datetime] = None
    started_at: Optional[datetime] = None


class ExerciseType(str, Enum):
    qcm = "qcm"
    open = "open"
    true_false = "true_false"


class ExerciseCreate(BaseModel):
    class_id: str
    title: str
    type: ExerciseType
    question: str
    options: Optional[List[str]] = None
    correct_answer: Optional[str] = None
    due_date: Optional[datetime] = None


class ExerciseSubmit(BaseModel):
    exercise_id: str
    answer: str


class ChatMessageIn(BaseModel):
    content: str
    is_private: bool = False
    recipient_id: Optional[str] = None


# ---------- PAIEMENTS ----------

class CheckoutCreate(BaseModel):
    class_id: str


class CheckoutOut(BaseModel):
    checkout_url: str
    payment_id: str


class WithdrawalMethod(str, Enum):
    mobile_money = "mobile_money"
    card = "card"


class WithdrawalCreate(BaseModel):
    method: WithdrawalMethod
    amount: float
    phone: Optional[str] = None       # requis si method == mobile_money
    card_info: Optional[str] = None   # requis si method == card (ex: 4 derniers chiffres, ou token)
    