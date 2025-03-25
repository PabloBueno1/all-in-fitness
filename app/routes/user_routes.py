from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Goal, Meal, Workout, ExerciseLog
from app.schemas import UserCreate, UserLogin, GoalCreate, GoalUpdate, Goal as GoalSchema, GoalProgress
from app.auth import get_password_hash, verify_password, create_access_token, get_current_user
from fastapi.security import OAuth2PasswordRequestForm
from datetime import datetime, date, timedelta
from typing import List

router = APIRouter()

# Define which categories are daily goals
DAILY_GOALS = {'calories', 'steps', 'protein', 'carbs', 'fats', 'weight'}

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

@router.post("/token")
def login_for_access_token(user: UserLogin, db: Session = Depends(get_db)):
    user_in_db = db.query(User).filter(User.email == user.email).first()
    if not user_in_db or not verify_password(user.password, user_in_db.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect email or password")

    access_token = create_access_token(data={"sub": str(user_in_db.id)})
    return {"access_token": access_token, "token_type": "bearer"}

#Oauth Testing
# @router.post("/token")
# async def oauth_login_for_access_token(
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

@router.get("/users/me")
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/users/goals", response_model=GoalSchema)
def create_user_goal(
    goal: GoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new goal for the current user"""
    today = date.today()
    
    # For daily goals (including weight), set start_date and target_date to today
    if goal.goal_type in DAILY_GOALS:
        db_goal = Goal(
            user_id=current_user.id,
            goal_type=goal.goal_type,
            target_value=goal.target_value,
            current_value=goal.current_value,
            start_date=today,
            target_date=today
        )
    else:
        db_goal = Goal(
            user_id=current_user.id,
            goal_type=goal.goal_type,
            target_value=goal.target_value,
            current_value=goal.current_value,
            start_date=goal.start_date,
            target_date=goal.target_date
        )
    
    db.add(db_goal)
    db.commit()
    db.refresh(db_goal)
    return db_goal

@router.post("/users/goals/create-daily", response_model=List[GoalSchema])
def create_daily_goals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create new daily goals for the current day if they don't exist"""
    today = date.today()
    
    # Get existing daily goals for today
    existing_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.goal_type.in_(DAILY_GOALS),
        Goal.start_date == today
    ).all()
    
    # If we already have all daily goals for today, return them
    if len(existing_goals) == len(DAILY_GOALS):
        return existing_goals
    
    # Get the most recent daily goals to copy target values
    recent_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.goal_type.in_(DAILY_GOALS)
    ).order_by(Goal.start_date.desc()).all()
    
    # Create a map of goal types to their target values
    target_values = {goal.goal_type: goal.target_value for goal in recent_goals}
    
    # Create new goals for today only for goal types that exist in recent_goals
    new_goals = []
    for goal_type in DAILY_GOALS:
        # Skip if we already have this goal type for today
        if any(g.goal_type == goal_type for g in existing_goals):
            continue
            
        # Only create new goal if user has previously set up this type of goal
        if goal_type in target_values:
            # Double check no goal exists for today (race condition prevention)
            existing_today = db.query(Goal).filter(
                Goal.user_id == current_user.id,
                Goal.goal_type == goal_type,
                Goal.start_date == today
            ).first()
            
            if not existing_today:
                new_goal = Goal(
                    user_id=current_user.id,
                    goal_type=goal_type,
                    target_value=target_values[goal_type],
                    current_value=0.0,
                    start_date=today,
                    target_date=today
                )
                db.add(new_goal)
                new_goals.append(new_goal)
    
    db.commit()
    return existing_goals + new_goals

@router.get("/users/goals", response_model=List[GoalSchema])
def get_user_goals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all goals for the current user"""
    today = date.today()
    
    # Check if we have any daily goals for today
    has_todays_daily_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.goal_type.in_(DAILY_GOALS),
        Goal.start_date == today
    ).first() is not None
    
    # Only create daily goals if we don't have any for today and user has previously set up daily goals
    if not has_todays_daily_goals:
        has_previous_daily_goals = db.query(Goal).filter(
            Goal.user_id == current_user.id,
            Goal.goal_type.in_(DAILY_GOALS)
        ).first() is not None
        
        if has_previous_daily_goals:
            create_daily_goals(current_user, db)
    
    # Return all goals
    return db.query(Goal).filter(Goal.user_id == current_user.id).all()

@router.get("/users/goals/{goal_id}", response_model=GoalSchema)
def get_user_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific goal by ID"""
    goal = db.query(Goal).filter(Goal.id == goal_id, Goal.user_id == current_user.id).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return goal

