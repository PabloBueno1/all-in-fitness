import requests
import os
import re
from typing import Dict, List, Optional
from dotenv import load_dotenv
from functools import lru_cache
from time import time

# Load environment variables
load_dotenv()

# Constants
BASE_URL = "https://wger.de/api/v2"
HEADERS = {
    "Accept": "application/json",
    "Content-Type": "application/json",
    "Authorization": f"Token {os.getenv('WGER_API_KEY')}" if os.getenv('WGER_API_KEY') else ""
}

# Cache for exercise details
_exercise_cache = {}
_cache_timeout = 3600  # 1 hour cache timeout

def clean_html(text: str) -> str:
    """Remove HTML tags and convert common HTML elements to plain text."""
    # Convert <ul><li> to bullet points
    text = re.sub(r'<ul>\s*', '\n', text)
    text = re.sub(r'<li>', '• ', text)
    text = re.sub(r'</li>', '\n', text)
    text = re.sub(r'</ul>', '', text)
    
    # Remove other HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    
    # Clean up whitespace
    text = re.sub(r'\s+', ' ', text)
    text = text.strip()
    
    return text

def standardize_muscles(muscles: List[str]) -> str:
    """Standardize muscle names and format."""
    if not muscles:
        return ""
    
    # Remove None values and duplicates while preserving order
    unique_muscles = []
    seen = set()
    for muscle in muscles:
        if muscle and muscle not in seen:
            seen.add(muscle)
            unique_muscles.append(muscle)
    
    # Sort alphabetically for consistency
    unique_muscles.sort()
    
    return ", ".join(unique_muscles)

@lru_cache(maxsize=1)
def get_categories() -> Dict[int, str]:
    """Get and cache exercise categories."""
    response = requests.get(f"{BASE_URL}/exercisecategory", headers=HEADERS)
    if response.status_code == 200:
        return {cat['id']: cat['name'] for cat in response.json().get("results", [])}
    return {}

@lru_cache(maxsize=1)
def get_all_muscles() -> Dict[int, str]:
    """Get and cache muscles."""
    response = requests.get(f"{BASE_URL}/muscle", headers=HEADERS)
    if response.status_code == 200:
        return {muscle['id']: muscle['name'] for muscle in response.json().get("results", [])}
    return {}

def get_exercise_details(exercise_id: int) -> Dict:
    """Get exercise details with caching."""
    current_time = time()
    
    # Check cache first
    if exercise_id in _exercise_cache:
        cached_data, timestamp = _exercise_cache[exercise_id]
        if current_time - timestamp < _cache_timeout:
            return cached_data
    
    # If not in cache or expired, fetch from API
    response = requests.get(f"{BASE_URL}/exercise/{exercise_id}", headers=HEADERS)
    if response.status_code == 200:
        data = response.json()
        _exercise_cache[exercise_id] = (data, current_time)
        return data
    return {}

def fetch_wger_exercises(query: str, language: int = 2, limit: int = 10) -> List[Dict]:
    """
    Fetch and format exercises from wger API with caching.
    Args:
        query: Search term
        language: Language ID (2 for English)
        limit: Maximum number of results to return (default reduced to 10)
    """
    # Get the basic exercise data first
    search_endpoint = f"{BASE_URL}/exercise/search"
    search_params = {
        "term": query,
        "language": language
    }
    
    response = requests.get(search_endpoint, headers=HEADERS, params=search_params)
    if response.status_code != 200:
        print(f"Wger API Error: {response.status_code}")
        return []

    exercises = response.json().get("suggestions", [])
    print(f"Found {len(exercises)} exercises matching '{query}'")
    
    # Limit the number of exercises to process
    exercises = exercises[:limit]
    
    # Get cached categories and muscles
    categories = get_categories()
    muscles = get_all_muscles()
    
    # Format the exercises
    formatted_exercises = []
    for exercise in exercises:
        # Get cached exercise details
        exercise_id = exercise.get('data', {}).get('id')
        if exercise_id:
            exercise_data = get_exercise_details(exercise_id)
        else:
            exercise_data = exercise.get('data', {})
        
        # Format muscles list
        exercise_muscles = []
        if exercise_data.get('muscles'):
            exercise_muscles.extend(muscles.get(m) for m in exercise_data['muscles'])
        if exercise_data.get('muscles_secondary'):
            exercise_muscles.extend(muscles.get(m) for m in exercise_data['muscles_secondary'])
        
        # Get category name
        category_name = categories.get(exercise_data.get('category'), '')
        
        # Clean description and standardize muscles
        description = clean_html(exercise_data.get('description', ''))
        muscle_list = standardize_muscles(exercise_muscles)
        
        # Normalize output format
        formatted_exercises.append({
            "id": 0,
            "name": exercise['value'],
            "description": description,
            "category": category_name,
            "muscles": muscle_list,
            "is_predefined": True
        })
    
    print(f"Successfully formatted {len(formatted_exercises)} exercises")
    return formatted_exercises

# Keep these simple helper functions for direct API access if needed
def get_exercises(language: int = 2) -> List[Dict]:
    endpoint = f"{BASE_URL}/exercise"
    response = requests.get(endpoint, headers=HEADERS, params={"language": language})
    response.raise_for_status()
    return response.json()["results"]

def get_exercise_categories() -> List[Dict]:
    endpoint = f"{BASE_URL}/exercisecategory"
    response = requests.get(endpoint, headers=HEADERS)
    response.raise_for_status()
    return response.json()["results"]

def get_muscles() -> List[Dict]:
    endpoint = f"{BASE_URL}/muscle"
    response = requests.get(endpoint, headers=HEADERS)
    response.raise_for_status()
    return response.json()["results"]

def search_exercises(name: str, language: int = 2) -> List[Dict]:
    """
    Search for exercises by name.
    Args:
        name: Name to search for
        language: Language ID (2 for English)
    Returns:
        List of matching exercise dictionaries
    """
    endpoint = f"{BASE_URL}/exercise/search"
    params = {
        "term": name,
        "language": language
    }
    
    response = requests.get(endpoint, headers=HEADERS, params=params)
    response.raise_for_status()
    return response.json()["suggestions"]

def get_exercise_images(exercise_id: int) -> List[Dict]:
    """
    Get images for a specific exercise.
    Args:
        exercise_id: ID of the exercise
    Returns:
        List of image dictionaries
    """
    endpoint = f"{BASE_URL}/exerciseimage"
    params = {"exercise": exercise_id}
    
    response = requests.get(endpoint, headers=HEADERS, params=params)
    response.raise_for_status()
    return response.json()["results"] 