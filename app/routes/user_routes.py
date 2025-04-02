from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Goal, Meal, Workout, ExerciseLog, UserProfile, ExerciseTypes, Exercise
from app.schemas import (
    UserCreate, UserLogin, GoalCreate, GoalUpdate, Goal as GoalSchema, 
    GoalProgress, UserProfileCreate, UserProfileUpdate, UserProfile as UserProfileSchema
)
from app.auth import get_password_hash, verify_password, create_access_token, get_current_user
from fastapi.security import OAuth2PasswordRequestForm
from datetime import datetime, date, timedelta
from typing import List
import math
import pytz

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
    
    # If this is a weight goal, update the profile weight
    if goal.goal_type == 'weight':
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        if profile:
            profile.weight = goal.current_value
    
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
    
    # Get all daily goals (both current and historical)
    daily_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.goal_type.in_(DAILY_GOALS)
    ).order_by(Goal.start_date.desc()).all()
    
    # Get all non-daily goals
    non_daily_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        ~Goal.goal_type.in_(DAILY_GOALS)
    ).all()
    
    # Check if we need to create today's daily goals
    has_todays_daily_goals = any(
        goal.start_date == today and goal.goal_type in DAILY_GOALS 
        for goal in daily_goals
    )
    
    # Only create daily goals if we don't have any for today and user has previously set up daily goals
    if not has_todays_daily_goals and daily_goals:  # daily_goals check ensures user has previous goals
        create_daily_goals(current_user, db)
        # Refresh daily goals to include newly created ones
        daily_goals = db.query(Goal).filter(
            Goal.user_id == current_user.id,
            Goal.goal_type.in_(DAILY_GOALS)
        ).order_by(Goal.start_date.desc()).all()
    
    # Combine and return both sets of goals
    return daily_goals + non_daily_goals

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
    update_data = goal_update.dict(exclude_unset=True)
    
    # If this is a weight goal and current_value is being updated, update the profile weight
    if goal.goal_type == 'weight' and 'current_value' in update_data:
        new_weight = update_data['current_value']
        # Update user profile weight
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        if profile:
            profile.weight = new_weight
    
    for field, value in update_data.items():
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
    timezone: str = Query(default="UTC", description="Client timezone or UTC offset"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get comprehensive dashboard data including meals, goals, and workouts"""
    # Handle both timezone names and UTC offsets
    if timezone.startswith('UTC'):
        try:
            # Parse UTC offset (e.g., UTC+4, UTC-5)
            offset_str = timezone[3:]  # Remove 'UTC'
            offset_hours = int(offset_str)
            local_now = datetime.now() + timedelta(hours=offset_hours)
            local_date = local_now.date()
        except ValueError:
            # If parsing fails, default to UTC
            local_date = date.today()
    else:
        try:
            # Try to use timezone name
            tz = pytz.timezone(timezone)
            local_now = datetime.now(tz)
            local_date = local_now.date()
        except pytz.exceptions.UnknownTimeZoneError:
            # If timezone is invalid, default to UTC
            local_date = date.today()
    
    # Get today's goals using local date
    today_goals = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.start_date == local_date
    ).all()
    
    # Get today's meals with their food items using local date
    today_meals = db.query(Meal).filter(
        Meal.user_id == current_user.id,
        Meal.date == local_date
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
    
    # Get today's workouts using local date
    today_workouts = db.query(Workout).filter(
        Workout.user_id == current_user.id,
        Workout.date == local_date
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

@router.post("/users/profile", response_model=UserProfileSchema)
def create_user_profile(
    profile: UserProfileCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if profile already exists
    existing_profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if existing_profile:
        raise HTTPException(status_code=400, detail="Profile already exists")
    
    # Create profile without target_weight
    profile_data = profile.dict(exclude={'target_weight'})
    new_profile = UserProfile(**profile_data, user_id=current_user.id)
    
    # If weight is provided, create or update today's weight goal
    if profile.weight is not None:
        today = date.today()
        weight_goal = db.query(Goal).filter(
            Goal.user_id == current_user.id,
            Goal.goal_type == 'weight',
            Goal.start_date == today
        ).first()
        
        if weight_goal:
            weight_goal.current_value = profile.weight  # Only update current_value
        else:
            new_weight_goal = Goal(
                user_id=current_user.id,
                goal_type='weight',
                current_value=profile.weight,
                target_value=profile.target_weight if profile.target_weight is not None else 0.0,  # Use target_weight if provided
                start_date=today,
                target_date=today
            )
            db.add(new_weight_goal)
    
    db.add(new_profile)
    db.commit()
    db.refresh(new_profile)
    return new_profile

@router.get("/users/profile", response_model=UserProfileSchema)
def get_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    return profile

@router.put("/users/profile", response_model=UserProfileSchema)
def update_user_profile(
    profile_update: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    # Update only the fields that were provided
    update_data = profile_update.dict(exclude_unset=True)
    
    # If weight is being updated, update any active weight goals
    if 'weight' in update_data:
        new_weight = update_data['weight']
        # Update today's weight goal if it exists
        today = date.today()
        weight_goal = db.query(Goal).filter(
            Goal.user_id == current_user.id,
            Goal.goal_type == 'weight',
            Goal.start_date == today
        ).first()
        
        if weight_goal:
            weight_goal.current_value = new_weight  # Only update current_value, not target_value
    
    for field, value in update_data.items():
        setattr(profile, field, value)
    
    db.commit()
    db.refresh(profile)
    return profile

@router.delete("/users/profile")
def delete_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    db.delete(profile)
    db.commit()
    return {"message": "Profile deleted successfully"}

@router.get("/recommendations/goals")
async def get_goal_recommendations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get personalized goal recommendations based on user profile"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found")

    # Get current weight goal if it exists
    current_weight_goal = db.query(Goal).filter(
        Goal.user_id == current_user.id,
        Goal.goal_type == 'weight'
    ).order_by(Goal.start_date.desc()).first()

    # Calculate weight goal timeline
    if current_weight_goal:
        current_weight = current_weight_goal.current_value
        target_weight = current_weight_goal.target_value
        weight_diff = abs(current_weight - target_weight)
        # Assuming 1.5-2 lbs per week is healthy weight change
        weeks_needed = math.ceil(weight_diff / 1.65)  # Using 1.65 lbs/week as average
        target_date = date.today() + timedelta(weeks=weeks_needed)
    else:
        current_weight = profile.weight
        target_weight = None
        weeks_needed = 12  # Default 12-week goal
        target_date = date.today() + timedelta(weeks=weeks_needed)

    # Calculate BMR using Mifflin-St Jeor formula adapted for imperial units
    # Original formula: (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + s
    # Converted to imperial: (4.536 * weight_lbs) + (15.875 * height_inches) - (5 * age) + s
    if profile.gender == 'male':
        bmr = (4.536 * current_weight) + (15.875 * profile.height) - (5 * 30) + 5  # Assuming age 30 for now
    else:
        bmr = (4.536 * current_weight) + (15.875 * profile.height) - (5 * 30) - 161

    # Activity multiplier based on fitness level
    activity_multiplier = {
        'beginner': 1.2,     # Sedentary/Light activity
        'intermediate': 1.375,  # Moderate activity
        'advanced': 1.55     # Very active
    }.get(profile.fitness_level, 1.2)

    # Calculate TDEE (Total Daily Energy Expenditure)
    tdee = bmr * activity_multiplier

    # Adjust calories based on weight goal
    if current_weight_goal and current_weight and target_weight:
        if target_weight < current_weight:  # Weight loss
            base_calories = tdee - 500  # 500 calorie deficit
        elif target_weight > current_weight:  # Weight gain
            base_calories = tdee + 500  # 500 calorie surplus
        else:  # Maintenance
            base_calories = tdee
    else:
        base_calories = tdee

    # Adjust calories based on dietary preferences
    if profile.dietary_preferences == 'keto':
        base_calories *= 1.05  # Slight increase for keto
    elif profile.dietary_preferences == 'vegan':
        base_calories *= 1.0  # No adjustment needed

    # Calculate macro targets based on weight goal
    if current_weight_goal and target_weight:
        if target_weight < current_weight:  # Weight loss
            protein_per_lb = 1.0  # Higher protein for preservation during cut
            fat_percentage = 0.25  # Lower fat during cut
        elif target_weight > current_weight:  # Weight gain
            protein_per_lb = 0.82  # Moderate protein for bulk
            fat_percentage = 0.3  # Moderate fat for bulk
        else:  # Maintenance
            protein_per_lb = 0.73  # Standard protein
            fat_percentage = 0.3  # Standard fat
    else:
        protein_per_lb = 0.73  # Default to standard
        fat_percentage = 0.3  # Default to standard

    # Calculate protein (prioritize based on body weight)
    protein_target = current_weight * protein_per_lb

    # Calculate fat (percentage of total calories)
    fat_calories = base_calories * fat_percentage
    fat_target = fat_calories / 9  # 9 calories per gram of fat

    # Calculate carbs (remaining calories)
    protein_calories = protein_target * 4  # 4 calories per gram of protein
    carb_calories = base_calories - protein_calories - fat_calories
    carb_target = max(0, carb_calories / 4)  # 4 calories per gram of carbs, ensure non-negative

    # Get weightlifting goals and progress
    weightlifting_recommendations = []
    
    # Get user's recent exercise history (last 7 days)
    recent_date = date.today() - timedelta(days=7)
    exercise_history = (
        db.query(Exercise, ExerciseLog)
        .join(ExerciseLog)
        .join(Workout)
        .filter(
            Workout.user_id == current_user.id,
            Workout.date >= recent_date
        )
        .order_by(Workout.date.desc())
        .all()
    )

    # Create a map of exercise type to max weight and last performed date
    exercise_stats = {}
    for exercise, log in exercise_history:
        exercise_name = exercise.exercise_type.name
        if exercise_name not in exercise_stats:
            exercise_stats[exercise_name] = {
                'max_weight': log.weight,
                'last_date': exercise.workout.date,
                'muscles': exercise.exercise_type.muscles
            }
        elif log.weight > exercise_stats[exercise_name]['max_weight']:
            exercise_stats[exercise_name]['max_weight'] = log.weight
        if exercise.workout.date > exercise_stats[exercise_name]['last_date']:
            exercise_stats[exercise_name]['last_date'] = exercise.workout.date

    # Generate weightlifting recommendations for each recently performed exercise
    for exercise_name, stats in exercise_stats.items():
        current_max = stats['max_weight']
        days_since_last = (date.today() - stats['last_date']).days
        
        # Calculate target based on fitness level
        if profile.fitness_level == 'beginner':
            target = current_max * 1.2  # 20% increase for beginners
            timeframe = "8 weeks"
        elif profile.fitness_level == 'intermediate':
            target = current_max * 1.15  # 15% increase
            timeframe = "12 weeks"
        else:  # advanced
            target = current_max * 1.1  # 10% increase
            timeframe = "16 weeks"

        # Add frequency recommendation based on days since last performed
        if days_since_last <= 2:
            frequency = "2-3 times per week"
        elif days_since_last <= 4:
            frequency = "1-2 times per week"
        else:
            frequency = "1 time per week"

        weightlifting_recommendations.append({
            "exercise_name": exercise_name,
            "current_max": current_max,
            "target_weight": round(target),
            "timeframe": timeframe,
            "frequency": frequency,
            "muscles_targeted": stats['muscles'],
            "days_since_last": days_since_last
        })

    return {
        "weight_goal": {
            "current_weight": current_weight,
            "target_weight": target_weight,
            "target_date": target_date,
            "weekly_change": 1.65,  # lbs per week
            "weeks_needed": weeks_needed,
        },
        "calorie_goal": {
            "daily_target": round(base_calories),
            "protein_target": round(protein_target),
            "carb_target": round(carb_target),
            "fat_target": round(fat_target),
        },
        "weightlifting_goals": weightlifting_recommendations,
        "recommendations": [
            f"Based on your {profile.fitness_level} fitness level and {profile.dietary_preferences} diet, we recommend:",
            f"- Daily calorie target: {round(base_calories)} calories",
            f"- Protein: {round(protein_target)}g ({round(protein_target * 4)} calories)",
            f"- Carbs: {round(carb_target)}g ({round(carb_target * 4)} calories)",
            f"- Fat: {round(fat_target)}g ({round(fat_target * 9)} calories)",
            f"- Expected timeline: {weeks_needed} weeks to reach your weight goal",
            f"- Weekly weight change: 1.65 lbs"
        ]
    }