from fastapi import FastAPI, Depends
from app.database import engine
from app.models import Base
from app.routes import router
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, time, timedelta
import asyncio
import httpx

app = FastAPI(title="Fitness App", version="1.0")

Base.metadata.create_all(bind=engine)

# Include main router which includes all other routers
app.include_router(router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins (Change to specific domains in production)
    allow_credentials=True,
    allow_methods=["*"],  # Allow GET, POST, PUT, DELETE
    allow_headers=["*"],
)

async def check_daily_goals():
    """Background task to check and create daily goals at midnight"""
    while True:
        now = datetime.now()
        # Calculate time until next midnight
        midnight = datetime.combine(now.date(), time())
        if now >= midnight:
            # Add one day to get to next midnight
            midnight = datetime.combine(now.date() + timedelta(days=1), time())
        
        # Wait until midnight
        await asyncio.sleep((midnight - now).total_seconds())
        
        # Create new daily goals
        async with httpx.AsyncClient() as client:
            try:
                await client.post("http://localhost:8000/users/goals/create-daily")
            except Exception as e:
                print(f"Error creating daily goals: {e}")

@app.on_event("startup")
async def startup_event():
    """Start the background task when the application starts"""
    asyncio.create_task(check_daily_goals())

@app.get("/")
def root():
    return {"message": "Welcome to the Fitness App API"}