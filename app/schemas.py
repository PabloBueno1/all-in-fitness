from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional, List
from pydantic import validator

class UserCreate(BaseModel):
    name: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class WorkoutBase(BaseModel):
    name: str
    duration: int
    date: date

class WorkoutCreate(WorkoutBase):
    pass

class WorkoutResponse(WorkoutBase):
    id: int
    user_id: int
    timestamp: datetime

    class Config:
        orm_mode = True


class ExerciseTypeBase(BaseModel):
    name: str
    description: Optional[str] = None
    category: Optional[str] = None
    muscles: Optional[str] = None
    is_predefined: Optional[bool] = False

class ExerciseTypeCreate(ExerciseTypeBase):
    pass

class ExerciseTypeResponse(ExerciseTypeBase):
    id: int

    class Config:
        orm_mode = True

class ExerciseBase(BaseModel):
    workout_id: int
    exercise_id: int
    sets: int  # Total sets, reps are tracked in ExerciseLog

class ExerciseCreate(ExerciseBase):
    pass

class ExerciseResponse(ExerciseBase):
    id: int

    class Config:
        orm_mode = True

class ExerciseLogBase(BaseModel):
    exercise_id: int
    set_number: int
    weight: int
    reps: int

class ExerciseLogCreate(ExerciseLogBase):
    pass

class ExerciseLogResponse(ExerciseLogBase):
    id: int

    class Config:
        orm_mode = True

class FoodItemBase(BaseModel):
    name: str
    serving_size: float
    calories: int
    protein: float
    carbs: float
    fats: float
    is_custom: bool

class FoodItemCreate(FoodItemBase):
    pass

class FoodItemResponse(FoodItemBase):
    id: int

    class Config:
        orm_mode = True

class MealBase(BaseModel):
    name: str
    date: date

class MealCreate(MealBase):
    pass

class MealResponse(MealBase):
    id: int
    class Config:
        orm_mode = True

class MealUpdate(BaseModel):
    name: str
    date: date

    class Config:
        orm_mode = True

class MealFoodItemBase(BaseModel):
    meal_id: int
    food_item_id: int
    quantity: float

class MealFoodItemCreate(MealFoodItemBase):
    pass

class MealFoodItemResponse(MealFoodItemBase):
    id: int
    class Config:
        orm_mode = True

class UpdateFoodItemBase(BaseModel):
    quantity: float

class WorkoutUpdate(BaseModel):
    name: str
    duration: int
    date: date

    class Config:
        orm_mode = True