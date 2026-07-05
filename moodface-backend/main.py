from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Form, Request
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware # Permet de gérer les CORS pour les requêtes depuis Flutter
from sqlalchemy.orm import Session
import shutil # Pour gérer les fichiers (sauvegarde temporaire)
import os
import uuid
from typing import Optional

# Charger les variables d'un fichier .env s'il existe
if os.path.exists(".env"):
    with open(".env", "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, val = line.split("=", 1)
                os.environ[key.strip()] = val.strip()

# Imports base de données
import models
import schemas
import crud
from database import engine, get_db
from analyzer import analyze_emotion

# Initialisation des tables de la base de données
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="MoodFace AI API")

# Configuration CORS pour permettre à Flutter de communiquer avec l'API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dossier temporaire pour stocker les images reçues
UPLOAD_DIR = "temp_uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.get("/")
async def root():
    return {
        "message": "Bienvenue sur l'API MoodFace AI",
        "status": "Online",
        "docs": "/docs"
    }

# 1. Endpoint d'Inscription
@app.post("/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Cet email est déjà enregistré.")
    return crud.create_user(db=db, user=user)

# 2. Endpoint de Connexion (Authentification simple)
@app.post("/login")
def login_user(user_login: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user_login.email)
    if not db_user:
        raise HTTPException(status_code=400, detail="Ce compte n'existe pas. Il n'y a pas d'adresse email avec ce nom.")
    if not crud.verify_password(user_login.password, db_user.hashed_password):
        raise HTTPException(status_code=400, detail="Mot de passe incorrect.")
    return {"status": "success", "user": {"id": db_user.id, "name": db_user.name, "email": db_user.email}}

