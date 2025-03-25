from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Exercise, ExerciseLog, Workout, Goal
from app.schemas import ExerciseLogCreate, ExerciseLogResponse
from app.auth import get_current_user
from datetime import date

router = APIRouter()

def _update_weightlifting_goals(db: Session, current_user: User, exercise: Exercise, today: date):
    """Helper function to update weightlifting goals for an exercise"""
    if exercise.workout.date == today:
        # Get all logs for this exercise
        exercise_logs = db.query(ExerciseLog).filter(
            ExerciseLog.exercise_id == exercise.id
        ).all()

        # Find the highest weight logged for this exercise
        max_weight = max((log.weight for log in exercise_logs), default=0)

        # Look for weightlifting goals for this exercise
        goal_type = f"weightlifting:{exercise.exercise_type.name}"
        goals = db.query(Goal).filter(
            Goal.user_id == current_user.id,
            Goal.goal_type == goal_type
        ).all()

        for goal in goals:
            # Update the current value with the highest weight
            goal.current_value = max_weight
            goal.is_completed = goal.current_value >= goal.target_value

@router.post("/exercise_logs", response_model=ExerciseLogResponse)
def log_exercise_set(
    log: ExerciseLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify the exercise exists and get its workout_id
    exercise = db.query(Exercise).filter(Exercise.id == log.exercise_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    # Create the exercise log
    new_log = ExerciseLog(
        exercise_id=log.exercise_id,
        set_number=log.set_number,
        weight=log.weight,
        reps=log.reps
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)

    # Update weightlifting goals
    _update_weightlifting_goals(db, current_user, exercise, date.today())
    db.commit()
    return new_log

@router.get("/exercise_logs/{workout_id}/{exercise_id}")
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

@router.patch("/exercise_logs/{log_id}", response_model=ExerciseLogResponse)
def partial_update_exercise_log(
    log_id: int,
    log_update: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
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

    for field, value in log_update.items():
        setattr(exercise_log, field, value)

    db.commit()
    db.refresh(exercise_log)

    # Update weightlifting goals
    _update_weightlifting_goals(db, current_user, exercise_log.exercise, date.today())
    db.commit()

    return exercise_log

@router.delete("/exercise_logs/{log_id}")
def delete_exercise_log(
    log_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
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

    exercise = exercise_log.exercise
    db.delete(exercise_log)
    db.commit()

    # Update weightlifting goals
    _update_weightlifting_goals(db, current_user, exercise, date.today())
    db.commit()

    return {"message": "Exercise log deleted successfully"} 