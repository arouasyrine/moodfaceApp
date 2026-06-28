from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, Form
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
    if not db_user or not crud.verify_password(user_login.password, db_user.hashed_password):
        raise HTTPException(status_code=400, detail="Email ou mot de passe incorrect.")
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
def forgot_password(request: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=request.email)
    if not db_user:
        raise HTTPException(status_code=404, detail="Aucun compte n'est associé à cette adresse e-mail.")
    
    import secrets
    from datetime import datetime, timedelta
    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(minutes=15)
    
    crud.set_user_reset_token(db=db, user_id=db_user.id, token=token, expires_at=expires_at)
    
    # Nous utilisons l'IP de l'ordinateur configurée
    reset_link = f"http://10.168.227.97:8001/reset-password?token={token}"
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

def exchange_github_code(code: str):
    import urllib.request
    import urllib.parse
    import json
    
    client_id = os.getenv("GITHUB_CLIENT_ID", "")
    client_secret = os.getenv("GITHUB_CLIENT_SECRET", "")
    
    # 1. Échanger le code contre un access_token
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
        
    # 2. Récupérer les informations de profil de l'utilisateur
    user_url = "https://api.github.com/user"
    req_user = urllib.request.Request(user_url, headers={
        "Authorization": f"token {access_token}",
        "User-Agent": "MoodFace-App"
    })
    with urllib.request.urlopen(req_user) as response_user:
        user_profile = json.loads(response_user.read().decode("utf-8"))
        
    # 3. Si l'email est privé, le récupérer via l'API des emails de GitHub
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
def auth_github():
    client_id = os.getenv("GITHUB_CLIENT_ID", "")
    # Si non configuré, on simule un succès immédiat pour tester localement sans créer d'application GitHub
    if not client_id or client_id == "votre_client_id_github":
         mock_id = 999
         mock_name = "GitHub Test User"
         mock_email = "github_test@example.com"
         return RedirectResponse(url=f"moodface://auth?status=success&id={mock_id}&name={mock_name}&email={mock_email}")

    redirect_uri = "http://10.168.227.97:8001/auth/github/callback"
    url = f"https://github.com/login/oauth/authorize?client_id={client_id}&scope=user:email&redirect_uri={redirect_uri}"
    return RedirectResponse(url=url)

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
            
        html_content = f"""
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Connexion réussie</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; }}
                .card {{ background: white; padding: 30px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 400px; width: 100%; }}
                h2 {{ color: #4A148C; margin-bottom: 10px; }}
                p {{ color: #666; margin-bottom: 25px; }}
                .btn {{ display: inline-block; padding: 12px 30px; background-color: #9C27B0; color: white; text-decoration: none; border-radius: 12px; font-weight: bold; box-shadow: 0 5px 15px rgba(156, 39, 176, 0.3); }}
            </style>
        </head>
        <body>
            <div class="card">
                <h2>Connexion réussie !</h2>
                <p>Vous allez être redirigé vers l'application MoodFace...</p>
                <a class="btn" href="moodface://auth?status=success&id={db_user.id}&name={db_user.name}&email={db_user.email}">Ouvrir l'application</a>
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
    except Exception as e:
        error_msg = str(e)
        html_error = f"""
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Erreur</title>
            <style>
                body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background-color: #f5f5f7; text-align: center; padding: 20px; }}
                .card {{ background: white; padding: 30px; border-radius: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.05); max-width: 400px; width: 100%; }}
                h2 {{ color: #D32F2F; margin-bottom: 10px; }}
                p {{ color: #666; margin-bottom: 25px; }}
                .btn {{ display: inline-block; padding: 12px 30px; background-color: #D32F2F; color: white; text-decoration: none; border-radius: 12px; font-weight: bold; }}
            </style>
        </head>
        <body>
            <div class="card">
                <h2>Erreur de Connexion</h2>
                <p>{error_msg}</p>
                <a class="btn" href="moodface://auth?status=error&message={error_msg}">Retourner à l'application</a>
            </div>
        </body>
        </html>
        """
        return HTMLResponse(content=html_error, status_code=500)

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
    uvicorn.run(app, host="0.0.0.0", port=8001)
