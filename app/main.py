from fastapi import FastAPI, Depends
from app.database import engine
from app.models import Base
from app.routes import router
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Fitness App", version="1.0")

Base.metadata.create_all(bind=engine)

app.include_router(router)

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins (Change to specific domains in production)
    allow_credentials=True,
    allow_methods=["*"],  # Allow GET, POST, PUT, DELETE
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "Welcome to the Fitness App API"}