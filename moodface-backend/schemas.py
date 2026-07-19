from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional

# Schémas pour l'utilisateur
class UserBase(BaseModel):
    name: str
    email: EmailStr

class UserCreate(UserBase):
    password: str

class UserUpdate(BaseModel):
    name: str
    email: EmailStr

class PasswordUpdate(BaseModel):
    old_password: str
    new_password: str

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class UserResponse(UserBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

# Schémas pour l'historique des émotions
class EmotionRecordCreate(BaseModel):
    emotion: str
    confidence: float
    note: Optional[str] = None
    tags: Optional[str] = None
    user_declared_emotion: Optional[str] = None

class EmotionRecordResponse(BaseModel):
    id: int
    user_id: int
    emotion: str
    confidence: float
    timestamp: datetime
    note: Optional[str] = None
    tags: Optional[str] = None
    user_declared_emotion: Optional[str] = None

    class Config:
        from_attributes = True

class JournalUpdateRequest(BaseModel):
    note: Optional[str] = None
    tags: Optional[str] = None
    user_declared_emotion: Optional[str] = None


