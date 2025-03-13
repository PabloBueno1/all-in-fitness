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

# Conversion table for handling household measurements to grams
MEASUREMENT_CONVERSION = {
    "cup": 240,  # 1 cup ≈ 240g
    "tbsp": 15,  # 1 tablespoon ≈ 15g
    "tsp": 5,   # 1 teaspoon ≈ 5g
    "oz": 28.35,  # 1 ounce ≈ 28.35g
    "lb": 453.59,  # 1 pound ≈ 453.59g
    "fl oz": 29.57,  # 1 fluid ounce ≈ 29.57g
    "ml": 1,  # 1 milliliter ≈ 1g (assuming water density)
    "g": 1,  # 1 gram = 1g (base unit)
    "mg": 0.001,  # 1 milligram = 0.001g
    "kg": 1000,  # 1 kilogram = 1000g
    "piece": 100,  # Default assumption for 1 piece/serving
    "serving": 100  # Default assumption for 1 serving
}

# Function to fetch food data from USDA API
def fetch_usda_foods(query: str, page_size: int = 15):
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
                for unit, factor in MEASUREMENT_CONVERSION.items():
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
            "serving_size": round(serving_size),
            "calories": round(nutrients.get("Energy", 0)),
            "protein": round(nutrients.get("Protein", 0)),
            "carbs": round(nutrients.get("Carbohydrate, by difference", 0)),
            "fats": round(nutrients.get("Total lipid (fat)", 0)),
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

def fetch_food_by_barcode(barcode: str):
    """
    Fetch food data from USDA API using a barcode (UPC/GTIN)
    Args:
        barcode (str): The barcode/UPC number of the food item
    Returns:
        dict: Normalized food data or None if not found
    """
    params = {
        "api_key": USDA_API_KEY,
        "query": barcode,
        "pageSize": 1
    }
    
    response = requests.get(USDA_SEARCH_URL, params=params)
    
    if response.status_code != 200:
        print(f"USDA API Error: {response.status_code}")
        return None
        
    foods = response.json().get("foods", [])
    
    # If no food found with this barcode
    if not foods:
        return None
        
    food = foods[0]  # Get the first (and should be only) match
    
    # Get serving size - handle different food types
    serving_size = 0
    data_type = food.get("dataType", "Unknown")
    serving_size_unit = None

    if data_type == "Branded":
        serving_size = food.get("servingSize", 0)
        serving_size_unit = food.get("servingSizeUnit", "").lower()
        household_serving = food.get("householdServingFullText", "")
        
        # Try to get serving size from household serving text if not available
        if not serving_size and household_serving:
            serving_text = household_serving.lower()
            match = re.search(r"(\d+(\.\d+)?)", serving_text)
            quantity = float(match.group(1)) if match else None
            for unit, factor in MEASUREMENT_CONVERSION.items():
                if unit in serving_text and quantity:
                    serving_size = quantity * factor
                    serving_size_unit = "g"
                    break
    elif data_type == "Survey (FNDDS)":
        if "finalFoodInputFoods" in food and food["finalFoodInputFoods"]:
            serving_size = food["finalFoodInputFoods"][0].get("gramWeight", 0)
            serving_size_unit = "g"
    elif data_type in ["Foundation", "SR Legacy"]:
        if "foodPortions" in food and food["foodPortions"]:
            first_portion = food["foodPortions"][0]
            serving_size = first_portion.get("gramWeight", 0)
            serving_size_unit = "g"

    # If no serving size was found, default to 100g for scaling
    if serving_size == 0:
        serving_size = 100
        serving_size_unit = "g"
    
    # Extract nutrients and construct name based on food type
    nutrients = {}
    
    if data_type == "Branded":
        # For branded foods, use brand name and product name
        brand_name = food.get("brandOwner", "")
        brand_name = brand_name.replace("&amp;", "&")  # Fix common HTML entities
        product_name = food.get("description", "Unknown")
        
        # Clean up the product name if it contains the brand name
        if brand_name and product_name.lower().startswith(brand_name.lower()):
            product_name = product_name[len(brand_name):].strip(" ,")
        
        # Combine brand and product name for branded items
        full_name = f"{brand_name} - {product_name}" if brand_name else product_name
        
        # Extract nutrients (values are already per serving for branded foods)
        for nutrient in food.get("foodNutrients", []):
            if "nutrientName" in nutrient and "value" in nutrient:
                nutrient_name = nutrient["nutrientName"].lower()
                nutrient_value = nutrient["value"]
                
                # Map common nutrient names for branded foods
                if "energy" in nutrient_name or "calories" in nutrient_name:
                    nutrients["Energy"] = nutrient_value
                elif "protein" in nutrient_name:
                    nutrients["Protein"] = nutrient_value
                elif "carbohydrate" in nutrient_name and "total" in nutrient_name:
                    nutrients["Carbohydrate, by difference"] = nutrient_value
                elif "fat" in nutrient_name and "total" in nutrient_name:
                    nutrients["Total lipid (fat)"] = nutrient_value
                else:
                    nutrients[nutrient["nutrientName"]] = nutrient_value
    
    else:  # Non-branded foods (Survey, Foundation, SR Legacy)
        # Use the description as the name
        full_name = food.get("description", "Unknown")
        
        # Extract nutrients and scale them from per 100g to per serving
        for nutrient in food.get("foodNutrients", []):
            if "nutrientName" in nutrient and "value" in nutrient:
                nutrient_name = nutrient["nutrientName"]
                nutrient_value = (nutrient["value"] * serving_size) / 100
                
                if any(x in nutrient_name.lower() for x in ["energy", "calorie", "kcal"]):
                    nutrients["Energy"] = nutrient_value
                elif "protein" in nutrient_name.lower():
                    nutrients["Protein"] = nutrient_value
                elif any(x in nutrient_name.lower() for x in ["carbohydrate", "carb"]):
                    nutrients["Carbohydrate, by difference"] = nutrient_value
                elif any(x in nutrient_name.lower() for x in ["fat", "lipid"]):
                    if "total" in nutrient_name.lower():
                        nutrients["Total lipid (fat)"] = nutrient_value
                else:
                    nutrients[nutrient_name] = nutrient_value
    
    # Return normalized food data
    return {
        "id": 0,  # Placeholder for USDA data
        "name": full_name.title(),  # Use the full name we constructed
        "serving_size": round(serving_size),
        "serving_unit": serving_size_unit,
        "calories": round(nutrients.get("Energy", 0)),
        "protein": round(nutrients.get("Protein", 0)),
        "carbs": round(nutrients.get("Carbohydrate, by difference", 0)),
        "fats": round(nutrients.get("Total lipid (fat)", 0)),
        "is_custom": False,
        "nutrients_debug": nutrients,  # Keep debug info
        "data_type": data_type,  # Add food type for debugging
        "raw_food": food  # Add raw food data for debugging
    }
