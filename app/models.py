from sqlalchemy import Column, Integer, String, ForeignKey, Boolean, Date, DateTime, func, Float
from sqlalchemy.orm import relationship
from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String, nullable=False)

    workouts = relationship("Workout", back_populates="user")
    exercises = relationship("ExerciseTypes", back_populates="user")


class Workout(Base):
    __tablename__ = "workouts"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    duration = Column(Integer, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"))
    date = Column(Date, nullable=False)
    timestamp = Column(DateTime, default=func.now())

    user = relationship("User", back_populates="workouts")
    exercises = relationship("Exercise", back_populates="workout")


class ExerciseTypes(Base):
    __tablename__ = "exercise_types"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    is_predefined = Column(Boolean, default=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)

    user = relationship("User", back_populates="exercises")


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    workout_id = Column(Integer, ForeignKey("workouts.id"), nullable=False)
    exercise_id = Column(Integer, ForeignKey("exercise_types.id"), nullable=False)
    sets = Column(Integer, nullable=False)  # Total number of sets

    workout = relationship("Workout", back_populates="exercises")
    exercise_type = relationship("ExerciseTypes")
    logs = relationship("ExerciseLog", back_populates="exercise")


class ExerciseLog(Base):
    __tablename__ = "exercise_logs"

    id = Column(Integer, primary_key=True, index=True)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)
    set_number = Column(Integer, nullable=False)
    weight = Column(Integer, nullable=False)
    reps = Column(Integer, nullable=False)

    exercise = relationship("Exercise", back_populates="logs")


class FoodItem(Base):
    __tablename__ = "food_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    serving_size = Column(Float, nullable=False)
    calories = Column(Integer, nullable=False)
    protein = Column(Float, nullable=False)
    carbs = Column(Float, nullable=False)
    fats = Column(Float, nullable=False)
    is_custom = Column(Boolean, default=False, nullable=False)  # True for user-added foods
    last_updated = Column(DateTime(timezone=True), server_default=func.now(), nullable=False) 

class Meal(Base):
    __tablename__ = "meals"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    date = Column(Date, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Relationship (Meals → MealFoodItems)
    meal_food_items = relationship("MealFoodItem", back_populates="meal")

class MealFoodItem(Base):
    __tablename__ = "meal_food_items"

    id = Column(Integer, primary_key=True, index=True)
    meal_id = Column(Integer, ForeignKey("meals.id"), nullable=False)
    food_item_id = Column(Integer, ForeignKey("food_items.id"), nullable=False)
    quantity = Column(Float, nullable=False)

    # Relationships
    meal = relationship("Meal", back_populates="meal_food_items")
    food_item = relationship("FoodItem")
