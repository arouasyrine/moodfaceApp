from database import engine
from sqlalchemy import text, inspect

def migrate():
    print(f"Connexion à la base de données via SQLAlchemy Engine: {engine.url}")
    inspector = inspect(engine)
    
    # Vérifier si la table 'emotion_records' existe
    if 'emotion_records' in inspector.get_table_names():
        columns = [col['name'] for col in inspector.get_columns('emotion_records')]
        
        columns_to_add = [
            ("note", "TEXT"),
            ("tags", "TEXT"),
            ("user_declared_emotion", "TEXT")
        ]
        
        with engine.begin() as conn:
            for col_name, col_type in columns_to_add:
                if col_name not in columns:
                    try:
                        conn.execute(text(f"ALTER TABLE emotion_records ADD COLUMN {col_name} {col_type}"))
                        print(f"Colonne '{col_name}' ajoutée avec succès.")
                    except Exception as e:
                        print(f"Erreur lors de l'ajout de '{col_name}' : {e}")
                else:
                    print(f"La colonne '{col_name}' existe déjà.")
    else:
        print("La table 'emotion_records' n'existe pas. Elle sera créée lors du démarrage de l'application.")
    print("Migration terminée !")

if __name__ == "__main__":
    migrate()

