from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models import User, Workout, Exercise, ExerciseTypes, ExerciseLog
from app.schemas import ExerciseCreate, ExerciseResponse, ExerciseTypeCreate, ExerciseTypeResponse
from app.auth import get_current_user
from app.wger_api import fetch_wger_exercises

router = APIRouter()

@router.post("/exercise_types", response_model=ExerciseTypeResponse)
def create_exercise_type(
    exercise: ExerciseTypeCreate, 
    db: Session = Depends(get_db)
):
    existing_exercise = db.query(ExerciseTypes).filter(ExerciseTypes.name == exercise.name).first()
    if existing_exercise:
        raise HTTPException(status_code=400, detail="Exercise name already exists")

    new_exercise = ExerciseTypes(**exercise.dict())
    db.add(new_exercise)
    db.commit()
    db.refresh(new_exercise)
    
    return new_exercise

@router.get("/exercise_types", response_model=list[ExerciseTypeResponse])
def get_exercise_types(db: Session = Depends(get_db)):
    return db.query(ExerciseTypes).all()

@router.post("/exercises", response_model=ExerciseResponse)
def create_exercise_entry(exercise: ExerciseCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    workout = db.query(Workout).filter(Workout.id == exercise.workout_id, Workout.user_id == current_user.id).first()
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

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
        .join(Workout, Workout.id == Exercise.workout_id)
        .join(ExerciseTypes, Exercise.exercise_id == ExerciseTypes.id)
        .filter(Exercise.workout_id == workout_id, Workout.user_id == current_user.id)
        .all()
    )

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
    workout = db.query(Workout).filter(Workout.id == workout_id, Workout.user_id == current_user.id).first()
    
    if not workout:
        raise HTTPException(status_code=400, detail="Invalid workout_id or unauthorized")

    exercise = db.query(Exercise).filter(
        Exercise.id == exercise_id,
        Exercise.workout_id == workout_id
    ).first()

    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found in workout")

    try:
        db.query(ExerciseLog).filter(ExerciseLog.exercise_id == exercise_id).delete(synchronize_session=False)
        db.delete(exercise)
        db.commit()

        return {"message": "Exercise and its logs removed from workout"}
    except Exception as e:
        db.rollback()
        print(f"Error removing exercise: {e}")
        raise HTTPException(status_code=500, detail="Error removing exercise from workout")

@router.get("/search-exercises", response_model=List[ExerciseTypeResponse])
def search_exercise_endpoint(query: str, db: Session = Depends(get_db)):
    local_results = (
        db.query(ExerciseTypes)
        .filter(ExerciseTypes.name.ilike(f"%{query}%"))
        .all()
    )
    
    if local_results:
        return local_results
    
    wger_results = fetch_wger_exercises(query)
    return wger_results

@router.get("/exercise_types/search", response_model=list[ExerciseTypeResponse])
def search_exercise_types(query: str, db: Session = Depends(get_db)):
    local_results = (
        db.query(ExerciseTypes)
        .filter(ExerciseTypes.name.ilike(f"%{query}%"))
        .all()
    )
    
    if local_results:
        return local_results
    
    wger_results = fetch_wger_exercises(query)
    return wger_results 