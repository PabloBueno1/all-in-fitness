from fastapi import APIRouter
from .user_routes import router as user_router
from .workout_routes import router as workout_router
from .exercise_routes import router as exercise_router
from .exercise_log_routes import router as exercise_log_router
from .food_routes import router as food_router
from .meal_routes import router as meal_router

router = APIRouter()

# Include all route modules
router.include_router(user_router)
router.include_router(workout_router)
router.include_router(exercise_router)
router.include_router(exercise_log_router)
router.include_router(food_router)
router.include_router(meal_router) 