@router.put("/users/goals/{goal_id}", response_model=GoalSchema)
def update_user_goal(
    goal_id: int,
    goal_update: GoalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update a specific goal"""
    goal = db.query(Goal).filter(Goal.id == goal_id, Goal.user_id == current_user.id).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    # Update only provided fields
    for field, value in goal_update.dict(exclude_unset=True).items():
        setattr(goal, field, value)
    
    # For daily goals, ensure target_date stays as today
    if goal.goal_type in DAILY_GOALS:
        goal.target_date = date.today()
    
    db.commit()
    db.refresh(goal)
    return goal

@router.delete("/users/goals/{goal_id}")
def delete_user_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a specific goal"""
    goal = db.query(Goal).filter(Goal.id == goal_id, Goal.user_id == current_user.id).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    
    db.delete(goal)
    db.commit()
    return {"message": "Goal deleted successfully"}

@router.get("/users/goals/{goal_id}/progress", response_model=GoalProgress)
def get_goal_progress(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get progress information for a specific goal"""
    goal = db.query(Goal).filter(Goal.id == goal_id, Goal.user_id == current_user.id).first()
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    # Calculate progress
    if goal.current_value is None:
        progress_percentage = 0.0
    else:
        progress_percentage = (goal.current_value / goal.target_value) * 100

    # Calculate remaining days if target date exists
    remaining_days = None
    if goal.target_date:
        remaining_days = (goal.target_date - date.today()).days

    return GoalProgress(
        goal_id=goal.id,
        progress_percentage=min(100.0, max(0.0, progress_percentage)),  # Clamp between 0-100
        remaining_days=remaining_days,
        current_value=goal.current_value or 0.0,
        target_value=goal.target_value,
        goal_type=goal.goal_type
    )

@router.get("/users/weekly-progress")
def get_weekly_progress(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get progress data for daily goals over the last 7 days"""
    today = date.today()
    seven_days_ago = today - timedelta(days=6)  # Include today, so 6 days ago for 7 total days
    
    # Get all daily goals for the last 7 days
    weekly_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.goal_type.in_(DAILY_GOALS),
        Goal.start_date >= seven_days_ago,
        Goal.start_date <= today
    ).order_by(Goal.start_date).all()
    
    # Group goals by date
    progress_by_date = {}
    for goal in weekly_goals:
        date_str = goal.start_date.isoformat()
        if date_str not in progress_by_date:
            progress_by_date[date_str] = {}
        progress_by_date[date_str][goal.goal_type] = {
            'current': goal.current_value,
            'target': goal.target_value
        }
    
    # Fill in missing dates with zero values
    for i in range(7):
        current_date = today - timedelta(days=i)
        date_str = current_date.isoformat()
        if date_str not in progress_by_date:
            progress_by_date[date_str] = {}
            for goal_type in DAILY_GOALS:
                progress_by_date[date_str][goal_type] = {
                    'current': 0.0,
                    'target': 0.0
                }
    
    # Convert to list format for frontend
    weekly_data = []
    for date_str in sorted(progress_by_date.keys()):
        daily_data = {
            'date': date_str,
            'goals': progress_by_date[date_str]
        }
        weekly_data.append(daily_data)
    
    return weekly_data

@router.get("/users/dashboard")
def get_dashboard_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get comprehensive dashboard data including meals, goals, and workouts"""
    today = date.today()
    
    # Get today's goals
    today_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.start_date == today
    ).all()
    
    # Get today's meals with their food items
    today_meals = db.query(Meal).filter(
        Meal.user_id == current_user.id,
        Meal.date == today
    ).all()
    
    # Calculate total nutrition from meals
    total_calories = 0
    total_protein = 0
    total_carbs = 0
    total_fats = 0
    
    for meal in today_meals:
        for meal_food in meal.meal_food_items:
            food_item = meal_food.food_item
            quantity = meal_food.quantity
            total_calories += food_item.calories * quantity
            total_protein += food_item.protein * quantity
            total_carbs += food_item.carbs * quantity
            total_fats += food_item.fats * quantity
    
    # Get today's workouts
    today_workouts = db.query(Workout).filter(
        Workout.user_id == current_user.id,
        Workout.date == today
    ).all()
    
    # Calculate total workout duration and exercises
    total_duration = sum(workout.duration for workout in today_workouts)
    total_exercises = sum(len(workout.exercises) for workout in today_workouts)
    
    # Get workout details with exercises and their logs
    workout_details = []
    for workout in today_workouts:
        exercises_details = []
        for exercise in workout.exercises:
            # Get exercise logs
            logs = db.query(ExerciseLog).filter(
                ExerciseLog.exercise_id == exercise.id
            ).order_by(ExerciseLog.set_number).all()
            
            exercises_details.append({
                "name": exercise.exercise_type.name,
                "sets": exercise.sets,
                "logs": [
                    {
                        "set": log.set_number,
                        "weight": log.weight,
                        "reps": log.reps
                    } for log in logs
                ]
            })
        
        workout_details.append({
            "name": workout.name,
            "duration": workout.duration,
            "exercise_count": len(workout.exercises),
            "exercises": exercises_details
        })
    
    # Get weekly progress (reuse existing endpoint)
    weekly_progress = get_weekly_progress(current_user, db)
    
    return {
        "goals": {
            "daily": [
                {
                    "type": goal.goal_type,
                    "current": goal.current_value or 0.0,
                    "target": goal.target_value,
                    "progress": (goal.current_value or 0.0) / goal.target_value if goal.target_value > 0 else 0.0
                }
                for goal in today_goals
            ]
        },
        "nutrition": {
            "calories": total_calories,
            "protein": total_protein,
            "carbs": total_carbs,
            "fats": total_fats
        },
        "workouts": {
            "count": len(today_workouts),
            "total_duration": total_duration,
            "total_exercises": total_exercises,
            "details": workout_details
        },
        "weekly_progress": weekly_progress
    }