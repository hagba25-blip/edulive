from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.routers import auth, classes, sessions, exercises, users, payments, notifications
from app.websocket import room

app = FastAPI(title="EduLive API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # à restreindre en production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    """Empêche de renvoyer une erreur 500 en texte brut (illisible côté app) —
    on renvoie toujours du JSON, même pour un bug imprévu côté serveur."""
    return JSONResponse(status_code=500, content={"detail": f"Erreur serveur interne: {exc}"})

app.include_router(auth.router)
app.include_router(classes.router)
app.include_router(sessions.router)
app.include_router(exercises.router)
app.include_router(users.router)
app.include_router(payments.router)
app.include_router(notifications.router)
app.include_router(room.router)  # expose /ws/room/{session_id}


@app.get("/")
def health_check():
    return {"status": "ok", "service": "EduLive API"}
