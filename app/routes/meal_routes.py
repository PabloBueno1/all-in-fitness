from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Meal, MealFoodItem, FoodItem, Goal
from app.schemas import (
    MealCreate, MealResponse,
    MealFoodItemCreate, MealFoodItemResponse,
    UpdateFoodItemBase,
    MealUpdate
)
from app.auth import get_current_user
from datetime import date

router = APIRouter()

@router.post("/meals", response_model=MealResponse)
def create_meal(meal: MealCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    new_meal = Meal(
        name=meal.name,
        date=meal.date,
        user_id=current_user.id
    )
    db.add(new_meal)
    db.commit()
    db.refresh(new_meal)
    return new_meal

@router.get("/meals")
def get_meals(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Meal).filter(Meal.user_id == current_user.id).all()

def _update_goals_for_meal(db: Session, current_user: User, meal: Meal, today: date):
    """Helper function to update goals for a meal"""
    if meal.date == today:
        # Calculate total calories and macros for today
        today_meals = db.query(Meal).filter(
            Meal.user_id == current_user.id,
            Meal.date == today
        ).all()
        
        # Calculate total daily calories
        total_daily_calories = 0
        for today_meal in today_meals:
            meal_items = db.query(MealFoodItem, FoodItem).join(
                FoodItem, MealFoodItem.food_item_id == FoodItem.id
            ).filter(MealFoodItem.meal_id == today_meal.id).all()
            
            total_daily_calories += sum(
                item.quantity * food.calories 
                for item, food in meal_items
            )
        
        # Update calorie goals
        calorie_goals = db.query(Goal).filter(
            Goal.user_id == current_user.id,
            Goal.goal_type == 'calories'
        ).all()

        for goal in calorie_goals:
            goal.current_value = total_daily_calories
            goal.is_completed = goal.current_value >= goal.target_value

        # Calculate and update macro goals
        for macro_type in ['protein', 'carbs', 'fats']:
            total_daily_macro = 0
            for today_meal in today_meals:
                meal_items = db.query(MealFoodItem, FoodItem).join(
                    FoodItem, MealFoodItem.food_item_id == FoodItem.id
                ).filter(MealFoodItem.meal_id == today_meal.id).all()
                
                total_daily_macro += sum(
                    item.quantity * getattr(food, macro_type)
                    for item, food in meal_items
                )
            
            # Update macro goals
            macro_goals = db.query(Goal).filter(
                Goal.user_id == current_user.id,
                Goal.goal_type == macro_type
            ).all()

            for goal in macro_goals:
                goal.current_value = total_daily_macro
                goal.is_completed = goal.current_value >= goal.target_value

@router.post("/meal_food_items", response_model=MealFoodItemResponse)
async def add_food_to_meal(
    item: MealFoodItemCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    meal = db.query(Meal).filter(Meal.id == item.meal_id, Meal.user_id == current_user.id).first()
    if not meal:
        raise HTTPException(status_code=400, detail="Invalid meal_id or unauthorized")

    if item.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be greater than 0")

    # Get the food item to calculate calories and macros
    food_item = db.query(FoodItem).filter(FoodItem.id == item.food_item_id).first()
    if not food_item:
        raise HTTPException(status_code=404, detail="Food item not found")

    # Add or update the meal food item
    existing_food = db.query(MealFoodItem).filter(
        MealFoodItem.meal_id == item.meal_id, 
        MealFoodItem.food_item_id == item.food_item_id
    ).first()

    if existing_food:
        existing_food.quantity += item.quantity
        db.commit()
        db.refresh(existing_food)
        result = existing_food
    else:
        new_meal_item = MealFoodItem(
            meal_id=item.meal_id,
            food_item_id=item.food_item_id,
            quantity=item.quantity
        )
        db.add(new_meal_item)
        db.commit()
        db.refresh(new_meal_item)
        result = new_meal_item

    # Update goals
    _update_goals_for_meal(db, current_user, meal, date.today())
    db.commit()
    return result

@router.patch("/meal_food_items/{meal_id}/{food_item_id}")
def update_food_quantity(
    meal_id: int,
    food_item_id: int,
    item: UpdateFoodItemBase,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meal_food_item = (
        db.query(MealFoodItem)
        .join(Meal)
        .filter(
            MealFoodItem.meal_id == meal_id,
            MealFoodItem.food_item_id == food_item_id,
            Meal.user_id == current_user.id
        )
        .first()
    )

    if not meal_food_item:
        raise HTTPException(status_code=404, detail="Food item not found in meal")

    meal_food_item.quantity = item.quantity
    db.commit()
    db.refresh(meal_food_item)

    # Update goals
    _update_goals_for_meal(db, current_user, meal_food_item.meal, date.today())
    db.commit()
    return {"message": "Quantity updated successfully", "new_quantity": meal_food_item.quantity}

@router.get("/meal_food_items/{meal_id}")
def get_meal_food_items(meal_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    meal = db.query(Meal).filter(Meal.id == meal_id, Meal.user_id == current_user.id).first()
    if not meal:
        raise HTTPException(status_code=400, detail="Invalid meal_id or unauthorized")

    meal_food_items = (
        db.query(
            MealFoodItem.food_item_id, 
            MealFoodItem.quantity,
            FoodItem.name, 
            FoodItem.calories, 
            FoodItem.serving_size,
            FoodItem.protein,
            FoodItem.carbs,
            FoodItem.fats,
            FoodItem.is_custom)
        .join(FoodItem, MealFoodItem.food_item_id == FoodItem.id)
        .filter(MealFoodItem.meal_id == meal_id)
        .all()
    )

    return [
        {
            "food_id": item.food_item_id,
            "food_name": item.name,
            "quantity": item.quantity,
            "calories_per_item": item.calories,
            "serving_size": item.serving_size,
            "protein": item.protein,
            "carbs": item.carbs,
            "fats": item.fats,
            "is_custom": item.is_custom 
        }
        for item in meal_food_items
    ]

@router.delete("/meals/{meal_id}")
def delete_meal(
    meal_id: int, 
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    meal = db.query(Meal).filter(
        Meal.id == meal_id,
        Meal.user_id == current_user.id
    ).first()
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found or unauthorized.")
    
    db.query(MealFoodItem).filter(MealFoodItem.meal_id == meal_id).delete(synchronize_session=False)
    db.delete(meal)
    db.commit()
    
    return {"message": "Meal deleted successfully"}

@router.delete("/meal_food_items/{meal_id}/{food_id}")
def remove_food_from_meal(
    meal_id: int, 
    food_id: int, 
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    meal_food = (
        db.query(MealFoodItem)
        .join(Meal)
        .filter(
            MealFoodItem.meal_id == meal_id,
            MealFoodItem.food_item_id == food_id,
            Meal.user_id == current_user.id
        )
        .first()
    )
    if not meal_food:
        raise HTTPException(status_code=404, detail="Food item not found in meal.")
    
    meal = meal_food.meal
    db.delete(meal_food)
    db.commit()

    # Update goals
    _update_goals_for_meal(db, current_user, meal, date.today())
    db.commit()
    return {"message": "Food item removed from meal"}

@router.patch("/meals/{meal_id}", response_model=MealResponse)
def update_meal(
    meal_id: int,
    meal_update: MealUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Get the existing meal
    meal = db.query(Meal).filter(
        Meal.id == meal_id,
        Meal.user_id == current_user.id
    ).first()

    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found or unauthorized")

    # Update only the fields that were provided
    update_data = meal_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(meal, field, value)

    try:
        db.commit()
        db.refresh(meal)
        return meal
    except Exception as e:
        db.rollback()
        print(f"Error updating meal: {e}")
        raise HTTPException(status_code=500, detail="Error updating meal") 