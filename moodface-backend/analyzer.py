import cv2 # OpenCV pour le traitement d'image
import mediapipe as mp
from deepface import DeepFace
import numpy as np

# Initialisation de MediaPipe Face Detection
# model_selection=0 pour les visages proches (selfies), 1 pour les visages à plus de 2 mètres
mp_face_detection = mp.solutions.face_detection
face_detection = mp_face_detection.FaceDetection(model_selection=0, min_detection_confidence=0.5)

def analyze_emotion(image_path):
    """
    Version sécurisée et robuste de l'analyse d'émotion.
    """
    try:
        # 1. Chargement de l'image
        img = cv2.imread(image_path)
        if img is None:
            return {"status": "error", "message": f"Fichier introuvable ou illisible: {image_path}"}
            
        h, w = img.shape[:2]
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # 2. Détection initiale avec MediaPipe
        results = face_detection.process(img_rgb)

        # Si MediaPipe ne voit rien, on laisse DeepFace essayer quand même avec son propre détecteur
        # car RetinaFace est plus puissant que MediaPipe.
        
        # 3. Analyse avec DeepFace (RetinaFace est très robuste)
        try:
            objs = DeepFace.analyze(
                img_path = img, # On utilise l'image originale pour éviter les erreurs de format
                actions = ['emotion'],
                enforce_detection = True,
                detector_backend = 'retinaface',
                align = True
            )
        except Exception as e_deep:
            return {"status": "error", "message": f"Erreur DeepFace: {str(e_deep)}"}

        if not objs:
            return {"status": "error", "message": "Aucun visage analysable trouvé"}

        result = objs[0]
        emotions = result['emotion']
        
        # 4. Calibration du résultat
        dominant = result['dominant_emotion']
        
        # Si l'humeur dominante est neutre, on privilégie une émotion active
        # seulement si elle est significative (>= 20%) et on sélectionne celle
        # avec le score le plus élevé (plutôt que le premier clé dans le dictionnaire).
        if dominant == 'neutral':
            active_emotions = {k: v for k, v in emotions.items() if k != 'neutral'}
            if active_emotions:
                best_active_emo = max(active_emotions, key=active_emotions.get)
                if active_emotions[best_active_emo] >= 20.0:
                    dominant = best_active_emo

        return {
            "status": "success",
            "emotion": dominant,
            "confidence": round(emotions[dominant], 2),
            "all_emotions": {k: round(v, 2) for k, v in emotions.items()}
        }

    except Exception as e:
        import traceback
        return {"status": "error", "message": f"Erreur système: {str(e)}", "trace": traceback.format_exc()}

    except Exception as e:
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    print("Module analyzer.py prêt.")
