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
    meals = relationship("Meal", back_populates="user")
    goals = relationship("Goal", back_populates="user")
    profile = relationship("UserProfile", back_populates="user", uselist=False)


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
    description = Column(String, nullable=True)
    category = Column(String, nullable=True)
    muscles = Column(String, nullable=True)
    is_predefined = Column(Boolean, default=False)

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

    # Relationships
    user = relationship("User", back_populates="meals")
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

class Goal(Base):
    __tablename__ = "goals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    goal_type = Column(String, nullable=False)  # 'weight', 'calories', 'protein', 'carbs', 'fats'
    target_value = Column(Float, nullable=False)
    current_value = Column(Float, nullable=True)
    start_date = Column(Date, nullable=False)
    target_date = Column(Date, nullable=True)
    is_completed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="goals")

class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    gender = Column(String, nullable=True)  # 'male', 'female', 'other'
    weight = Column(Float, nullable=True)  # in kg
    height = Column(Float, nullable=True)  # in cm
    fitness_level = Column(String, nullable=True)  # 'beginner', 'intermediate', 'advanced'
    dietary_preferences = Column(String, nullable=True)  # e.g., 'vegetarian', 'vegan', 'keto'
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="profile")
