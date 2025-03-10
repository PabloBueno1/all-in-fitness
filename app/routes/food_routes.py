from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models import FoodItem
from app.schemas import FoodItemCreate, FoodItemResponse
from app.usda_api import fetch_usda_foods, fetch_usda_foods_raw

router = APIRouter()

@router.post("/food_items", response_model=FoodItemResponse)
def create_food_item(food: FoodItemCreate, db: Session = Depends(get_db)):
    existing_food = db.query(FoodItem).filter(FoodItem.name == food.name).first()
    if existing_food:
        raise HTTPException(status_code=400, detail="Food item already exists.")

    new_food = FoodItem(**food.dict())
    new_food.last_updated = db.execute(func.now()).scalar()
    db.add(new_food)
    db.commit()
    db.refresh(new_food)
    return new_food

@router.get("/food_items", response_model=list[FoodItemResponse])
def get_food_items(db: Session = Depends(get_db)):
    return db.query(FoodItem).all()

@router.get("/food_items/search", response_model=list[FoodItemResponse])
def search_food_items(query: str, db: Session = Depends(get_db)):
    local_results = db.query(FoodItem).filter(FoodItem.name.ilike(f"%{query}%")).all()

    if local_results:
        return local_results

    usda_results = fetch_usda_foods(query)
    return usda_results

@router.get("/usda/raw")
def get_usda_raw_data(query: str):
    return fetch_usda_foods_raw(query) 