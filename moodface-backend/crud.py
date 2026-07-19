from sqlalchemy.orm import Session
import models
import schemas
import hashlib

def hash_password(password: str) -> str:
    # Utilisation de pbkdf2_hmac de la bibliothèque standard pour éviter des dépendances externes complexes
    salt = b"moodface_salt_secure_123"
    pwd_hash = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return pwd_hash.hex()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return hash_password(plain_password) == hashed_password

# Opérations Utilisateurs (CRUD)
def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email.lower()).first()

def get_user_by_id(db: Session, user_id: int):
    return db.query(models.User).filter(models.User.id == user_id).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_pwd = hash_password(user.password)
    db_user = models.User(
        name=user.name,
        email=user.email.lower(),
        hashed_password=hashed_pwd
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def update_user(db: Session, user_id: int, name: str, email: str):
    db_user = get_user_by_id(db, user_id=user_id)
    if db_user:
        db_user.name = name
        db_user.email = email.lower()
        db.commit()
        db.refresh(db_user)
    return db_user

def change_user_password(db: Session, user_id: int, old_password: str, new_password: str) -> bool:
    db_user = get_user_by_id(db, user_id=user_id)
    if not db_user:
        return False
    if not verify_password(old_password, db_user.hashed_password):
        return False
    db_user.hashed_password = hash_password(new_password)
    db.commit()
    db.refresh(db_user)
    return True

def reset_user_password(db: Session, user_id: int, temp_password: str):
    db_user = get_user_by_id(db, user_id=user_id)
    if db_user:
        db_user.hashed_password = hash_password(temp_password)
        db_user.reset_token = None
        db_user.reset_token_expires = None
        db.commit()
        db.refresh(db_user)
    return db_user

def set_user_reset_token(db: Session, user_id: int, token: str, expires_at):
    db_user = get_user_by_id(db, user_id=user_id)
    if db_user:
        db_user.reset_token = token
        db_user.reset_token_expires = expires_at
        db.commit()
        db.refresh(db_user)
    return db_user

def get_user_by_reset_token(db: Session, token: str):
    return db.query(models.User).filter(models.User.reset_token == token).first()

def reset_password_with_token(db: Session, user_id: int, new_password: str):
    db_user = get_user_by_id(db, user_id=user_id)
    if db_user:
        db_user.hashed_password = hash_password(new_password)
        db_user.reset_token = None
        db_user.reset_token_expires = None
        db.commit()
        db.refresh(db_user)
        return True
    return False

# Opérations Historique d'Émotions (CRUD)
def create_emotion_record(db: Session, record: schemas.EmotionRecordCreate, user_id: int):
    db_record = models.EmotionRecord(
        user_id=user_id,
        emotion=record.emotion,
        confidence=record.confidence,
        note=record.note,
        tags=record.tags,
        user_declared_emotion=record.user_declared_emotion
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record

def update_emotion_record_journal(db: Session, record_id: int, note: str, tags: str, user_declared_emotion: str):
    db_record = db.query(models.EmotionRecord).filter(models.EmotionRecord.id == record_id).first()
    if db_record:
        db_record.note = note
        db_record.tags = tags
        db_record.user_declared_emotion = user_declared_emotion
        db.commit()
        db.refresh(db_record)
    return db_record

def get_user_history(db: Session, user_id: int, limit: int = 100):
    return db.query(models.EmotionRecord).filter(models.EmotionRecord.user_id == user_id).order_by(models.EmotionRecord.timestamp.desc()).limit(limit).all()

def delete_emotion_record(db: Session, record_id: int) -> bool:
    db_record = db.query(models.EmotionRecord).filter(models.EmotionRecord.id == record_id).first()
    if db_record:
        db.delete(db_record)
        db.commit()
        return True
    return False