# 2.5 Endpoint de Mise à Jour de l'Utilisateur
@app.put("/users/{user_id}", response_model=schemas.UserResponse)
def update_user(user_id: int, user_update: schemas.UserUpdate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_id(db, user_id=user_id)
    if not db_user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé.")
    
    # Vérifier si l'email est déjà pris par un autre utilisateur
    existing_user = crud.get_user_by_email(db, email=user_update.email)
    if existing_user and existing_user.id != user_id:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé par un autre compte.")
        
    updated = crud.update_user(db=db, user_id=user_id, name=user_update.name, email=user_update.email)
    return updated

@app.put("/users/{user_id}/change-password")
def change_password(user_id: int, pwd_update: schemas.PasswordUpdate, db: Session = Depends(get_db)):
    success = crud.change_user_password(
        db=db,
        user_id=user_id,
        old_password=pwd_update.old_password,
        new_password=pwd_update.new_password
    )
    if not success:
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect ou utilisateur introuvable.")
    return {"status": "success", "message": "Mot de passe mis à jour avec succès."}

# Envoi de l'email de réinitialisation de mot de passe (avec simulation locale si SMTP non configuré)
def send_reset_email(to_email: str, reset_link: str) -> bool:
    import smtplib
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart
    
    SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
    
    subject = "MoodFace - Réinitialisation de votre mot de passe"
    body = f"Bonjour,\n\nVous avez demandé la réinitialisation de votre mot de passe sur MoodFace.\n\nVeuillez cliquer sur le lien suivant (ou le copier-coller dans votre navigateur) pour choisir un nouveau mot de passe :\n\n{reset_link}\n\nCe lien expire dans 15 minutes.\n\nL'équipe MoodFace."
    
    html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Réinitialisation de votre mot de passe</title>
  <style>
    body {{
      font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
      background-color: #f6f9fc;
      margin: 0;
      padding: 0;
      -webkit-font-smoothing: antialiased;
    }}
    .wrapper {{
      width: 100%;
      background-color: #f6f9fc;
      padding: 40px 20px;
      box-sizing: border-box;
    }}
    .container {{
      max-width: 500px;
      background-color: #ffffff;
      margin: 0 auto;
      border-radius: 16px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
      overflow: hidden;
      border: 1px solid #eef2f5;
    }}
    .header {{
      background: linear-gradient(135deg, #4A148C 0%, #9C27B0 100%);
      padding: 30px 20px;
      text-align: center;
    }}
    .header h1 {{
      color: #ffffff;
      margin: 0;
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.5px;
    }}
    .content {{
      padding: 40px 30px;
      color: #333333;
      line-height: 1.6;
    }}
    .content p {{
      font-size: 16px;
      margin-top: 0;
      margin-bottom: 24px;
      color: #4a5568;
    }}
    .btn-container {{
      text-align: center;
      margin: 35px 0;
    }}
    .btn {{
      display: inline-block;
      padding: 14px 30px;
      background: linear-gradient(135deg, #9C27B0 0%, #7B1FA2 100%);
      color: #ffffff !important;
      text-decoration: none;
      border-radius: 12px;
      font-weight: bold;
      font-size: 16px;
      box-shadow: 0 4px 10px rgba(156, 39, 176, 0.3);
    }}
    .action-text {{
      font-size: 14px;
      color: #718096;
      margin-bottom: 10px;
    }}
    .link-text {{
      word-break: break-all;
      font-size: 14px;
      color: #9C27B0;
      margin-bottom: 24px;
    }}
    .link-text a {{
      color: #9C27B0;
      text-decoration: none;
    }}
    .footer {{
      background-color: #fafbfc;
      padding: 24px 30px;
      text-align: center;
      border-top: 1px solid #eef2f5;
    }}
    .footer p {{
      font-size: 12px;
      color: #a0aec0;
      margin: 0;
    }}
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="container">
      <div class="header">
        <h1>MoodFace</h1>
      </div>
      <div class="content">
        <p>Bonjour,</p>
        <p>Vous avez demandé la réinitialisation de votre mot de passe sur l'application MoodFace. Veuillez cliquer sur le bouton ci-dessous pour choisir un nouveau mot de passe :</p>
        
        <div class="btn-container">
          <a href="{reset_link}" class="btn">Réinitialiser le mot de passe</a>
        </div>
        
        <p class="action-text">Si le bouton ne fonctionne pas, copiez-collez le lien suivant dans votre navigateur :</p>
        <p class="link-text"><a href="{reset_link}">{reset_link}</a></p>
        
        <p class="action-text">Ce lien est valable pendant 15 minutes. Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet e-mail en toute sécurité.</p>
      </div>
      <div class="footer">
        <p>&copy; 2026 MoodFace AI. Tous droits réservés.</p>
      </div>
    </div>
  </div>
</body>
</html>"""

    is_placeholder = not SMTP_USERNAME or not SMTP_PASSWORD or "votre_adresse_gmail" in SMTP_USERNAME or "votre_mot_de_passe" in SMTP_PASSWORD
    if is_placeholder:
        print("\n=== [SIMULATION ENVOI EMAIL] ===")
        print(f"Destinataire : {to_email}")
        print(f"Sujet : {subject}")
        print(f"Contenu :\n{body}")
        print("=================================\n")
        return True

    try:
        msg = MIMEMultipart('alternative')
        msg['From'] = SMTP_USERNAME
        msg['To'] = to_email
        msg['Subject'] = subject
        
        part1 = MIMEText(body, 'plain', 'utf-8')
        part2 = MIMEText(html_content, 'html', 'utf-8')
        msg.attach(part1)
        msg.attach(part2)

        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.sendmail(SMTP_USERNAME, to_email, msg.as_string())
        server.quit()
        return True
    except Exception as e:
        print(f"Erreur d'envoi d'email: {e}")
        print(f"\n=== [FALLBACK SIMULATION ENVOI EMAIL] ===")
        print(f"Destinataire : {to_email}")
        print(f"Lien de réinitialisation : {reset_link}")
        print("=========================================\n")
        return False

@app.post("/forgot-password")
def forgot_password(request: schemas.ForgotPasswordRequest, fastapi_request: Request, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=request.email)
    if not db_user:
        raise HTTPException(status_code=404, detail="Aucun compte n'est associé à cette adresse e-mail.")
    
    import secrets
    from datetime import datetime, timedelta
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(minutes=15)
    
    crud.set_user_reset_token(db=db, user_id=db_user.id, token=token, expires_at=expires_at)
    
    base_url = str(fastapi_request.base_url).rstrip('/')
    reset_link = f"{base_url}/reset-password?token={token}"
    email_sent = send_reset_email(db_user.email, reset_link)
    
    smtp_username = os.getenv("SMTP_USERNAME", "")
    smtp_password = os.getenv("SMTP_PASSWORD", "")
    is_placeholder = not smtp_username or not smtp_password or "votre_adresse_gmail" in smtp_username or "votre_mot_de_passe" in smtp_password
    is_simulation = is_placeholder or not email_sent

    response_data = {
        "status": "success",
        "message": "Un lien de réinitialisation a été envoyé par e-mail." if (email_sent and not is_simulation) else "Lien de réinitialisation généré (mode simulation)."
    }
    if is_simulation:
        response_data["reset_link"] = reset_link
        
    return response_data

@app.get("/reset-password", response_class=HTMLResponse)
def reset_password_form(token: str, db: Session = Depends(get_db)):
    from datetime import datetime
    db_user = crud.get_user_by_reset_token(db, token=token)
    if not db_user or not db_user.reset_token_expires or db_user.reset_token_expires < datetime.utcnow():
        error_html = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Erreur - MoodFace</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; }
        .card { background: white; padding: 45px 35px; border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 400px; width: 100%; box-sizing: border-box; }
        h2 { color: #D32F2F; margin-top: 0; margin-bottom: 10px; font-weight: 800; }
        p { color: #666; margin-bottom: 30px; font-size: 15px; line-height: 1.5; }
        .icon { font-size: 48px; color: #D32F2F; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">⚠️</div>
        <h2>Lien invalide ou expiré</h2>
        <p>Ce lien de réinitialisation est invalide, a déjà été utilisé ou a expiré (validité de 15 minutes). Veuillez refaire une demande depuis l'application.</p>
    </div>
</body>
</html>"""
        return HTMLResponse(content=error_html, status_code=400)
        
    form_html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nouveau mot de passe - MoodFace</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; box-sizing: border-box; }}
        .card {{ background: white; padding: 40px 30px; border-radius: 24px; box-shadow: 0 10px 35px rgba(0,0,0,0.05); max-width: 400px; width: 100%; box-sizing: border-box; }}
        h2 {{ color: #4A148C; margin-top: 0; margin-bottom: 10px; font-weight: 800; }}
        p {{ color: #666; margin-bottom: 30px; font-size: 15px; }}
        .form-group {{ text-align: left; margin-bottom: 20px; }}
        label {{ display: block; margin-bottom: 8px; font-weight: 600; color: #4A148C; font-size: 14px; }}
        input[type="password"] {{ width: 100%; padding: 14px 16px; border: 1px solid #e2e8f0; border-radius: 12px; font-size: 15px; box-sizing: border-box; background-color: #f8fafc; transition: all 0.2s; }}
        input[type="password"]:focus {{ outline: none; border-color: #9C27B0; background-color: white; box-shadow: 0 0 0 3px rgba(156, 39, 176, 0.15); }}
        .btn {{ display: block; width: 100%; padding: 14px; background: linear-gradient(135deg, #9C27B0 0%, #7B1FA2 100%); color: white; border: none; border-radius: 12px; font-weight: bold; font-size: 16px; cursor: pointer; box-shadow: 0 5px 15px rgba(156, 39, 176, 0.3); transition: all 0.2s; }}
        .btn:hover {{ transform: translateY(-1px); box-shadow: 0 7px 18px rgba(156, 39, 176, 0.4); }}
        .error-msg {{ color: #d32f2f; font-size: 13px; margin-top: 5px; display: none; }}
    </style>
</head>
<body>
    <div class="card">
        <h2>MoodFace</h2>
        <p>Définissez votre nouveau mot de passe ci-dessous.</p>
        <form action="/reset-password" method="POST" onsubmit="return validateForm()">
            <input type="hidden" name="token" value="{token}">
            <div class="form-group">
                <label for="password">Nouveau mot de passe</label>
                <input type="password" id="password" name="password" required minlength="6">
            </div>
            <div class="form-group">
                <label for="confirm_password">Confirmer le mot de passe</label>
                <input type="password" id="confirm_password" name="confirm_password" required minlength="6">
                <div id="error" class="error-msg">Les mots de passe ne correspondent pas.</div>
            </div>
            <button type="submit" class="btn">Enregistrer</button>
        </form>
    </div>
    <script>
        function validateForm() {{
            var pwd = document.getElementById("password").value;
            var conf = document.getElementById("confirm_password").value;
            var err = document.getElementById("error");
            if (pwd !== conf) {{
                err.style.display = "block";
                return false;
            }}
            err.style.display = "none";
            return true;
        }}
    </script>
</body>
</html>"""
    return HTMLResponse(content=form_html)

@app.post("/reset-password", response_class=HTMLResponse)
def handle_reset_password(
    token: str = Form(...), 
    password: str = Form(...), 
    confirm_password: str = Form(...), 
    db: Session = Depends(get_db)
):
    from datetime import datetime
    if password != confirm_password:
        return HTMLResponse(content="""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Erreur - MoodFace</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; }
        .card { background: white; padding: 45px 35px; border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 400px; width: 100%; box-sizing: border-box; }
        h2 { color: #D32F2F; margin-top: 0; margin-bottom: 10px; font-weight: 800; }
        p { color: #666; margin-bottom: 30px; font-size: 15px; line-height: 1.5; }
        .icon { font-size: 48px; color: #D32F2F; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">⚠️</div>
        <h2>Erreur</h2>
        <p>Les mots de passe ne correspondent pas. Veuillez faire retour et réessayer.</p>
    </div>
</body>
</html>""", status_code=400)

    db_user = crud.get_user_by_reset_token(db, token=token)
    if not db_user or not db_user.reset_token_expires or db_user.reset_token_expires < datetime.utcnow():
        return HTMLResponse(content="""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Erreur - MoodFace</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; }
        .card { background: white; padding: 45px 35px; border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 400px; width: 100%; box-sizing: border-box; }
        h2 { color: #D32F2F; margin-top: 0; margin-bottom: 10px; font-weight: 800; }
        p { color: #666; margin-bottom: 30px; font-size: 15px; line-height: 1.5; }
        .icon { font-size: 48px; color: #D32F2F; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">⚠️</div>
        <h2>Lien invalide ou expiré</h2>
        <p>Ce lien de réinitialisation est invalide ou a expiré.</p>
    </div>
</body>
</html>""", status_code=400)

    crud.reset_password_with_token(db=db, user_id=db_user.id, new_password=password)
    
    success_html = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mot de passe mis à jour - MoodFace</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; }
        .card { background: white; padding: 45px 35px; border-radius: 24px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 400px; width: 100%; box-sizing: border-box; }
        h2 { color: #2E7D32; margin-top: 0; margin-bottom: 10px; font-weight: 800; }
        p { color: #666; margin-bottom: 30px; font-size: 15px; line-height: 1.5; }
        .icon { font-size: 48px; color: #2E7D32; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">✅</div>
        <h2>Mot de passe mis à jour !</h2>
        <p>Votre mot de passe a été modifié avec succès. Vous pouvez maintenant fermer cette page et vous connecter sur l'application MoodFace.</p>
    </div>
</body>
</html>"""
    return HTMLResponse(content=success_html)

def render_social_success_page(db_user, provider_name="Social"):
    html_content = f"""
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Connexion {provider_name} réussie</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
        <style>
            * {{ box-sizing: border-box; }}
            body {{
                font-family: 'Outfit', sans-serif;
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100vh;
                margin: 0;
                background: linear-gradient(135deg, #F3E5F5 0%, #FFFFFF 50%, #EDE7F6 100%);
                padding: 20px;
                overflow: hidden;
                position: relative;
            }}
            
            .bubble {{
                position: absolute;
                border-radius: 50%;
                background: linear-gradient(135deg, rgba(156, 39, 176, 0.1), rgba(233, 30, 99, 0.1));
                filter: blur(40px);
                z-index: 1;
                animation: float 8s ease-in-out infinite;
            }}
            .bubble-1 {{ width: 300px; height: 300px; top: -100px; right: -100px; }}
            .bubble-2 {{ width: 250px; height: 250px; bottom: -50px; left: -50px; animation-delay: -4s; }}
            
            @keyframes float {{
                0%, 100% {{ transform: translateY(0) scale(1); }}
                50% {{ transform: translateY(-20px) scale(1.05); }}
            }}

            .card {{
                background: rgba(255, 255, 255, 0.75);
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
                padding: 40px 30px;
                border-radius: 28px;
                box-shadow: 0 15px 35px rgba(156, 39, 176, 0.08), 0 5px 15px rgba(0, 0, 0, 0.04);
                max-width: 400px;
                width: 100%;
                border: 1px solid rgba(255, 255, 255, 0.6);
                z-index: 2;
                text-align: center;
                transform: translateY(20px);
                opacity: 0;
                animation: slideUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
            }}

            @keyframes slideUp {{
                to {{ transform: translateY(0); opacity: 1; }}
            }}

            .success-checkmark {{
                width: 80px;
                height: 80px;
                margin: 0 auto 24px;
            }}
            .success-checkmark .check-icon {{
                width: 80px;
                height: 80px;
                position: relative;
                border-radius: 50%;
                box-sizing: content-box;
                border: 4px solid rgba(156, 39, 176, 0.2);
            }}
            .success-checkmark .check-icon::after {{
                content: '';
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                width: 72px;
                height: 72px;
                border-radius: 50%;
                background: linear-gradient(135deg, #9C27B0, #E91E63);
                z-index: 1;
                box-shadow: 0 8px 20px rgba(156, 39, 176, 0.3);
                animation: pulse 2s infinite;
            }}
            
            @keyframes pulse {{
                0% {{ box-shadow: 0 8px 20px rgba(156, 39, 176, 0.3), 0 0 0 0 rgba(156, 39, 176, 0.4); }}
                70% {{ box-shadow: 0 8px 20px rgba(156, 39, 176, 0.3), 0 0 0 15px rgba(156, 39, 176, 0); }}
                100% {{ box-shadow: 0 8px 20px rgba(156, 39, 176, 0.3), 0 0 0 0 rgba(156, 39, 176, 0); }}
            }}

            .success-checkmark .check-icon .icon-line {{
                height: 5px;
                background-color: white;
                display: block;
                border-radius: 2px;
                position: absolute;
                z-index: 10;
            }}
            .success-checkmark .check-icon .icon-line.line-tip {{
                width: 15px;
                left: 21px;
                top: 42px;
                transform: rotate(45deg);
                animation: writeTip 0.4s ease-in-out forwards;
            }}
            .success-checkmark .check-icon .icon-line.line-long {{
                width: 30px;
                right: 18px;
                top: 36px;
                transform: rotate(-45deg);
                animation: writeLong 0.4s ease-in-out 0.3s forwards;
                opacity: 0;
            }}

            @keyframes writeTip {{
                0% {{ width: 0; left: 16px; top: 37px; }}
                100% {{ width: 15px; left: 21px; top: 42px; }}
            }}
            @keyframes writeLong {{
                0% {{ width: 0; right: 41px; top: 48px; opacity: 1; }}
                100% {{ width: 30px; right: 18px; top: 36px; opacity: 1; }}
            }}

            h2 {{
                color: #4A148C;
                margin-top: 0;
                margin-bottom: 12px;
                font-weight: 800;
                font-size: 24px;
                letter-spacing: -0.5px;
            }}
            p {{
                color: #5C5A6A;
                margin-bottom: 30px;
                font-size: 15px;
                line-height: 1.6;
            }}
            strong {{
                color: #4A148C;
                font-weight: 600;
            }}
            
            .spinner {{
                display: inline-block;
                width: 20px;
                height: 20px;
                border: 3px solid rgba(156, 39, 176, 0.2);
                border-radius: 50%;
                border-top-color: #9C27B0;
                animation: spin 1s ease-in-out infinite;
                vertical-align: middle;
                margin-right: 8px;
            }}
            @keyframes spin {{
                to {{ transform: rotate(360deg); }}
            }}

            .btn {{
                display: flex;
                align-items: center;
                justify-content: center;
                width: 100%;
                padding: 16px 30px;
                background: linear-gradient(135deg, #9C27B0, #E91E63);
                color: white;
                text-decoration: none;
                border-radius: 18px;
                font-weight: 600;
                font-size: 16px;
                box-shadow: 0 8px 20px rgba(156, 39, 176, 0.25);
                transition: all 0.3s ease;
                border: none;
                cursor: pointer;
            }}
            .btn:hover {{
                transform: translateY(-2px);
                box-shadow: 0 10px 25px rgba(156, 39, 176, 0.35);
            }}
            .btn:active {{
                transform: translateY(0);
            }}
            
            .redirect-notice {{
                margin-top: 18px;
                font-size: 13px;
                color: #8C8A9A;
                display: flex;
                align-items: center;
                justify-content: center;
            }}
        </style>
    </head>
    <body>
        <div class="bubble bubble-1"></div>
        <div class="bubble bubble-2"></div>
        <div class="card">
            <div class="success-checkmark">
                <div class="check-icon">
                    <span class="icon-line line-tip"></span>
                    <span class="icon-line line-long"></span>
                </div>
            </div>
            <h2>Connexion réussie !</h2>
            <p>Bonjour <strong>{db_user.name}</strong>,<br>vous allez être automatiquement redirigé vers l'application MoodFace...</p>
            <a class="btn" href="moodface://auth?status=success&id={db_user.id}&name={db_user.name}&email={db_user.email}">
                Ouvrir l'application
            </a>
            <div class="redirect-notice">
                <div class="spinner"></div>Redirection en cours...
            </div>
        </div>
        <script>
            setTimeout(function() {{
                window.location.href = "moodface://auth?status=success&id={db_user.id}&name={db_user.name}&email={db_user.email}";
            }}, 1500);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

def render_social_error_page(error_title, error_message, back_url):
    html_content = f"""
    <html>
    <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>{error_title}</title>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
        <style>
            * {{ box-sizing: border-box; }}
            body {{
                font-family: 'Outfit', sans-serif;
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100vh;
                margin: 0;
                background: linear-gradient(135deg, #FFEBEE 0%, #FFFFFF 50%, #FCE4EC 100%);
                padding: 20px;
                overflow: hidden;
                position: relative;
            }}
            
            .bubble {{
                position: absolute;
                border-radius: 50%;
                background: linear-gradient(135deg, rgba(211, 47, 47, 0.08), rgba(233, 30, 99, 0.08));
                filter: blur(40px);
                z-index: 1;
                animation: float 8s ease-in-out infinite;
            }}
            .bubble-1 {{ width: 300px; height: 300px; top: -100px; right: -100px; }}
            .bubble-2 {{ width: 250px; height: 250px; bottom: -50px; left: -50px; animation-delay: -4s; }}
            
            @keyframes float {{
                0%, 100% {{ transform: translateY(0) scale(1); }}
                50% {{ transform: translateY(-20px) scale(1.05); }}
            }}

            .card {{
                background: rgba(255, 255, 255, 0.75);
                backdrop-filter: blur(20px);
                -webkit-backdrop-filter: blur(20px);
                padding: 40px 30px;
                border-radius: 28px;
                box-shadow: 0 15px 35px rgba(211, 47, 47, 0.08), 0 5px 15px rgba(0, 0, 0, 0.04);
                max-width: 400px;
                width: 100%;
                border: 1px solid rgba(255, 255, 255, 0.6);
                z-index: 2;
                text-align: center;
                transform: translateY(20px);
                opacity: 0;
                animation: slideUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
            }}

            @keyframes slideUp {{
                to {{ transform: translateY(0); opacity: 1; }}
            }}

            .error-icon-container {{
                width: 80px;
                height: 80px;
                margin: 0 auto 24px;
                position: relative;
                border-radius: 50%;
                border: 4px solid rgba(211, 47, 47, 0.2);
                display: flex;
                align-items: center;
                justify-content: center;
            }}
            .error-icon-container::after {{
                content: '';
                position: absolute;
                width: 72px;
                height: 72px;
                border-radius: 50%;
                background: linear-gradient(135deg, #D32F2F, #FF5252);
                z-index: 1;
                box-shadow: 0 8px 20px rgba(211, 47, 47, 0.3);
                animation: pulse-error 2s infinite;
            }}
            
            @keyframes pulse-error {{
                0% {{ box-shadow: 0 8px 20px rgba(211, 47, 47, 0.3), 0 0 0 0 rgba(211, 47, 47, 0.4); }}
                70% {{ box-shadow: 0 8px 20px rgba(211, 47, 47, 0.3), 0 0 0 15px rgba(211, 47, 47, 0); }}
                100% {{ box-shadow: 0 8px 20px rgba(211, 47, 47, 0.3), 0 0 0 0 rgba(211, 47, 47, 0); }}
            }}

            .error-icon-container span {{
                color: white;
                font-size: 36px;
                font-weight: 800;
                position: relative;
                z-index: 10;
            }}

            h2 {{
                color: #D32F2F;
                margin-top: 0;
                margin-bottom: 12px;
                font-weight: 800;
                font-size: 24px;
                letter-spacing: -0.5px;
            }}
            p {{
                color: #5C5A6A;
                margin-bottom: 30px;
                font-size: 15px;
                line-height: 1.6;
            }}

            .btn {{
                display: block;
                width: 100%;
                padding: 16px 30px;
                background: linear-gradient(135deg, #D32F2F, #FF5252);
                color: white;
                text-decoration: none;
                border-radius: 18px;
                font-weight: 600;
                font-size: 16px;
                box-shadow: 0 8px 20px rgba(211, 47, 47, 0.25);
                transition: all 0.3s ease;
                border: none;
                cursor: pointer;
                text-align: center;
            }}
            .btn:hover {{
                transform: translateY(-2px);
                box-shadow: 0 10px 25px rgba(211, 47, 47, 0.35);
            }}
            .btn:active {{
                transform: translateY(0);
            }}
        </style>
    </head>
    <body>
        <div class="bubble bubble-1"></div>
        <div class="bubble bubble-2"></div>
        <div class="card">
            <div class="error-icon-container">
                <span>!</span>
            </div>
            <h2>{error_title}</h2>
            <p>{error_message}</p>
            <a class="btn" href="{back_url}">
                Réessayer
            </a>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=400)

def get_redirect_uri(request: Request, provider: str) -> str:
    import re
    base_url = str(request.base_url).rstrip('/')
    is_local = "localhost" in base_url or "127.0.0.1" in base_url or re.search(r'192\.168\.\d+\.\d+', base_url) or re.search(r'10\.\d+\.\d+\.\d+', base_url)
    if not is_local:
        base_url = base_url.replace("http://", "https://")
    return f"{base_url}/auth/{provider}/callback"

@app.get("/auth/check-email")
def check_email(email: str, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=email)
    if db_user:
        return {"exists": True, "name": db_user.name}
    return {"exists": False}

@app.get("/auth/check-google-account")
def check_google_account(email: str, db: Session = Depends(get_db)):
    email_clean = email.strip().lower()
    if not email_clean or "@" not in email_clean:
        return {"exists_in_google": False, "message": "Format d'adresse e-mail invalide."}
    
    parts = email_clean.split("@")
    domain = parts[1]
    username = parts[0]
    
    is_google_domain = domain in ["gmail.com", "googlemail.com"]
    
    google_exists = False
    if is_google_domain and len(username) >= 3:
        google_exists = True
    else:
        import urllib.request
        import urllib.error
        try:
            url = f"https://accounts.google.com/.well-known/webfinger?resource=acct:{email_clean}"
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                if resp.status == 200:
                    google_exists = True
        except Exception:
            # En mode simulation, si l'appel webfinger échoue ou renvoie 404, 
            # on accepte quand même l'adresse e-mail pour ne pas bloquer l'utilisateur.
            google_exists = True

    if not google_exists:
        return {
            "exists_in_google": False,
            "message": "Impossible de trouver votre compte Google. Cette adresse e-mail n'existe pas dans le service de Google."
        }

    db_user = crud.get_user_by_email(db, email=email_clean)
    return {
        "exists_in_google": True,
        "exists_in_db": db_user is not None,
        "name": db_user.name if db_user else "Utilisateur Google"
    }

# --- GOOGLE AUTHENTICATION ---
def exchange_google_code(code: str, redirect_uri: str):
    import urllib.request
    import urllib.parse
    import json
    
    client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    client_secret = os.getenv("GOOGLE_CLIENT_SECRET", "")
    
    token_url = "https://oauth2.googleapis.com/token"
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "code": code,
        "grant_type": "authorization_code",
        "redirect_uri": redirect_uri
    }).encode("utf-8")
    
    req = urllib.request.Request(token_url, data=data, headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode("utf-8"))
        access_token = res_data.get("access_token")
        
    if not access_token:
        raise Exception("Impossible d'obtenir l'access token de Google.")
        
    user_url = "https://www.googleapis.com/oauth2/v2/userinfo"
    req_user = urllib.request.Request(user_url, headers={"Authorization": f"Bearer {access_token}"})
    with urllib.request.urlopen(req_user) as response_user:
        user_profile = json.loads(response_user.read().decode("utf-8"))
        
    return {
        "name": user_profile.get("name") or "Google User",
        "email": user_profile.get("email")
    }

@app.get("/auth/google")
def auth_google(request: Request, email: str = None):
    client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    if not client_id or client_id == "votre_client_id_google":
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Connexion avec Google - MoodFace Portal</title>
            <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: 'Outfit', sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #F3E5F5 0%, #FFFFFF 50%, #EDE7F6 100%);
                    padding: 20px;
                    overflow-y: auto;
                    position: relative;
                }
                .bubble {
                    position: absolute;
                    border-radius: 50%;
                    background: linear-gradient(135deg, rgba(156, 39, 176, 0.08), rgba(233, 30, 99, 0.08));
                    filter: blur(40px);
                    z-index: 1;
                    animation: float 8s ease-in-out infinite;
                }
                .bubble-1 { width: 300px; height: 300px; top: -100px; right: -100px; }
                .bubble-2 { width: 250px; height: 250px; bottom: -50px; left: -50px; animation-delay: -4s; }
                
                @keyframes float {
                    0%, 100% { transform: translateY(0) scale(1); }
                    50% { transform: translateY(-20px) scale(1.05); }
                }

                .card {
                    background: rgba(255, 255, 255, 0.75);
                    backdrop-filter: blur(20px);
                    -webkit-backdrop-filter: blur(20px);
                    padding: 40px 30px;
                    border-radius: 28px;
                    box-shadow: 0 15px 35px rgba(156, 39, 176, 0.08), 0 5px 15px rgba(0, 0, 0, 0.04);
                    max-width: 400px;
                    width: 100%;
                    border: 1px solid rgba(255, 255, 255, 0.6);
                    z-index: 2;
                    text-align: center;
                }
                .google-icon { width: 48px; height: 48px; margin-bottom: 20px; }
                h2 {
                    color: #4A148C;
                    margin-top: 0;
                    margin-bottom: 8px;
                    font-weight: 800;
                    font-size: 24px;
                    letter-spacing: -0.5px;
                }
                p {
                    color: #5C5A6A;
                    margin-bottom: 25px;
                    font-size: 14px;
                    line-height: 1.5;
                }
                .form-group { text-align: left; margin-bottom: 18px; }
                label {
                    display: block;
                    margin-bottom: 6px;
                    font-weight: 600;
                    color: #4A148C;
                    font-size: 13px;
                }
                input[type="email"], input[type="text"], input[type="password"] {
                    width: 100%;
                    padding: 14px 16px;
                    border: 1px solid #E2E8F0;
                    border-radius: 12px;
                    font-size: 14px;
                    box-sizing: border-box;
                    background-color: white;
                    transition: all 0.3s ease;
                    font-family: inherit;
                }
                input[type="email"]:focus, input[type="text"]:focus, input[type="password"]:focus {
                    outline: none;
                    border-color: #9C27B0;
                    box-shadow: 0 0 0 3px rgba(156, 39, 176, 0.15);
                }
                .btn {
                    display: block;
                    width: 100%;
                    padding: 14px;
                    background: linear-gradient(135deg, #9C27B0, #E91E63);
                    color: white;
                    border: none;
                    border-radius: 14px;
                    font-weight: 600;
                    font-size: 15px;
                    cursor: pointer;
                    box-shadow: 0 8px 20px rgba(156, 39, 176, 0.2);
                    transition: all 0.3s ease;
                }
                .btn:hover {
                    transform: translateY(-1px);
                    box-shadow: 0 10px 22px rgba(156, 39, 176, 0.3);
                }
                .btn:active {
                    transform: translateY(0);
                }
                .error-banner {
                    display: none;
                    color: #d93025;
                    background-color: #fce8e6;
                    border-radius: 10px;
                    padding: 12px;
                    font-size: 13px;
                    margin-bottom: 18px;
                    text-align: left;
                    border: 1px solid #fad2cf;
                    line-height: 1.4;
                }
                .step-2 { display: none; }
            </style>
        </head>
        <body>
            <div class="bubble bubble-1"></div>
            <div class="bubble bubble-2"></div>
            <div class="card">
                <svg class="google-icon" viewBox="0 0 48 48">
                    <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.66 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
                    <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
                    <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24s.92 7.54 2.56 10.78l7.97-6.19z"/>
                    <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.66 48 24 48z"/>
                </svg>
                <h2>Connexion avec Google</h2>
                <p id="subtitle">Saisissez votre e-mail pour continuer</p>
                <div id="errorBanner" class="error-banner"></div>
                <form id="loginForm" action="/auth/google/simulate" method="POST">
                    <div id="step1">
                        <div class="form-group">
                            <label for="email">Adresse e-mail Google</label>
                            <input type="email" id="email" name="email" placeholder="nom@gmail.com" required>
                        </div>
                        <button type="button" class="btn" onclick="checkEmail()">Suivant</button>
                    </div>
                    <div id="step2" class="step-2">
                        <div class="form-group" id="nameGroup" style="display: none;">
                            <label for="name">Nom complet</label>
                            <input type="text" id="name" name="name" value="Utilisateur Google" required>
                        </div>
                        <div class="form-group">
                            <label for="password">Mot de passe</label>
                            <input type="password" id="password" name="password" placeholder="••••••••" required minlength="6">
                        </div>
                        <button type="submit" class="btn" id="submitBtn">Se connecter avec Google</button>
                    </div>
                </form>
            </div>
            <script>
                async function checkEmail() {
                    const emailInput = document.getElementById("email");
                    const errorBanner = document.getElementById("errorBanner");
                    const email = emailInput.value.trim();
                    errorBanner.style.display = "none";
                    if (!email) {
                        errorBanner.textContent = "Veuillez saisir une adresse e-mail.";
                        errorBanner.style.display = "block";
                        return;
                    }
                    // Valider le format de l'e-mail avec une expression régulière
                    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                    if (!emailRegex.test(email)) {
                        errorBanner.textContent = "Format d'adresse e-mail invalide.";
                        errorBanner.style.display = "block";
                        return;
                    }
                    try {
                        const res = await fetch("/auth/check-google-account?email=" + encodeURIComponent(email));
                        const data = await res.json();
                        if (data.exists_in_google) {
                            if (data.exists_in_db) {
                                document.getElementById("name").value = data.name || "Utilisateur Google";
                                document.getElementById("nameGroup").style.display = "none";
                                document.getElementById("subtitle").textContent = "Saisissez votre mot de passe pour vous connecter";
                                document.getElementById("submitBtn").textContent = "Se connecter avec Google";
                            } else {
                                document.getElementById("name").value = "Utilisateur Google";
                                document.getElementById("nameGroup").style.display = "block";
                                document.getElementById("subtitle").textContent = "Créez votre compte sur MoodFace";
                                document.getElementById("submitBtn").textContent = "Créer un compte avec Google";
                            }
                            document.getElementById("step1").style.display = "none";
                            document.getElementById("step2").style.display = "block";
                        } else {
                            errorBanner.textContent = data.message || "Ce compte Google n'existe pas.";
                            errorBanner.style.display = "block";
                        }
                    } catch (err) {
                        errorBanner.textContent = "Erreur lors de la vérification de l'adresse e-mail.";
                        errorBanner.style.display = "block";
                    }
                }
                window.onload = function() {
                    const emailInput = document.getElementById("email");
                    if (emailInput && emailInput.value.trim() !== "") {
                        checkEmail();
                    }
                };
            </script>
        </body>
        </html>
        """
        if email:
            email_val = email.strip()
            html_content = html_content.replace(
                'id="email" name="email" placeholder="nom@gmail.com"',
                f'id="email" name="email" value="{email_val}" placeholder="nom@gmail.com"'
            )
        return HTMLResponse(content=html_content)

    redirect_uri = get_redirect_uri(request, "google")
    url = f"https://accounts.google.com/o/oauth2/v2/auth?client_id={client_id}&response_type=code&scope=openid%20email%20profile&redirect_uri={redirect_uri}"
    return RedirectResponse(url=url)

@app.post("/auth/google/simulate")
def auth_google_simulate(name: str = Form(...), email: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    import re
    import urllib.parse
    email_clean = email.strip().lower()
    
    # 1. Vérifier la validité de l'adresse email
    if not email_clean or not re.match(r'^[^@]+@[^\s@]+\.[^\s@]+$', email_clean):
        return render_social_error_page(
            "Adresse e-mail invalide",
            "Le format de l'adresse e-mail Google saisie est incorrect.",
            "/auth/google"
        )
        
    # 2. Vérifier la validité du mot de passe (longueur minimale)
    if not password or len(password) < 6:
        return render_social_error_page(
            "Mot de passe invalide",
            "Le mot de passe doit contenir au moins 6 caractères.",
            f"/auth/google?email={urllib.parse.quote(email_clean)}"
        )
        
    db_user = crud.get_user_by_email(db, email=email_clean)
    if db_user:
        # L'utilisateur existe déjà, on doit vérifier le mot de passe pour la sécurité
        if not crud.verify_password(password, db_user.hashed_password):
            return render_social_error_page(
                "Mot de passe incorrect",
                "Le mot de passe que vous avez saisi pour cette adresse e-mail Google est incorrect.",
                f"/auth/google?email={urllib.parse.quote(email_clean)}"
            )
    else:
        # L'utilisateur n'existe pas encore, on crée un nouveau compte avec ce mot de passe
        user_create = schemas.UserCreate(name=name or "Utilisateur Google", email=email_clean, password=password)
        db_user = crud.create_user(db, user=user_create)
        
    return render_social_success_page(db_user, "Google")

@app.get("/auth/google/callback")
def auth_google_callback(code: str, request: Request, db: Session = Depends(get_db)):
    try:
        redirect_uri = get_redirect_uri(request, "google")
        user_info = exchange_google_code(code, redirect_uri)
        email = user_info["email"]
        name = user_info["name"]
        
        db_user = crud.get_user_by_email(db, email=email)
        if not db_user:
            import secrets
            random_password = secrets.token_urlsafe(16)
            user_create = schemas.UserCreate(name=name, email=email, password=random_password)
            db_user = crud.create_user(db, user=user_create)
            
        return render_social_success_page(db_user, "Google")
    except Exception as e:
        return HTMLResponse(content=f"<h2>Erreur Google OAuth</h2><p>{e}</p>", status_code=500)


# --- FACEBOOK AUTHENTICATION ---
def exchange_facebook_code(code: str, redirect_uri: str):
    import urllib.request
    import urllib.parse
    import json
    
    client_id = os.getenv("FACEBOOK_CLIENT_ID", "")
    client_secret = os.getenv("FACEBOOK_CLIENT_SECRET", "")
    
    token_url = f"https://graph.facebook.com/v12.0/oauth/access_token?client_id={client_id}&redirect_uri={redirect_uri}&client_secret={client_secret}&code={code}"
    
    req = urllib.request.Request(token_url)
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode("utf-8"))
        access_token = res_data.get("access_token")
        
    if not access_token:
        raise Exception("Impossible d'obtenir l'access token de Facebook.")
        
    user_url = f"https://graph.facebook.com/me?fields=id,name,email&access_token={access_token}"
    req_user = urllib.request.Request(user_url)
    with urllib.request.urlopen(req_user) as response_user:
        user_profile = json.loads(response_user.read().decode("utf-8"))
        
    return {
        "name": user_profile.get("name") or "Facebook User",
        "email": user_profile.get("email") or f"{user_profile.get('id')}@facebook.com"
    }

@app.get("/auth/facebook")
def auth_facebook(request: Request, email: str = None):
    client_id = os.getenv("FACEBOOK_CLIENT_ID", "")
    if not client_id or client_id == "votre_client_id_facebook":
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Connexion avec Facebook - MoodFace Portal</title>
            <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: 'Outfit', sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #E3F2FD 0%, #FFFFFF 50%, #ECEFF1 100%);
                    padding: 20px;
                    overflow-y: auto;
                    position: relative;
                }
                .bubble {
                    position: absolute;
                    border-radius: 50%;
                    background: linear-gradient(135deg, rgba(24, 119, 242, 0.08), rgba(30, 136, 229, 0.08));
                    filter: blur(40px);
                    z-index: 1;
                    animation: float 8s ease-in-out infinite;
                }
                .bubble-1 { width: 300px; height: 300px; top: -100px; right: -100px; }
                .bubble-2 { width: 250px; height: 250px; bottom: -50px; left: -50px; animation-delay: -4s; }
                
                @keyframes float {
                    0%, 100% { transform: translateY(0) scale(1); }
                    50% { transform: translateY(-20px) scale(1.05); }
                }

                .card {
                    background: rgba(255, 255, 255, 0.75);
                    backdrop-filter: blur(20px);
                    -webkit-backdrop-filter: blur(20px);
                    padding: 40px 30px;
                    border-radius: 28px;
                    box-shadow: 0 15px 35px rgba(24, 119, 242, 0.08), 0 5px 15px rgba(0, 0, 0, 0.04);
                    max-width: 400px;
                    width: 100%;
                    border: 1px solid rgba(255, 255, 255, 0.6);
                    z-index: 2;
                    text-align: center;
                }
                .fb-icon { width: 48px; height: 48px; margin-bottom: 20px; fill: #1877f2; }
                h2 {
                    color: #0d47a1;
                    margin-top: 0;
                    margin-bottom: 8px;
                    font-weight: 800;
                    font-size: 24px;
                    letter-spacing: -0.5px;
                }
                p {
                    color: #5C5A6A;
                    margin-bottom: 25px;
                    font-size: 14px;
                    line-height: 1.5;
                }
                .form-group { text-align: left; margin-bottom: 18px; }
                label {
                    display: block;
                    margin-bottom: 6px;
                    font-weight: 600;
                    color: #0d47a1;
                    font-size: 13px;
                }
                input[type="email"], input[type="text"], input[type="password"] {
                    width: 100%;
                    padding: 14px 16px;
                    border: 1px solid #E2E8F0;
                    border-radius: 12px;
                    font-size: 14px;
                    box-sizing: border-box;
                    background-color: white;
                    transition: all 0.3s ease;
                    font-family: inherit;
                }
                input[type="email"]:focus, input[type="text"]:focus, input[type="password"]:focus {
                    outline: none;
                    border-color: #1877f2;
                    box-shadow: 0 0 0 3px rgba(24, 119, 242, 0.15);
                }
                .btn {
                    display: block;
                    width: 100%;
                    padding: 14px;
                    background: linear-gradient(135deg, #1877f2, #1565c0);
                    color: white;
                    border: none;
                    border-radius: 14px;
                    font-weight: 600;
                    font-size: 15px;
                    cursor: pointer;
                    box-shadow: 0 8px 20px rgba(24, 119, 242, 0.2);
                    transition: all 0.3s ease;
                }
                .btn:hover {
                    transform: translateY(-1px);
                    box-shadow: 0 10px 22px rgba(24, 119, 242, 0.3);
                }
                .btn:active {
                    transform: translateY(0);
                }
                .error-banner {
                    display: none;
                    color: #d93025;
                    background-color: #fce8e6;
                    border-radius: 10px;
                    padding: 12px;
                    font-size: 13px;
                    margin-bottom: 18px;
                    text-align: left;
                    border: 1px solid #fad2cf;
                    line-height: 1.4;
                }
                .step-2 { display: none; }
            </style>
        </head>
        <body>
            <div class="bubble bubble-1"></div>
            <div class="bubble bubble-2"></div>
            <div class="card">
                <svg class="fb-icon" viewBox="0 0 24 24">
                    <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
                </svg>
                <h2>Connexion avec Facebook</h2>
                <p id="subtitle">Saisissez votre e-mail pour continuer</p>
                <div id="errorBanner" class="error-banner"></div>
                <form id="loginForm" action="/auth/facebook/simulate" method="POST">
                    <div id="step1">
                        <div class="form-group">
                            <label for="email">Adresse e-mail Facebook</label>
                            <input type="email" id="email" name="email" placeholder="nom@exemple.com" required>
                        </div>
                        <button type="button" class="btn" onclick="checkEmail()">Suivant</button>
                    </div>
                    <div id="step2" class="step-2">
                        <div class="form-group" id="nameGroup" style="display: none;">
                            <label for="name">Nom complet</label>
                            <input type="text" id="name" name="name" value="Utilisateur Facebook" required>
                        </div>
                        <div class="form-group">
                            <label for="password">Mot de passe</label>
                            <input type="password" id="password" name="password" placeholder="••••••••" required minlength="6">
                        </div>
                        <button type="submit" class="btn" id="submitBtn">Se connecter avec Facebook</button>
                    </div>
                </form>
            </div>
            <script>
                async function checkEmail() {
                    const emailInput = document.getElementById("email");
                    const errorBanner = document.getElementById("errorBanner");
                    const email = emailInput.value.trim();
                    errorBanner.style.display = "none";
                    if (!email) {
                        errorBanner.textContent = "Veuillez saisir une adresse e-mail.";
                        errorBanner.style.display = "block";
                        return;
                    }
                    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                    if (!emailRegex.test(email)) {
                        errorBanner.textContent = "Format d'adresse e-mail invalide.";
                        errorBanner.style.display = "block";
                        return;
                    }
                    try {
                        const res = await fetch("/auth/check-email?email=" + encodeURIComponent(email));
                        const data = await res.json();
                        if (data.exists) {
                            document.getElementById("name").value = data.name || "Utilisateur Facebook";
                            document.getElementById("nameGroup").style.display = "none";
                            document.getElementById("subtitle").textContent = "Saisissez votre mot de passe pour vous connecter";
                            document.getElementById("submitBtn").textContent = "Se connecter avec Facebook";
                        } else {
                            document.getElementById("name").value = "Utilisateur Facebook";
                            document.getElementById("nameGroup").style.display = "block";
                            document.getElementById("subtitle").textContent = "Créez votre compte sur MoodFace";
                            document.getElementById("submitBtn").textContent = "Créer un compte avec Facebook";
                        }
                        document.getElementById("step1").style.display = "none";
                        document.getElementById("step2").style.display = "block";
                    } catch (err) {
                        errorBanner.textContent = "Erreur lors de la vérification de l'adresse e-mail.";
                        errorBanner.style.display = "block";
                    }
                }
                window.onload = function() {
                    const emailInput = document.getElementById("email");
                    if (emailInput && emailInput.value.trim() !== "") {
                        checkEmail();
                    }
                };
            </script>
        </body>
        </html>
        """
        if email:
            email_val = email.strip()
            html_content = html_content.replace(
                'id="email" name="email" placeholder="nom@exemple.com"',
                f'id="email" name="email" value="{email_val}" placeholder="nom@exemple.com"'
            )
        return HTMLResponse(content=html_content)

    redirect_uri = get_redirect_uri(request, "facebook")
    url = f"https://www.facebook.com/v12.0/dialog/oauth?client_id={client_id}&redirect_uri={redirect_uri}&scope=email,public_profile"
    return RedirectResponse(url=url)

@app.post("/auth/facebook/simulate")
def auth_facebook_simulate(name: str = Form(...), email: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    import re
    import urllib.parse
    email_clean = email.strip().lower()
    
    # 1. Vérifier la validité de l'adresse email
    if not email_clean or not re.match(r'^[^@]+@[^\s@]+\.[^\s@]+$', email_clean):
        return render_social_error_page(
            "Adresse e-mail invalide",
            "Le format de l'adresse e-mail Facebook saisie est incorrect.",
            "/auth/facebook"
        )
        
    # 2. Vérifier la validité du mot de passe (longueur minimale)
    if not password or len(password) < 6:
        return render_social_error_page(
            "Mot de passe invalide",
            "Le mot de passe doit contenir au moins 6 caractères.",
            f"/auth/facebook?email={urllib.parse.quote(email_clean)}"
        )
        
    db_user = crud.get_user_by_email(db, email=email_clean)
    if db_user:
        # L'utilisateur existe déjà, on doit vérifier le mot de passe pour la sécurité
        if not crud.verify_password(password, db_user.hashed_password):
            return render_social_error_page(
                "Mot de passe incorrect",
                "Le mot de passe que vous avez saisi pour cette adresse e-mail Facebook est incorrect.",
                f"/auth/facebook?email={urllib.parse.quote(email_clean)}"
            )
    else:
        # L'utilisateur n'existe pas encore, on crée un nouveau compte avec ce mot de passe
        user_create = schemas.UserCreate(name=name or "Utilisateur Facebook", email=email_clean, password=password)
        db_user = crud.create_user(db, user=user_create)
        
    return render_social_success_page(db_user, "Facebook")

@app.get("/auth/facebook/callback")
def auth_facebook_callback(code: str, request: Request, db: Session = Depends(get_db)):
    try:
        redirect_uri = get_redirect_uri(request, "facebook")
        user_info = exchange_facebook_code(code, redirect_uri)
        email = user_info["email"]
        name = user_info["name"]
        
        db_user = crud.get_user_by_email(db, email=email)
        if not db_user:
            import secrets
            random_password = secrets.token_urlsafe(16)
            user_create = schemas.UserCreate(name=name, email=email, password=random_password)
            db_user = crud.create_user(db, user=user_create)
            
        return render_social_success_page(db_user, "Facebook")
    except Exception as e:
        return HTMLResponse(content=f"<h2>Erreur Facebook OAuth</h2><p>{e}</p>", status_code=500)


# --- GITHUB AUTHENTICATION ---
def exchange_github_code(code: str):
    import urllib.request
    import urllib.parse
    import json
    
    client_id = os.getenv("GITHUB_CLIENT_ID", "")
    client_secret = os.getenv("GITHUB_CLIENT_SECRET", "")
    
    token_url = "https://github.com/login/oauth/access_token"
    data = urllib.parse.urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "code": code
    }).encode("utf-8")
    
    req = urllib.request.Request(token_url, data=data, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req) as response:
        res_data = json.loads(response.read().decode("utf-8"))
        access_token = res_data.get("access_token")
        
    if not access_token:
        raise Exception("Impossible d'obtenir l'access token de GitHub.")
        
    user_url = "https://api.github.com/user"
    req_user = urllib.request.Request(user_url, headers={
        "Authorization": f"token {access_token}",
        "User-Agent": "MoodFace-App"
    })
    with urllib.request.urlopen(req_user) as response_user:
        user_profile = json.loads(response_user.read().decode("utf-8"))
        
    email = user_profile.get("email")
    if not email:
        email_url = "https://api.github.com/user/emails"
        req_email = urllib.request.Request(email_url, headers={
            "Authorization": f"token {access_token}",
            "User-Agent": "MoodFace-App"
        })
        try:
            with urllib.request.urlopen(req_email) as response_email:
                emails = json.loads(response_email.read().decode("utf-8"))
                for e in emails:
                    if e.get("primary") and e.get("verified"):
                        email = e.get("email")
                        break
                if not email and emails:
                    email = emails[0].get("email")
        except Exception:
            pass
                
    return {
        "name": user_profile.get("name") or user_profile.get("login") or "GitHub User",
        "email": email or f"{user_profile.get('login')}@github.com"
    }

@app.get("/auth/github")
def auth_github(request: Request, email: str = None):
    client_id = os.getenv("GITHUB_CLIENT_ID", "")
    if not client_id or client_id == "votre_client_id_github":
        html_content = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Connexion avec GitHub - MoodFace Portal</title>
            <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;800&display=swap" rel="stylesheet">
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: 'Outfit', sans-serif;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    margin: 0;
                    background: linear-gradient(135deg, #0d1117 0%, #161b22 100%);
                    padding: 20px;
                    overflow-y: auto;
                    color: #c9d1d9;
                    position: relative;
                }
                .bubble {
                    position: absolute;
                    border-radius: 50%;
                    background: linear-gradient(135deg, rgba(88, 166, 255, 0.05), rgba(35, 134, 54, 0.05));
                    filter: blur(40px);
                    z-index: 1;
                    animation: float 8s ease-in-out infinite;
                }
                .bubble-1 { width: 300px; height: 300px; top: -100px; right: -100px; }
                .bubble-2 { width: 250px; height: 250px; bottom: -50px; left: -50px; animation-delay: -4s; }
                
                @keyframes float {
                    0%, 100% { transform: translateY(0) scale(1); }
                    50% { transform: translateY(-20px) scale(1.05); }
                }

                .card {
                    background: rgba(22, 27, 34, 0.85);
                    backdrop-filter: blur(20px);
                    -webkit-backdrop-filter: blur(20px);
                    padding: 40px 30px;
                    border-radius: 28px;
                    box-shadow: 0 15px 35px rgba(0, 0, 0, 0.3);
                    max-width: 400px;
                    width: 100%;
                    border: 1px solid rgba(48, 54, 61, 0.6);
                    z-index: 2;
                    text-align: center;
                }
                .github-icon { width: 48px; height: 48px; margin-bottom: 20px; fill: #f0f6fc; }
                h2 {
                    color: #f0f6fc;
                    margin-top: 0;
                    margin-bottom: 8px;
                    font-weight: 800;
                    font-size: 24px;
                    letter-spacing: -0.5px;
                }
                p {
                    color: #8b949e;
                    margin-bottom: 25px;
                    font-size: 14px;
                    line-height: 1.5;
                }
                .form-group { text-align: left; margin-bottom: 18px; }
                label {
                    display: block;
                    margin-bottom: 6px;
                    font-weight: 600;
                    color: #c9d1d9;
                    font-size: 13px;
                }
                input[type="email"], input[type="text"], input[type="password"] {
                    width: 100%;
                    padding: 14px 16px;
                    border: 1px solid #30363d;
                    border-radius: 12px;
                    font-size: 14px;
                    box-sizing: border-box;
                    background-color: #0d1117;
                    color: #c9d1d9;
                    transition: all 0.3s ease;
                    font-family: inherit;
                }
                input[type="email"]:focus, input[type="text"]:focus, input[type="password"]:focus {
                    outline: none;
                    border-color: #58a6ff;
                    box-shadow: 0 0 0 3px rgba(88, 166, 255, 0.15);
                }
                .btn {
                    display: block;
                    width: 100%;
                    padding: 14px;
                    background: linear-gradient(135deg, #238636, #2ea043);
                    color: white;
                    border: none;
                    border-radius: 14px;
                    font-weight: 600;
                    font-size: 15px;
                    cursor: pointer;
                    box-shadow: 0 8px 20px rgba(35, 134, 54, 0.2);
                    transition: all 0.3s ease;
                }
                .btn:hover {
                    transform: translateY(-1px);
                    box-shadow: 0 10px 22px rgba(35, 134, 54, 0.3);
                }
                .btn:active {
                    transform: translateY(0);
                }
                .error-banner {
                    display: none;
                    color: #f85149;
                    background-color: rgba(248, 81, 73, 0.1);
                    border-radius: 10px;
                    padding: 12px;
                    font-size: 13px;
                    margin-bottom: 18px;
                    text-align: left;
                    border: 1px solid rgba(248, 81, 73, 0.4);
                    line-height: 1.4;
                }
                .step-2 { display: none; }
            </style>
        </head>
        <body>
            <div class="bubble bubble-1"></div>
            <div class="bubble bubble-2"></div>
            <div class="card">
                <svg class="github-icon" viewBox="0 0 24 24">
                    <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
                </svg>
                <h2>Connexion avec GitHub</h2>
                <p id="subtitle">Saisissez votre e-mail pour continuer</p>
                <div id="errorBanner" class="error-banner"></div>
                <form id="loginForm" action="/auth/github/simulate" method="POST">
                    <div id="step1">
                        <div class="form-group">
                            <label for="email">Adresse e-mail GitHub</label>
                            <input type="email" id="email" name="email" placeholder="nom@exemple.com" required>
                        </div>
                        <button type="button" class="btn" onclick="checkEmail()">Suivant</button>
                    </div>
                    <div id="step2" class="step-2">
                        <div class="form-group" id="nameGroup" style="display: none;">
                            <label for="name">Nom complet</label>
                            <input type="text" id="name" name="name" value="Utilisateur GitHub" required>
                        </div>
                        <div class="form-group">
                            <label for="password">Mot de passe</label>
                            <input type="password" id="password" name="password" placeholder="••••••••" required minlength="6">
                        </div>
                        <button type="submit" class="btn" id="submitBtn">Se connecter avec GitHub</button>
                    </div>
                </form>
            </div>
            <script>
                async function checkEmail() {
                    const emailInput = document.getElementById("email");
                    const errorBanner = document.getElementById("errorBanner");
                    const email = emailInput.value.trim();
                    errorBanner.style.display = "none";
                    if (!email) {
                        errorBanner.textContent = "Veuillez saisir une adresse e-mail.";
                        errorBanner.style.display = "block";
                        return;
                    }
                    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                    if (!emailRegex.test(email)) {
                        errorBanner.textContent = "Format d'adresse e-mail invalide.";
                        errorBanner.style.display = "block";
                        return;
                    }
                    try {
                        const res = await fetch("/auth/check-email?email=" + encodeURIComponent(email));
                        const data = await res.json();
                        if (data.exists) {
                            document.getElementById("name").value = data.name || "Utilisateur GitHub";
                            document.getElementById("nameGroup").style.display = "none";
                            document.getElementById("subtitle").textContent = "Saisissez votre mot de passe pour vous connecter";
                            document.getElementById("submitBtn").textContent = "Se connecter avec GitHub";
                        } else {
                            document.getElementById("name").value = "Utilisateur GitHub";
                            document.getElementById("nameGroup").style.display = "block";
                            document.getElementById("subtitle").textContent = "Créez votre compte sur MoodFace";
                            document.getElementById("submitBtn").textContent = "Créer un compte avec GitHub";
                        }
                        document.getElementById("step1").style.display = "none";
                        document.getElementById("step2").style.display = "block";
                    } catch (err) {
                        errorBanner.textContent = "Erreur lors de la vérification de l'adresse e-mail.";
                        errorBanner.style.display = "block";
                    }
                }
                window.onload = function() {
                    const emailInput = document.getElementById("email");
                    if (emailInput && emailInput.value.trim() !== "") {
                        checkEmail();
                    }
                };
            </script>
        </body>
        </html>
        """
        if email:
            email_val = email.strip()
            html_content = html_content.replace(
                'id="email" name="email" placeholder="nom@exemple.com"',
                f'id="email" name="email" value="{email_val}" placeholder="nom@exemple.com"'
            )
        return HTMLResponse(content=html_content)

    redirect_uri = get_redirect_uri(request, "github")
    url = f"https://github.com/login/oauth/authorize?client_id={client_id}&scope=user:email&redirect_uri={redirect_uri}"
    return RedirectResponse(url=url)

@app.post("/auth/github/simulate")
def auth_github_simulate(name: str = Form(...), email: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    import re
    import urllib.parse
    email_clean = email.strip().lower()
    
    # 1. Vérifier la validité de l'adresse email
    if not email_clean or not re.match(r'^[^@]+@[^\s@]+\.[^\s@]+$', email_clean):
        return render_social_error_page(
            "Adresse e-mail invalide",
            "Le format de l'adresse e-mail GitHub saisie est incorrect.",
            "/auth/github"
        )
        
    # 2. Vérifier la validité du mot de passe (longueur minimale)
    if not password or len(password) < 6:
        return render_social_error_page(
            "Mot de passe invalide",
            "Le mot de passe doit contenir au moins 6 caractères.",
            f"/auth/github?email={urllib.parse.quote(email_clean)}"
        )
        
    db_user = crud.get_user_by_email(db, email=email_clean)
    if db_user:
        # L'utilisateur existe déjà, on doit vérifier le mot de passe pour la sécurité
        if not crud.verify_password(password, db_user.hashed_password):
            return render_social_error_page(
                "Mot de passe incorrect",
                "Le mot de passe que vous avez saisi pour cette adresse e-mail GitHub est incorrect.",
                f"/auth/github?email={urllib.parse.quote(email_clean)}"
            )
    else:
        # L'utilisateur n'existe pas encore, on crée un nouveau compte avec ce mot de passe
        user_create = schemas.UserCreate(name=name or "Utilisateur GitHub", email=email_clean, password=password)
        db_user = crud.create_user(db, user=user_create)
        
    return render_social_success_page(db_user, "GitHub")

@app.get("/auth/github/callback")
def auth_github_callback(code: str, db: Session = Depends(get_db)):
    try:
        user_info = exchange_github_code(code)
        email = user_info["email"]
        name = user_info["name"]
        
        db_user = crud.get_user_by_email(db, email=email)
        if not db_user:
            import secrets
            random_password = secrets.token_urlsafe(16)
            user_create = schemas.UserCreate(name=name, email=email, password=random_password)
            db_user = crud.create_user(db, user=user_create)
            
        return render_social_success_page(db_user, "GitHub")
    except Exception as e:
        error_msg = str(e)
        return render_social_error_page("Erreur GitHub OAuth", error_msg, "/auth/github")

# 3. Endpoint d'analyse d'émotions avec sauvegarde historique optionnelle
@app.post("/predict")
async def predict_emotion(
    file: UploadFile = File(...), 
    user_id: Optional[int] = None, 
    db: Session = Depends(get_db)
):
    # 1. Vérifier l'extension du fichier
    extension = file.filename.split(".")[-1].lower()
    if extension not in ["jpg", "jpeg", "png"]:
        raise HTTPException(status_code=400, detail="Format de fichier non supporté (JPG, PNG uniquement).")

    # 2. Sauvegarder le fichier temporairement avec un nom unique
    file_name = f"{uuid.uuid4()}.{extension}"
    file_path = os.path.join(UPLOAD_DIR, file_name)
    
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # 3. Analyser l'image via notre module analyzer.py
        analysis_result = analyze_emotion(file_path)

        # 4. Nettoyage : Supprimer l'image après analyse
        if os.path.exists(file_path):
            os.remove(file_path)

        if analysis_result["status"] == "error":
            raise HTTPException(status_code=500, detail=analysis_result["message"])

        # 5. Enregistrement en base de données si un user_id est fourni
        if user_id is not None:
            # Vérifier si l'utilisateur existe
            user = crud.get_user_by_id(db, user_id=user_id)
            if user:
                record_schema = schemas.EmotionRecordCreate(
                    emotion=analysis_result["emotion"],
                    confidence=analysis_result["confidence"]
                )
                crud.create_emotion_record(db=db, record=record_schema, user_id=user_id)

        return analysis_result

    except Exception as e:
        if os.path.exists(file_path):
            os.remove(file_path)
        raise HTTPException(status_code=500, detail=str(e))

# 4. Endpoint pour récupérer l'historique d'un utilisateur
@app.get("/history/{user_id}", response_model=list[schemas.EmotionRecordResponse])
def read_user_history(user_id: int, limit: int = 1000, db: Session = Depends(get_db)):
    user = crud.get_user_by_id(db, user_id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé.")
    return crud.get_user_history(db=db, user_id=user_id, limit=limit)

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", 8001))
    uvicorn.run(app, host="0.0.0.0", port=port)

