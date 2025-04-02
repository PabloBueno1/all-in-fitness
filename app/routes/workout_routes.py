from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Workout, Exercise, ExerciseLog, ExerciseTypes, UserProfile
from app.schemas import WorkoutCreate, WorkoutResponse, WorkoutUpdate
from app.auth import get_current_user
from app.gpt_service import GPTService
from sqlalchemy import func
from datetime import datetime, timedelta
from typing import List, Dict

router = APIRouter()

@router.post("/workouts", response_model=WorkoutResponse)
def create_workout(workout: WorkoutCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    new_workout = Workout(
        name=workout.name,
        duration=workout.duration,
        user_id=current_user.id,
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
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    try:
        exercise_ids = (
            db.query(Exercise.id)
            .filter(Exercise.workout_id == workout_id)
            .all()
        )
        exercise_ids = [e[0] for e in exercise_ids]

        if exercise_ids:
            db.query(ExerciseLog).filter(ExerciseLog.exercise_id.in_(exercise_ids)).delete(synchronize_session=False)
            db.commit()
        
        return {"message": "Exercise logs deleted successfully"}
    except Exception as e:
        db.rollback()
        print(f"Error deleting workout logs: {e}")
        raise HTTPException(status_code=500, detail="Error deleting workout logs")

@router.delete("/workouts/{workout_id}/exercises")
def delete_workout_exercises(
    workout_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    db.query(Exercise).filter(Exercise.workout_id == workout_id).delete(synchronize_session=False)
    db.commit()
    
    return {"message": "Workout exercises deleted successfully"}

@router.delete("/workouts/{workout_id}")
def delete_workout(
    workout_id: int, 
    current_user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    try:
        # First get all exercise IDs for this workout
        exercise_ids = (
            db.query(Exercise.id)
            .filter(Exercise.workout_id == workout_id)
            .all()
        )
        exercise_ids = [e[0] for e in exercise_ids]

        # Delete logs for these exercises
        if exercise_ids:
            db.query(ExerciseLog).filter(ExerciseLog.exercise_id.in_(exercise_ids)).delete(synchronize_session=False)

        # Delete all exercises in the workout
        db.query(Exercise).filter(Exercise.workout_id == workout_id).delete(synchronize_session=False)

        # Finally delete the workout
        db.delete(workout)
        db.commit()

        return {"message": "Workout deleted successfully"}
    except Exception as e:
        db.rollback()
        print(f"Error deleting workout: {e}")
        raise HTTPException(status_code=500, detail="Error deleting workout")

@router.patch("/workouts/{workout_id}", response_model=WorkoutResponse)
def update_workout(
    workout_id: int,
    workout_update: WorkoutUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Get the existing workout
    workout = db.query(Workout).filter(
        Workout.id == workout_id,
        Workout.user_id == current_user.id
    ).first()

    if not workout:
        raise HTTPException(status_code=404, detail="Workout not found or unauthorized")

    # Update only the fields that were provided
    update_data = workout_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(workout, field, value)

    try:
        db.commit()
        db.refresh(workout)
        return workout
    except Exception as e:
        db.rollback()
        print(f"Error updating workout: {e}")
        raise HTTPException(status_code=500, detail="Error updating workout")

@router.get("/workouts/recommendations")
async def get_workout_recommendations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get AI-generated workout recommendations based on user's profile and workout history."""
    try:
        # Get user's fitness level from profile
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        if not user_profile or not user_profile.fitness_level:
            raise HTTPException(status_code=400, detail="User profile or fitness level not set")

        # Get recent workouts (last 7 days)
        recent_date = datetime.now() - timedelta(days=7)
        recent_workouts = []
        
        workouts = (
            db.query(Workout)
            .filter(Workout.user_id == current_user.id, Workout.date >= recent_date)
            .all()
        )

        for workout in workouts:
            exercises = []
            for exercise in workout.exercises:
                exercise_type = db.query(ExerciseTypes).filter(ExerciseTypes.id == exercise.exercise_id).first()
                if exercise_type:
                    exercises.append({
                        'name': exercise_type.name,
                        'muscles': exercise_type.muscles,
                        'category': exercise_type.category,
                        'sets': exercise.sets
                    })
            
            recent_workouts.append({
                'id': workout.id,
                'name': workout.name,
                'date': workout.date,
                'duration': workout.duration,
                'exercises': exercises
            })

        # Calculate typical workout duration (average of last 7 days)
        typical_duration = 60  # default
        if workouts:
            typical_duration = int(sum(w.duration for w in workouts) / len(workouts))

        # Get workout recommendations from GPT service
        recommendations = await GPTService.generate_workout_recommendations(
            fitness_level=user_profile.fitness_level,
            recent_workouts=recent_workouts,
            typical_duration=typical_duration
        )

        return {
            "success": True,
            "data": recommendations
        }

    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error generating workout recommendations: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate workout recommendations"
        ) 