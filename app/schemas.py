from pydantic import BaseModel, EmailStr
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

class GoalBase(BaseModel):
    goal_type: str  # 'weight', 'calories', 'protein', 'carbs', 'fats'
    target_value: float
    current_value: Optional[float] = None
    start_date: date
    target_date: Optional[date] = None

class GoalCreate(GoalBase):
    @validator('current_value')
    def validate_current_value(cls, v, values):
        if 'goal_type' in values and values['goal_type'] == 'weight' and v is None:
            raise ValueError('Current value is required for weight goals')
        return v

class GoalUpdate(BaseModel):
    target_value: Optional[float] = None
    current_value: Optional[float] = None
    target_date: Optional[date] = None
    is_completed: Optional[bool] = None

class Goal(GoalBase):
    id: int
    user_id: int
    is_completed: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class GoalProgress(BaseModel):
    goal_id: int
    progress_percentage: float
    remaining_days: Optional[int]
    current_value: float
    target_value: float
    goal_type: str

class UserProfileBase(BaseModel):
    gender: Optional[str] = None  # 'male', 'female', 'other'
    weight: Optional[float] = None  # in kg
    height: Optional[float] = None  # in cm
    fitness_level: Optional[str] = None  # 'beginner', 'intermediate', 'advanced'
    dietary_preferences: Optional[str] = None  # e.g., 'vegetarian', 'vegan', 'keto'

class UserProfileCreate(BaseModel):
    weight: Optional[float] = None
    height: Optional[float] = None
    gender: Optional[str] = None
    fitness_level: Optional[str] = None
    dietary_preferences: Optional[str] = None
    target_weight: Optional[float] = None  # Only used for creating weight goal

class UserProfileUpdate(BaseModel):
    weight: Optional[float] = None
    height: Optional[float] = None
    gender: Optional[str] = None
    fitness_level: Optional[str] = None
    dietary_preferences: Optional[str] = None

class UserProfile(UserProfileBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True