# EduLive — Plateforme de cours particuliers en temps réel

## Architecture

```
Flutter (Android / iOS / Web)
        │  REST (auth, classes, exercices)
        │  WebSocket ws://.../ws/room/{session_id}  (tableau blanc, chat, main levée, signalisation WebRTC)
        ▼
FastAPI backend
        │
        ▼
Supabase (Postgres + Auth + Storage)
```

- **REST** : inscription/connexion, création/rejoindre une classe, planifier et démarrer une session, créer/soumettre des exercices.
- **WebSocket** (`/ws/room/{session_id}`) : un seul canal par utilisateur connecté à une salle. Relaie en temps réel : traits du tableau blanc, messages de chat, main levée, autorisation micro, et signalisation WebRTC (offer/answer/ICE).
- **Audio/vidéo** : WebRTC pur (peer-to-peer via `flutter_webrtc`), avec le WebSocket comme simple canal de signalisation. Pour une classe nombreuse (>5-6 participants audio simultanés), remplacer le mesh P2P par un SFU (LiveKit, mediasoup, Janus) — la signalisation applicative ne change pas.

## Démarrer le backend

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # renseigner SUPABASE_URL, SUPABASE_KEY, JWT_SECRET
```

1. Va dans ton projet Supabase → SQL Editor → colle le contenu de `supabase_schema.sql` → Run.
2. Lance le serveur :

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

3. Documentation interactive auto-générée : http://localhost:8000/docs

## Démarrer le frontend Flutter

```bash
cd frontend
flutter pub get
flutter run
```

Adapte `kApiBaseUrl` / `kWsBaseUrl` dans `lib/services/api_service.dart` :
- Émulateur Android → `10.0.2.2`
- Simulateur iOS / Web → `localhost`
- Appareil physique → IP locale de ta machine (ex: `192.168.1.x`)
- Production → domaine HTTPS/WSS

## Ce qui est fonctionnel dans ce squelette

- ✅ Inscription/connexion JWT (enseignant / élève)
- ✅ Création de classe + code d'invitation, rejoindre une classe
- ✅ Planification et démarrage de session live
- ✅ Tableau blanc collaboratif temps réel (dessin main levée, couleurs, épaisseur, effacer, synchronisation à l'arrivée)
- ✅ Chat temps réel (broadcast + messages privés), persistance en base
- ✅ Main levée / autorisation-retrait de la parole (logique + UI)
- ✅ Squelette de signalisation WebRTC (offer/answer/ICE) prêt à connecter à `flutter_webrtc`
- ✅ Création d'exercices (QCM, ouvert, vrai/faux) + soumission + correction auto QCM/VF
- ✅ Interface responsive (bureau: 3 colonnes / mobile: onglets)

## Ce qu'il reste à construire (pistes)

- Import de PDF/images sur le tableau blanc (page dédiée + rendu par pages)
- LaTeX pour les formules mathématiques (ex: package `flutter_math_fork`)
- SFU pour l'audio/vidéo à grande échelle
- Upload de documents vers Supabase Storage (endpoint `/documents`)
- Notifications push (Firebase Cloud Messaging) pour les rappels de cours/devoirs
- Écran "Créer un exercice" et "Résultats" côté Flutter (les endpoints existent déjà)
- Tests automatisés (pytest côté backend, widget tests côté Flutter)
- Row Level Security (RLS) Supabase pour sécuriser l'accès direct aux données
