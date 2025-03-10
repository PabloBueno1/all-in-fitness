from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Exercise, ExerciseLog, Workout
from app.schemas import ExerciseLogCreate, ExerciseLogResponse
from app.auth import get_current_user

router = APIRouter()

@router.post("/exercise_log", response_model=ExerciseLogResponse)
def log_exercise_set(log: ExerciseLogCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
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

@router.patch("/exercise_log/{log_id}", response_model=ExerciseLogResponse)
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

    return exercise_log

@router.delete("/exercise_log/{log_id}")
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

    db.delete(exercise_log)
    db.commit()

    return {"message": "Exercise log deleted successfully"} 