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


class ClassOut(BaseModel):
    id: str
    name: str
    subject: str
    teacher_id: str
    invite_code: str


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
