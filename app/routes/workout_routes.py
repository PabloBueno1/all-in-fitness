from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Workout, Exercise, ExerciseLog
from app.schemas import WorkoutCreate, WorkoutResponse, WorkoutUpdate
from app.auth import get_current_user

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