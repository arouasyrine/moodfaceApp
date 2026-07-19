from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    reset_token = Column(String(255), unique=True, index=True, nullable=True)
    reset_token_expires = Column(DateTime, nullable=True)

    # Relation avec les enregistrements d'émotions
    records = relationship("EmotionRecord", back_populates="owner", cascade="all, delete-orphan")

class EmotionRecord(Base):
    __tablename__ = "emotion_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    emotion = Column(String(100), nullable=False)
    confidence = Column(Float, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    
    # Nouvelles colonnes pour le journal émotionnel intelligent
    note = Column(Text, nullable=True)
    tags = Column(Text, nullable=True) # tags stockés sous forme de chaîne séparée par des virgules
    user_declared_emotion = Column(String(100), nullable=True)

    # Relation inverse vers l'utilisateur
    owner = relationship("User", back_populates="records")


