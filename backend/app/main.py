from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, classes, sessions, exercises, users
from app.websocket import room

app = FastAPI(title="EduLive API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # à restreindre en production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(classes.router)
app.include_router(sessions.router)
app.include_router(exercises.router)
app.include_router(users.router)
app.include_router(room.router)  # expose /ws/room/{session_id}


@app.get("/")
def health_check():
    return {"status": "ok", "service": "EduLive API"}