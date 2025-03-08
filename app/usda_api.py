import requests
import os
import re
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from app.models import FoodItem
from dotenv import load_dotenv

# USDA API Details
load_dotenv()

USDA_API_KEY = os.getenv("USDA_API_KEY")
USDA_SEARCH_URL = os.getenv("USDA_SEARCH_URL")

# Function to fetch food data from USDA API
def fetch_usda_foods(query: str, page_size: int = 5):
    params = {
        "api_key": USDA_API_KEY,
        "query": query,
        "pageSize": page_size
    }
    response = requests.get(USDA_SEARCH_URL, params=params)

    if response.status_code != 200:
        print(f"USDA API Error: {response.status_code}")
        return []

    foods = response.json().get("foods", [])
    filtered_foods = []

    # Conversion table for handling household measurements
    conversion_table = {
        "cup": 240,  # 1 cup ≈ 240g
        "tbsp": 15,  # 1 tbsp ≈ 15g
        "tsp": 5,  # 1 tsp ≈ 5g
        "oz": 28.35,  # 1 oz ≈ 28.35g
        "lb": 453.59,  # 1 lb ≈ 453.59g
        "fl oz": 29.57,  # 1 fl oz ≈ 29.57g
        "ml": 1  # 1 ml = 1g (approximate for water)
    }

    for food in foods:
        data_type = food.get("dataType", "Unknown")

        # Extract nutrients (handles different formats)
        nutrients = {n["nutrientName"]: n["value"] for n in food.get("foodNutrients", [])}

        # Default serving size
        serving_size = 0

        # Handle different USDA food types
        if data_type == "Branded":
            # Branded foods often have a direct serving size value
            serving_size = food.get("servingSize", 0)
            if not serving_size and "householdServingFullText" in food:
                serving_text = food["householdServingFullText"].lower()
                match = re.search(r"(\d+(\.\d+)?)", serving_text)
                quantity = float(match.group(1)) if match else None
                for unit, factor in conversion_table.items():
                    if unit in serving_text and quantity:
                        serving_size = quantity * factor
                        break

        elif data_type == "Survey (FNDDS)":
            # FNDDS foods have nutrient values directly but might need scaling
            if "finalFoodInputFoods" in food and food["finalFoodInputFoods"]:
                serving_size = food["finalFoodInputFoods"][0].get("gramWeight", 0)

        elif data_type == "Foundation" or data_type == "SR Legacy":
            # Foundation & SR Legacy foods usually have "foodPortions"
            if "foodPortions" in food and food["foodPortions"]:
                first_portion = food["foodPortions"][0]
                serving_size = first_portion.get("gramWeight", 0)

        # Normalize output format
        filtered_foods.append({
            "id": 0,  # Placeholder for USDA data
            "name": food.get("description", "Unknown").title(),
            "serving_size": serving_size,
            "calories": nutrients.get("Energy", 0),
            "protein": nutrients.get("Protein", 0),
            "carbs": nutrients.get("Carbohydrate, by difference", 0),
            "fats": nutrients.get("Total lipid (fat)", 0),
            "is_custom": False
        })

    return filtered_foods



# #Raw food request
def fetch_usda_foods_raw(query: str, page_size: int = 1):
    params = {
        "api_key": USDA_API_KEY,
        "query": query,
        "pageSize": page_size
    }
    response = requests.get(USDA_SEARCH_URL, params=params)

    if response.status_code == 200:
        foods = response.json().get("foods", [])

        return foods
    else:
        print(f"USDA API Error: {response.status_code}")
        return {"error": f"USDA API returned status {response.status_code}"}

# Function to search food (Insert Only First Instance & Format Name)
def search_foods_with_cache(db: Session, query: str):
    # 30-day cache expiry
    cache_expiry = timedelta(days=30)
    now = datetime.now(timezone.utc)

    # ✅ Check local DB first
    local_results = db.query(FoodItem).filter(FoodItem.name.ilike(f"%{query}%")).all()

    # ✅ Filter out stale cached results
    fresh_results = [
        food for food in local_results
        if food.last_updated and (now - food.last_updated) < cache_expiry
    ]

    # If we have fresh local data, return it
    if fresh_results:
        return fresh_results

    # ✅ Fetch from USDA API
    usda_results = fetch_usda_foods(query)

    # ✅ Only insert the first instance if it doesn't exist
    for food in usda_results:
        raw_name = food.get("description")
        formatted_name = raw_name.title()  # ✅ Convert to Title Case (e.g., "Rice")

        nutrients = {n["nutrientName"]: n["value"] for n in food.get("foodNutrients", [])}

        # Check if formatted name already exists
        existing_food = db.query(FoodItem).filter(FoodItem.name == formatted_name).first()

        if existing_food:
            continue  # Skip duplicates

        # Insert the first unique instance
        new_food = FoodItem(
            name=formatted_name,  # ✅ Use formatted name
            serving_size=100,  # Default serving size
            calories=nutrients.get("Energy", 0),
            protein=nutrients.get("Protein", 0),
            carbs=nutrients.get("Carbohydrate, by difference", 0),
            fats=nutrients.get("Total lipid (fat)", 0),
            is_custom=False,
            last_updated=datetime.now(timezone.utc)
        )
        db.add(new_food)
        break  # ✅ Stop after first insert

    # ✅ Commit changes
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"Error during commit: {e}")

    # ✅ Re-query DB to return results
    return db.query(FoodItem).filter(FoodItem.name.ilike(f"%{query}%")).all()
