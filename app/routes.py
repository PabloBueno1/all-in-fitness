from fastapi import APIRouter, Depends, HTTPException, Request, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.database import get_db
from app.models import User, Workout, ExerciseTypes, Exercise, ExerciseLog, FoodItem, Meal, MealFoodItem
from app.schemas import (
    WorkoutCreate, WorkoutResponse, 
    ExerciseTypeCreate, ExerciseTypeResponse, 
    ExerciseCreate, ExerciseResponse,
    ExerciseLogCreate, ExerciseLogResponse,
    FoodItemCreate, FoodItemResponse,
    MealCreate, MealResponse,
    MealFoodItemCreate, MealFoodItemResponse,
    UserCreate, UserLogin,
    MealFoodItemBase, UpdateFoodItemBase,
)
from app.usda_api import fetch_usda_foods, fetch_usda_foods_raw
from app.wger_api import fetch_wger_exercises
from app.auth import get_password_hash, verify_password, create_access_token, get_current_user
from fastapi.security import OAuth2PasswordRequestForm
from typing import List
from app.routes import router

router = APIRouter()

# USERS
@router.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == user.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = get_password_hash(user.password)
    new_user = User(name=user.name, email=user.email, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User created successfully"}

# User Login (Authentication)
@router.post("/token")
def login_for_access_token(user: UserLogin, db: Session = Depends(get_db)):
    user_in_db = db.query(User).filter(User.email == user.email).first()
    if not user_in_db or not verify_password(user.password, user_in_db.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    access_token = create_access_token(data={"sub": str(user_in_db.id)})
    return {"access_token": access_token, "token_type": "bearer"}

# FOR OAUTH TESTING
@router.post("/token")
# async def login_for_access_token(
#     db: Session = Depends(get_db),
#     form_data: OAuth2PasswordRequestForm = Depends()  # Used for Swagger UI (OAuth2)
# ):
#     """
#     ✅ Supports only:
#     - OAuth2 form data (Swagger UI)
#     """

#     email = form_data.username  # OAuth2 uses "username", treat it as "email"
#     password = form_data.password

#     # Validate user
#     user_in_db = db.query(User).filter(User.email == email).first()
#     if not user_in_db or not verify_password(password, user_in_db.hashed_password):
#         raise HTTPException(status_code=400, detail="Incorrect email or password")

#     # Generate token
#     access_token = create_access_token(data={"sub": str(user_in_db.id)})
#     return {"access_token": access_token, "token_type": "bearer"}


# Get Current User Data
@router.get("/users/me")
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user


# WORKOUTS
@router.post("/workouts", response_model=WorkoutResponse)
def create_workout(workout: WorkoutCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    new_workout = Workout(
        name=workout.name,
        duration=workout.duration,
        user_id=current_user.id,  # Use the logged-in user ID
        date=workout.date
    )
    db.add(new_workout)
    db.commit()
    db.refresh(new_workout)
    return new_workout

@router.get("/workouts")
def get_workouts(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Workout).filter(Workout.user_id == current_user.id).all()

@router.delete("/workouts/{workout_id}/logs")
def delete_workout_logs(
    workout_id: int, 
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Ensure the workout belongs to the current user
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    # Delete all exercise logs for exercises in this workout
    logs_to_delete = (
        db.query(ExerciseLog)
        .join(Exercise, Exercise.id == ExerciseLog.exercise_id)
        .filter(Exercise.workout_id == workout_id)
    )
    logs_to_delete.delete(synchronize_session=False)
    db.commit()
    
    return {"message": "Exercise logs deleted successfully"}

@router.delete("/workouts/{workout_id}/exercises")
def delete_workout_exercises(
    workout_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Ensure the workout belongs to the current user
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    # Delete all exercises in the workout
    db.query(Exercise).filter(Exercise.workout_id == workout_id).delete(synchronize_session=False)
    db.commit()
    
    return {"message": "Workout exercises deleted successfully"}

@router.delete("/workouts/{workout_id}")
def delete_workout(
    workout_id: int, 
    current_user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    # Ensure the workout belongs to the current user
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    try:
        # First delete all exercise logs
        logs_to_delete = (
            db.query(ExerciseLog)
            .join(Exercise, Exercise.id == ExerciseLog.exercise_id)
            .filter(Exercise.workout_id == workout_id)
        )
        logs_to_delete.delete(synchronize_session=False)

        # Then delete all exercises
        db.query(Exercise).filter(Exercise.workout_id == workout_id).delete(synchronize_session=False)

        # Finally delete the workout
        db.delete(workout)
        db.commit()

        return {"message": "Workout deleted successfully"}
    except Exception as e:
        db.rollback()
        print(f"Error deleting workout: {e}")
        raise HTTPException(status_code=500, detail="Error deleting workout")


# EXERCISE TYPES
@router.post("/exercise_types", response_model=ExerciseTypeResponse)
def create_exercise_type(
    exercise: ExerciseTypeCreate, 
    db: Session = Depends(get_db)
):
    # Check if exercise name already exists
    existing_exercise = db.query(ExerciseTypes).filter(ExerciseTypes.name == exercise.name).first()
    if existing_exercise:
        raise HTTPException(status_code=400, detail="Exercise name already exists")

    # Create new exercise (is_predefined defaults to False for user-created exercises)
    new_exercise = ExerciseTypes(**exercise.dict())
    db.add(new_exercise)
    db.commit()
    db.refresh(new_exercise)
    
    return new_exercise


@router.get("/exercise_types", response_model=list[ExerciseTypeResponse])
def get_exercise_types(db: Session = Depends(get_db)):
    # Return all exercises (both predefined and user-created)
    return db.query(ExerciseTypes).all()


# EXERCISES
@router.post("/exercises", response_model=ExerciseResponse)
def create_exercise_entry(exercise: ExerciseCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Check if the workout belongs to the user
    workout = db.query(Workout).filter(Workout.id == exercise.workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    # Check if this exercise type is already in the workout
    existing_exercise = (
        db.query(Exercise)
        .filter(
            Exercise.workout_id == exercise.workout_id,
            Exercise.exercise_id == exercise.exercise_id
        )
        .first()
    )
    
    if existing_exercise:
        raise HTTPException(status_code=409, detail="This exercise is already in your workout")

    new_exercise = Exercise(
        workout_id=exercise.workout_id,
        exercise_id=exercise.exercise_id,
        sets=exercise.sets
    )
    db.add(new_exercise)
    db.commit()
    db.refresh(new_exercise)
    return new_exercise

@router.get("/exercises/{workout_id}")
def get_exercises(workout_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Verify the workout belongs to the current user
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    workout_exercises = (
        db.query(
            Exercise.id.label("exercise_id"),
            Exercise.exercise_id.label("exercise_type_id"),
            Exercise.sets,
            ExerciseTypes.name.label("exercise_name")
        )
        .join(Workout, Workout.id == Exercise.workout_id)  # ✅ Ensure Exercise is linked to Workout
        .join(ExerciseTypes, Exercise.exercise_id == ExerciseTypes.id)  # ✅ Correct Join
        .filter(Exercise.workout_id == workout_id, Workout.user_id == current_user.id)
        .all()
    )

    # Format response correctly
    return [
        {
            "exercise_id": item.exercise_id,
            "exercise_type_id": item.exercise_type_id,
            "exercise_name": item.exercise_name,
            "sets": item.sets,
        }
        for item in workout_exercises
    ]

@router.delete("/workouts/{workout_id}/exercises/{exercise_id}")
def remove_exercise_from_workout(workout_id: int, exercise_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Ensure the workout belongs to the current user
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    # Find the exercise
    exercise = db.query(Exercise).filter(
        Exercise.id == exercise_id,
        Exercise.workout_id == workout_id
    ).first()

    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found in workout")

    try:
        # First delete all logs for this exercise
        db.query(ExerciseLog).filter(ExerciseLog.exercise_id == exercise_id).delete(synchronize_session=False)
        
        # Then delete the exercise
        db.delete(exercise)
        db.commit()

        return {"message": "Exercise and its logs removed from workout"}
    except Exception as e:
        db.rollback()
        print(f"Error removing exercise: {e}")
        raise HTTPException(status_code=500, detail="Error removing exercise from workout")


# EXERCISE LOGS
# Single
@router.post("/exercise_log", response_model=ExerciseLogResponse)
def log_exercise_set(log: ExerciseLogCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Ensure exercise belongs to user
    exercise = db.query(Exercise).join(Workout).filter(Exercise.id == log.exercise_id, Workout.user_id == current_user.id).first()
    if not exercise:
        raise HTTPException(status_code=400, detail="Invalid exercise_id or unauthorized")

    new_log = ExerciseLog(
        exercise_id=log.exercise_id,
        set_number=log.set_number,
        weight=log.weight,
        reps=log.reps
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)
    return new_log

@router.get("/exercise_log/{workout_id}/{exercise_id}")
def get_exercise_logs(
    workout_id: int,
    exercise_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return (
        db.query(ExerciseLog)
        .join(Exercise, Exercise.id == ExerciseLog.exercise_id)
        .join(Workout, Workout.id == Exercise.workout_id)
        .filter(Workout.user_id == current_user.id)
        .filter(Workout.id == workout_id)
        .filter(Exercise.id == exercise_id)
        .all()
    )

#Edit Log
@router.patch("/exercise_log/{log_id}", response_model=ExerciseLogResponse)
def partial_update_exercise_log(
    log_id: int,
    log_update: dict,  # Allows partial data
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Fetch the log ensuring it belongs to the user
    exercise_log = (
        db.query(ExerciseLog)
        .join(Exercise)
        .join(Workout)
        .filter(ExerciseLog.id == log_id)
        .filter(Workout.user_id == current_user.id)
        .first()
    )

    if not exercise_log:
        raise HTTPException(status_code=404, detail="Exercise log not found")

    # Update only provided fields
    for field, value in log_update.items():
        setattr(exercise_log, field, value)

    db.commit()
    db.refresh(exercise_log)

    return exercise_log


#Delete exercise Log
@router.delete("/exercise_log/{log_id}")
def delete_exercise_log(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Find the specific log entry
    exercise_log = (
        db.query(ExerciseLog)
        .join(Exercise)
        .join(Workout)
        .filter(ExerciseLog.id == log_id)
        .filter(Workout.user_id == current_user.id)  # Ensure user owns the log
        .first()
    )

    if not exercise_log:
        raise HTTPException(status_code=404, detail="Exercise log not found")

    # Delete the log
    db.delete(exercise_log)
    db.commit()

    return {"message": "Exercise log deleted successfully"}


# FOOD
@router.post("/food_items", response_model=FoodItemResponse)
def create_food_item(food: FoodItemCreate, db: Session = Depends(get_db)):
    # Check if food already exists
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


# Create a meal
@router.post("/meals", response_model=MealResponse)
def create_meal(meal: MealCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    new_meal = Meal(
        name=meal.name,
        date=meal.date,
        user_id=current_user.id  # Associate with logged-in user
    )
    db.add(new_meal)
    db.commit()
    db.refresh(new_meal)
    return new_meal

# Retrieve all meals
@router.get("/meals")
def get_meals(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.query(Meal).filter(Meal.user_id == current_user.id).all()

# Add a food item to a meal
@router.post("/meal_food_items", response_model=MealFoodItemResponse)
async def add_food_to_meal(
    item: MealFoodItemCreate, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # Ensure the meal belongs to the logged-in user
    meal = db.query(Meal).filter(Meal.id == item.meal_id, Meal.user_id == current_user.id).first()
    if not meal:
        raise HTTPException(status_code=400, detail="Invalid meal_id or unauthorized")

    # Ensure quantity is a valid float
    if item.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantity must be greater than 0")

    # Check if the food item is already in the meal
    existing_food = db.query(MealFoodItem).filter(
        MealFoodItem.meal_id == item.meal_id, 
        MealFoodItem.food_item_id == item.food_item_id
    ).first()

    if existing_food:
        # ✅ If the item exists, increase the quantity instead of creating a new row
        existing_food.quantity += item.quantity
        db.commit()
        db.refresh(existing_food)
        return existing_food
    else:
        # ✅ If the item does not exist, insert it normally
        new_meal_item = MealFoodItem(
            meal_id=item.meal_id,
            food_item_id=item.food_item_id,
            quantity=item.quantity  # ✅ Quantity is now a float
        )
        db.add(new_meal_item)
        db.commit()
        db.refresh(new_meal_item)
        return new_meal_item

#Update meal food item   
@router.patch("/meal_food_items/{meal_id}/{food_item_id}")
def update_food_quantity(
    meal_id: int,
    food_item_id: int,
    item: UpdateFoodItemBase,  # ✅ Now using UpdateFoodItemBase
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

    meal_food_item.quantity = item.quantity  # ✅ Only updates "quantity"
    db.commit()
    db.refresh(meal_food_item)

    return {"message": "Quantity updated successfully", "new_quantity": meal_food_item.quantity}


# get meal food items
@router.get("/meal_food_items/{meal_id}")
def get_meal_food_items(meal_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    meal = db.query(Meal).filter(Meal.id == meal_id, Meal.user_id == current_user.id).first()
    if not meal:
        raise HTTPException(status_code=400, detail="Invalid meal_id or unauthorized")

    # Fetch meal food items with JOIN to get food name & calories
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

    # Format response correctly
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

#Delete Entire Meal
@router.delete("/meals/{meal_id}")
def delete_meal(
    meal_id: int, 
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    meal = db.query(Meal).filter(
        Meal.id == meal_id,
        Meal.user_id == current_user.id  # Ensure meal belongs to user
    ).first()
    if not meal:
        raise HTTPException(status_code=404, detail="Meal not found or unauthorized.")
    
    db.query(MealFoodItem).filter(MealFoodItem.meal_id == meal_id).delete(synchronize_session=False)
    db.delete(meal)
    db.commit()
    
    return {"message": "Meal deleted successfully"}


#Remove Food From Meal
@router.delete("/meal_food_items/{meal_id}/{food_id}")
def remove_food_from_meal(meal_id: int, food_id: int, db: Session = Depends(get_db)):
    meal_food = db.query(MealFoodItem).filter(
        MealFoodItem.meal_id == meal_id,
        MealFoodItem.food_item_id == food_id
    ).first()
    if not meal_food:
        raise HTTPException(status_code=404, detail="Food item not found in meal.")
    
    db.delete(meal_food)
    db.commit()
    return {"message": "Food item removed from meal"}


# WGER API Integration
@router.get("/search-exercises", response_model=List[ExerciseTypeResponse])
def search_exercise_endpoint(query: str, db: Session = Depends(get_db)):
    """
    Search for exercises in both local database and wger API.
    Returns combined results with preference for local exercises.
    """
    # Search local database first (like USDA pattern)
    local_results = (
        db.query(ExerciseTypes)
        .filter(ExerciseTypes.name.ilike(f"%{query}%"))
        .all()
    )
    
    if local_results:
        return local_results
    
    # If no local results, fetch from wger API (like USDA pattern)
    wger_results = fetch_wger_exercises(query)
    return wger_results


# Update search endpoint to match food items pattern
@router.get("/exercise_types/search", response_model=list[ExerciseTypeResponse])
def search_exercise_types(query: str, db: Session = Depends(get_db)):
    """
    Search for exercises in both local database and wger API.
    Returns combined results with preference for local exercises.
    """
    # Search local database first (like USDA pattern)
    local_results = (
        db.query(ExerciseTypes)
        .filter(ExerciseTypes.name.ilike(f"%{query}%"))
        .all()
    )
    
    if local_results:
        return local_results
    
    # If no local results, fetch from wger API (like USDA pattern)
    wger_results = fetch_wger_exercises(query)
    return wger_results

