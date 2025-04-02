import os
import json
from typing import Dict, List, Optional
import openai
from openai import AsyncOpenAI
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure OpenAI
client = AsyncOpenAI(api_key=os.getenv('OPENAI_API_KEY'))

class GPTService:
    MODEL = "gpt-4o-mini"  # Specified cheaper model
    MAX_TOKENS = 500  # Increased token limit for complete responses
    
    @staticmethod
    async def generate_meal_recommendations(
        remaining_calories: float,
        remaining_protein: float,
        remaining_carbs: float,
        remaining_fats: float,
        dietary_preferences: Optional[List[str]] = None,
        allergies: Optional[List[str]] = None
    ) -> Dict:
        """
        Generate meal recommendations using GPT-4o-mini model based on remaining macros.
        """
        try:
            # Prompt for a protein-rich meal that contributes to goals
            prompt = (
                f"Suggest a high-protein meal that helps reach these remaining daily goals:\n"
                f"Remaining: {remaining_calories:.0f} calories, {remaining_protein:.0f}g protein, "
                f"{remaining_carbs:.0f}g carbs, {remaining_fats:.0f}g fats\n"
                f"Diet: {', '.join(dietary_preferences) if dietary_preferences else 'none'}\n\n"
                "Return a JSON object with a protein-rich meal like this:\n"
                "{\n"
                '  "meal_name": "High Protein Meal Name",\n'
                '  "ingredients": ["protein source", "healthy fat", "veggie/carb"],\n'
                '  "instructions": ["prep step", "cook step"],\n'
                '  "macros": {\n'
                '    "calories": number (300-800),\n'
                '    "protein": number (30-60g),\n'
                '    "carbs": number (20-50g),\n'
                '    "fats": number (10-30g)\n'
                "  }\n"
                "}"
            )

            # Call OpenAI API with strict settings
            response = await client.chat.completions.create(
                model=GPTService.MODEL,
                messages=[
                    {
                        "role": "system", 
                        "content": "You are a fitness meal planner. Suggest protein-rich meals with realistic portions and macros."
                    },
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,  # Slightly higher for more variety
                max_tokens=GPTService.MAX_TOKENS,
                response_format={"type": "json_object"}
            )

            # Get the response content and clean it
            content = response.choices[0].message.content.strip()
            
            try:
                # Parse the response with strict JSON validation
                meal_recommendation = json.loads(content)
                
                # Validate required fields
                required_fields = ['meal_name', 'ingredients', 'instructions', 'macros']
                macro_fields = ['calories', 'protein', 'carbs', 'fats']
                
                for field in required_fields:
                    if field not in meal_recommendation:
                        raise ValueError(f"Missing required field: {field}")
                
                for field in macro_fields:
                    if field not in meal_recommendation['macros']:
                        raise ValueError(f"Missing required macro field: {field}")

                # Ensure lists are not too long
                meal_recommendation['ingredients'] = meal_recommendation['ingredients'][:6]
                meal_recommendation['instructions'] = meal_recommendation['instructions'][:3]

                return {
                    "success": True,
                    "data": meal_recommendation
                }
            except (KeyError, ValueError) as e:
                print(f"Validation Error: {e}")
                print(f"Response content: {content}")
                raise ValueError(f"Invalid response format: {str(e)}")

        except json.JSONDecodeError as e:
            print(f"JSON Parse Error: {e}")
            print(f"Raw response content: {content}")
            return {
                "success": False,
                "error": "Failed to parse meal recommendation",
                "details": f"Invalid JSON response: {str(e)}"
            }
        except ValueError as e:
            return {
                "success": False,
                "error": "Invalid meal recommendation format",
                "details": str(e)
            }
        except Exception as e:
            print(f"General Error: {e}")
            return {
                "success": False,
                "error": "Failed to generate meal recommendation",
                "details": str(e)
            }

    @staticmethod
    async def generate_workout_recommendations(
        fitness_level: str,
        recent_workouts: List[Dict],
        typical_duration: int = 60
    ) -> Dict:
        """Generate smart workout recommendations based on workout history and previous weights."""
        try:
            # Track exercise history with weights
            exercise_history = {}
            recently_worked_muscles = set()
            
            for workout in recent_workouts:
                for exercise in workout['exercises']:
                    # Track muscles worked
                    if exercise.get('muscles'):
                        muscles = [m.strip() for m in exercise['muscles'].split(',')]
                        recently_worked_muscles.update(muscles)
                    
                    # Track exercise weights and reps
                    exercise_name = exercise.get('name')
                    if exercise_name and exercise.get('weight') and exercise.get('reps'):
                        if exercise_name not in exercise_history:
                            exercise_history[exercise_name] = []
                        exercise_history[exercise_name].append({
                            'weight': float(exercise['weight']),
                            'reps': int(exercise['reps']),
                            'date': workout.get('date')
                        })

            # Define all major muscle groups
            all_muscles = {
                'chest', 'back', 'shoulders', 'legs', 'arms', 'core',
                'biceps', 'triceps', 'quadriceps', 'hamstrings', 'calves'
            }
            
            # Prioritize muscles that haven't been worked recently
            muscles_to_target = list(all_muscles - recently_worked_muscles) or list(all_muscles)

            # Define intensity based on fitness level
            intensity_guide = {
                'beginner': 'Focus on form with moderate weights (60-70% 1RM)',
                'intermediate': 'Challenge with heavier weights (70-85% 1RM) and advanced variations',
                'advanced': 'Push limits with heavy weights (80-90% 1RM) and complex movements'
            }

            # Format exercise history for the prompt
            exercise_history_prompt = ""
            for exercise, history in exercise_history.items():
                if history:
                    latest = max(history, key=lambda x: x['date']) if history[0].get('date') else history[-1]
                    exercise_history_prompt += f"\n- {exercise}: Last performed with {latest['weight']}kg for {latest['reps']} reps"

            messages = [
                {
                    "role": "system",
                    "content": (
                        "You are an experienced strength and conditioning coach specializing in weightlifting and progressive overload. Create challenging workouts that:"
                        "\n1. Prioritize compound barbell and dumbbell exercises over bodyweight movements"
                        "\n2. Focus on progressive overload with specific weight recommendations"
                        "\n3. Include appropriate intensity and volume for the fitness level"
                        "\n4. Suggest weights based on previous performance (increase by 2.5-5kg if successful)"
                        "\n5. Target underworked muscle groups strategically"
                        "\n6. Include 4-6 exercises with emphasis on proper loading"
                        "\n7. For new exercises, estimate appropriate weights based on similar exercises"
                        "\n8. IMPORTANT: Respond with valid JSON only"
                    )
                },
                {
                    "role": "user",
                    "content": (
                        f"Create a {typical_duration}-minute {fitness_level} strength workout targeting: {', '.join(muscles_to_target[:3])}.\n"
                        f"Recently worked muscles to avoid: {', '.join(recently_worked_muscles)}.\n"
                        f"Intensity Guide: {intensity_guide[fitness_level.lower()]}\n"
                        f"Previous Exercise History:{exercise_history_prompt}\n"
                        "Emphasize barbell and dumbbell exercises with specific weight recommendations based on history.\n"
                        "Return ONLY a JSON object with this exact format:\n"
                        "{\n"
                        '  "workout_name": "Strength Focus Workout",\n'
                        '  "exercises": [{\n'
                        '    "name": "string (prefer barbell/dumbbell exercises)",\n'
                        '    "sets": number,\n'
                        '    "reps": "string (include weight % for compound lifts)",\n'
                        '    "rest_seconds": number,\n'
                        '    "notes": "string (include specific weight recommendation)",\n'
                        '    "suggested_weight": number\n'
                        '  }],\n'
                        '  "warmup": ["string"],\n'
                        '  "cooldown": ["string"],\n'
                        '  "estimated_duration_minutes": number,\n'
                        '  "difficulty_level": "string",\n'
                        '  "target_muscles": ["string"]\n'
                        "}"
                    )
                }
            ]

            response = await client.chat.completions.create(
                model="gpt-4",
                messages=messages,
                temperature=0.7,
                max_tokens=1000
            )

            content = response.choices[0].message.content.strip()
            
            try:
                # Clean the response to ensure it's valid JSON
                content = content.replace("'", '"')  # Replace single quotes with double quotes
                content = content.strip('`')  # Remove any markdown code block markers
                if content.startswith('```json'):  # Remove JSON code block markers if present
                    content = content.replace('```json', '').replace('```', '').strip()
                
                workout_data = json.loads(content)
                required_fields = {
                    'workout_name', 'exercises', 'warmup', 'cooldown',
                    'estimated_duration_minutes', 'difficulty_level', 'target_muscles'
                }
                
                if not all(field in workout_data for field in required_fields):
                    raise ValueError("Missing required fields in response")
                
                # Limit number of exercises and length of lists
                workout_data['exercises'] = workout_data['exercises'][:6]
                workout_data['warmup'] = workout_data['warmup'][:2]
                workout_data['cooldown'] = workout_data['cooldown'][:2]
                workout_data['target_muscles'] = workout_data['target_muscles'][:3]
                
                # Validate exercises structure
                for exercise in workout_data['exercises']:
                    required_exercise_fields = {'name', 'sets', 'reps', 'rest_seconds', 'notes', 'suggested_weight'}
                    if not all(field in exercise for field in required_exercise_fields):
                        raise ValueError("Missing required fields in exercise data")
                    # Keep notes concise
                    exercise['notes'] = exercise['notes'][:100]  # Increased limit for weight guidance
                
                return workout_data
                
            except json.JSONDecodeError:
                raise ValueError("Invalid JSON response from GPT")
                
        except Exception as e:
            print(f"Error generating workout: {str(e)}")
            # Return a simplified fallback workout
            target_muscle = next(iter(muscles_to_target), "full body")
            return {
                "workout_name": f"{target_muscle.title()} Focus Workout",
                "exercises": [
                    {
                        "name": "Barbell Bench Press" if target_muscle == "chest" else "Barbell Squat",
                        "sets": 4,
                        "reps": "8-10 reps at 70% 1RM",
                        "rest_seconds": 90,
                        "notes": "Start with a weight you can control for all reps with perfect form",
                        "suggested_weight": 60  # Default conservative weight
                    }
                ],
                "warmup": ["Dynamic stretches", "Light warmup sets"],
                "cooldown": ["Static stretches"],
                "estimated_duration_minutes": 30,
                "difficulty_level": fitness_level,
                "target_muscles": [target_muscle]
            }

    @staticmethod
    def validate_api_key() -> bool:
        """
        Validate that the OpenAI API key is properly configured.
        """
        return bool(os.getenv('OPENAI_API_KEY')) 