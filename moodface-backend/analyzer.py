import cv2 # OpenCV pour le traitement d'image
import mediapipe as mp
from deepface import DeepFace
import numpy as np
import os

# Initialisation de MediaPipe Face Detection
# model_selection=0 pour les visages proches (selfies), 1 pour les visages à plus de 2 mètres
mp_face_detection = mp.solutions.face_detection
face_detection = mp_face_detection.FaceDetection(model_selection=0, min_detection_confidence=0.5)

def analyze_emotion(image_path, model_type="pretrained"):
    """
    Version hautement robuste et optimisée de l'analyse d'émotion.
    Utilise une stratégie multi-détecteurs (MediaPipe -> RetinaFace -> OpenCV -> No Enforce)
    pour garantir une détection et une classification optimales de l'émotion.
    """
    try:
        # 1. Chargement de l'image
        img = cv2.imread(image_path)
        if img is None:
            return {"status": "error", "message": f"Fichier introuvable ou illisible: {image_path}"}
            
        # Stratégie de secours multi-détecteurs
        backends = ['mediapipe', 'retinaface', 'opencv']
        objs = None
        error_logs = []

        for backend in backends:
            try:
                objs = DeepFace.analyze(
                    img_path = img,
                    actions = ['emotion'],
                    enforce_detection = True,
                    detector_backend = backend,
                    align = True
                )
                if objs:
                    print(f"[INFO] Visage détecté avec succès via le moteur : {backend}")
                    break
            except Exception as e:
                error_logs.append(f"{backend}: {str(e)}")

        # Si aucun détecteur strict n'a trouvé de visage, on force l'analyse sans contrainte de détection
        if not objs:
            print("[WARNING] Aucun visage trouvé de manière stricte. Tentative avec enforce_detection=False")
            try:
                objs = DeepFace.analyze(
                    img_path = img,
                    actions = ['emotion'],
                    enforce_detection = False,
                    detector_backend = 'opencv',
                    align = True
                )
            except Exception as e_final:
                return {"status": "error", "message": f"Échec final de l'analyse : {str(e_final)} (Détails: {', '.join(error_logs)})"}

        if not objs:
            return {"status": "error", "message": "Aucun visage analysable trouvé"}

        result = objs[0]
        emotions = result['emotion']
        dominant = result['dominant_emotion']
        
        # Post-traitement : Si le score de l'émotion dominante est trop faible (ex: moins de 35%),
        # l'expression est probablement neutre.
        if emotions[dominant] < 35.0:
            dominant = 'neutral'

        return {
            "status": "success",
            "emotion": dominant,
            "confidence": round(emotions[dominant], 2),
            "all_emotions": {k: round(v, 2) for k, v in emotions.items()}
        }

    except Exception as e:
        import traceback
        return {"status": "error", "message": f"Erreur système: {str(e)}", "trace": traceback.format_exc()}

if __name__ == "__main__":
    print("Module analyzer.py prêt.")


