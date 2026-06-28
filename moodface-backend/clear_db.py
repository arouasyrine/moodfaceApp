from database import SessionLocal
import models
db = SessionLocal()
try:
        # Supprime toutes les lignes de chaque table
        db.query(models.EmotionRecord).delete()
        db.query(models.User).delete()
        db.commit()
        print("Base de données vidée avec succès !")
except Exception as e:
        db.rollback()
        print(f"Erreur : {e}")
finally:
        db.close()