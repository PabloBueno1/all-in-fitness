import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  _MealsPageState createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> {
  List meals = [];
  List foodItems = [];
  Map<int, List> mealFoodItems = {};
  Map<int, String> mealSearchQueries = {}; // Meal-specific search text
  Map<int, bool> isSearchingMeal = {}; // For tracking search status per meal

  final String searchApiUrl = 'http://localhost:8000/food_items/search';
  final String postApiUrl = 'http://localhost:8000/food_items';

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  /// ✅ Fetch Meals
  Future<void> _fetchMeals() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/meals'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List decodedResponse = json.decode(response.body);
      setState(() {
        meals = decodedResponse.map((meal) {
          return {
            'id': meal['id'] ?? -1,
            'name': meal['name'] ?? 'Unknown Meal',
            'date': meal['date']?.toString() ?? 'Unknown Date',
          };
        }).toList();
      });

      for (var meal in meals) {
        _fetchMealFoodItems(meal['id']);
      }
    } else {
      print("Failed to fetch meals: ${response.statusCode}");
    }
  }

  /// Delete Meal
  Future<void> _deleteMeal(int mealId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.delete(
      Uri.parse('http://localhost:8000/meals/$mealId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        meals.removeWhere((meal) => meal['id'] == mealId);
        mealFoodItems.remove(mealId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal deleted successfully!")),
      );
    } else {
      print("❌ Failed to delete meal: ${response.statusCode}");
    }
  }

  /// Fetch available food items
  Future<void> _fetchFoodItems() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/food_items'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List decodedResponse = json.decode(response.body);
      setState(() {
        foodItems = decodedResponse.map((food) {
          return {
            'id': food['id'] ?? -1,
            'name': food['name'] ?? 'Unknown Food',
          };
        }).toList();
      });
    } else {
      print("❌ Failed to fetch food items: ${response.statusCode}");
    }
  }

  /// ✅ Search food items (USDA + DB)
  Future<List<Map<String, dynamic>>> searchFoodItems(String query) async {
    if (query.isEmpty) return [];

    try {
      print("🔍 Searching for: $query");
      final response = await http.get(Uri.parse('$searchApiUrl?query=$query'));

      if (response.statusCode == 200) {
        List<dynamic> foods = json.decode(response.body);
        print("✅ Search results: $foods");
        return foods.cast<Map<String, dynamic>>();
      } else {
        print("❌ Search API Error: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("⚠️ Error during search: $e");
      return [];
    }
  }

  /// ✅ POST: Add Selected Food to DB if from USDA
  Future<Map<String, dynamic>?> addFoodToDB(Map<String, dynamic> food) async {
    if (food['id'] == 0) {
      final response = await http.post(
        Uri.parse(postApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(food),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final savedFood = json.decode(response.body);
        return {
          ...food, // Keep all existing data
          'id': savedFood['id'], // Ensure we use the new ID from DB
        };
      } else {
        return null;
      }
    }
    return food;
  }

  /// ✅ Fetch Meal Food Items
  Future<void> _fetchMealFoodItems(int mealId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('http://localhost:8000/meal_food_items/$mealId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      List decodedResponse = json.decode(response.body);

      setState(() {
        mealFoodItems[mealId] = decodedResponse.map((food) {
          return {
            'food_id': food['food_id'],
            'food_name': food['food_name'] ?? 'Unknown Food',
            'quantity': food['quantity']?.toDouble() ?? 1.0,
            'calories_per_item': food['calories_per_item'] ?? 0.0,
            'serving_size': food['serving_size'] ?? 100,  // ✅ Default serving size
            'protein': food['protein'] ?? 0,  // ✅ Ensure protein is included
            'carbs': food['carbs'] ?? 0,
            'fats': food['fats'] ?? 0,
            'is_custom': food['is_custom'] ?? false,
          };
        }).toList();
      });
    } else {
      print("❌ Failed to fetch meal food items: ${response.statusCode}");
    }
  }

  /// ✅ Add food directly to the Meal
  Future<void> _addFoodToMeal(int mealId, int foodId, double quantity) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      print("❌ Error: No token found. Please log in.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication error: Please log in again.")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('http://localhost:8000/meal_food_items'),
      headers: {
        'Authorization': 'Bearer $token', // ✅ Include the token
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "meal_id": mealId,
        "food_item_id": foodId,
        "quantity": quantity,
      }),
    );

    if (response.statusCode == 200) {
      await _fetchMealFoodItems(mealId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food added to meal!")),
      );
    } else {
      print("❌ Failed to add food to meal: ${response.statusCode}, Response: ${response.body}");
    }
  }

  /// Remove food from meal
  Future<void> _removeFoodFromMeal(int mealId, int foodId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.delete(
      Uri.parse('http://localhost:8000/meal_food_items/$mealId/$foodId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        mealFoodItems[mealId]?.removeWhere((food) => food['food_id'] == foodId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food item removed from meal!")),
      );
    } else {
      print("❌ Failed to remove food from meal: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Meals")),
      body: Column(
        children: [
          // Buttons at the top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, '/create-meal');
                    if (result == true) {
                      _fetchMeals(); // Refresh meals list when returning
                    }
                  },
                  child: const Text("Create Meal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/add-food');
                  },
                  child: const Text("Manually Add Food"),
                ),
              ],
            ),
          ),
          // List of meals
          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (context, index) {
                final meal = meals[index];
                final mealId = meal['id'];

                return Card(
                  child: ExpansionTile(
                    title: Text(meal['name']),
                    subtitle: Text("Date: ${meal['date']}"),
                    leading: const Icon(Icons.restaurant_menu, color: Colors.blue),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteMeal(mealId),
                        ),
                        const Icon(Icons.expand_more, color: Colors.grey),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    children: [
                      // 🍽️ Meal's Food List
                      Column(
                        children: mealFoodItems[mealId]?.map<Widget>((food) {
                          int foodId = food['food_id'];
                          double totalCalories = food['quantity'] * food['calories_per_item'];
                          return ListTile(
                            title: Text(food['food_name']),
                            subtitle: Text("Total Calories: ${totalCalories.toStringAsFixed(2)}"),
                            leading: const Icon(Icons.edit, color: Colors.blue),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _removeFoodFromMeal(mealId, foodId),
                            ),
                            tileColor: Colors.grey[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            onTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/food-details',
                                arguments: {
                                  'food': food,
                                  'mealId': mealId,
                                },
                              );

                              // ✅ Refresh meal food items if food was successfully added
                              if (result == true) {
                                _fetchMealFoodItems(mealId);
                              }
                            },
                          );
                        }).toList() ??
                        [],
                      ),

                      // 🔍 Search Bar Inside Meal
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "Search Food to Add",
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) {
                            setState(() {
                              mealSearchQueries[mealId] = value;
                              isSearchingMeal[mealId] = value.isNotEmpty;
                            });
                          },
                        ),
                      ),

                      // 🔄 Meal-specific Search Results
                      isSearchingMeal[mealId] == true
                          ? FutureBuilder<List<Map<String, dynamic>>>(
                              future: searchFoodItems(mealSearchQueries[mealId] ?? ''),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                } else if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                  return const Text('No food found.');
                                } else {
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: snapshot.data!.length,
                                    itemBuilder: (context, index) {
                                      final food = snapshot.data![index];
                                      return ListTile(
                                        title: Text(food['name']),
                                        onTap: () async {
                                          final result = await Navigator.pushNamed(
                                            context,
                                            '/food-details',
                                            arguments: {
                                              'food': food,
                                              'mealId': mealId,
                                            },
                                          );

                                          // ✅ Refresh meal food items if food was successfully added
                                          if (result == true) {
                                            _fetchMealFoodItems(mealId);
                                          }
                                        },
                                        trailing: ElevatedButton(
                                          child: const Text("Add"),
                                          onPressed: () async {
                                            // Check if food is already in the meal
                                            bool isAlreadyAdded = mealFoodItems[mealId]?.any((item) => item['food_id'] == food['id']) ?? false;
                                            
                                            if (isAlreadyAdded) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("This food is already in the meal. Tap on it to edit the quantity."),
                                                ),
                                              );
                                              return;
                                            }

                                            if (food['id'] == 0) {
                                              // If the food item comes from USDA, save it to the database first
                                              final savedFood = await addFoodToDB(food);
                                              if (savedFood != null) {
                                                _addFoodToMeal(mealId, savedFood['id'], 1.0); // Use the new ID from DB
                                              }
                                            } else {
                                              // If it's already in DB, directly add it to the meal
                                              _addFoodToMeal(mealId, food['id'], 1.0);
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  );
                                }
                              },
                            )
                          : const SizedBox(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
