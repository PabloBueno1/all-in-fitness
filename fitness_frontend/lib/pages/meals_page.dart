import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Add Timer import
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';
import '../constants/colors.dart';
import '../widgets/user_profile_menu.dart';

class MealsPage extends StatefulWidget {
  const MealsPage({super.key});

  @override
  State<MealsPage> createState() => _MealsPageState();
}

class _MealsPageState extends State<MealsPage> with NavigationMixin {
  List meals = [];
  List foodItems = [];
  Map<int, List> mealFoodItems = {};
  Map<int, String> mealSearchQueries = {}; // Meal-specific search text
  Map<int, bool> isSearchingMeal = {}; // For tracking search status per meal
  Map<int, Timer?> _searchDebounceTimers = {}; // Add debounce timers map
  Map<int, Future<List<Map<String, dynamic>>>> _searchFutures = {}; // Store search futures
  String? username;

  final String searchApiUrl = 'http://localhost:8000/food_items/search';
  final String postApiUrl = 'http://localhost:8000/food_items';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchMeals();
  }

  @override
  void dispose() {
    // Cancel all active timers
    for (var timer in _searchDebounceTimers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:8000/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          username = data['name'];
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
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

  /// Update meal details
  Future<void> _updateMeal(int mealId, String name, String date) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final requestBody = {
      'name': name,
      'date': date,
    };
    print('Sending update request with body: $requestBody');

    try {
      final response = await http.patch(
        Uri.parse('http://localhost:8000/meals/$mealId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        _fetchMeals(); // Refresh the meals list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Meal updated successfully!")),
        );
      } else {
        print("Failed to update meal: ${response.statusCode}");
        print("Response body: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update meal: ${response.body}")),
        );
      }
    } catch (e) {
      print("Error during meal update: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An error occurred while updating the meal.")),
      );
    }
  }

  void _showEditMealDialog(Map meal) {
    final nameController = TextEditingController(text: meal['name']);
    final dateController = TextEditingController(text: meal['date']);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Edit ${meal['name']}'),
        message: Column(
          children: [
            CupertinoTextField(
              controller: nameController,
              placeholder: 'Meal Name',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: dateController,
              placeholder: 'Date (YYYY-MM-DD)',
              padding: const EdgeInsets.all(12),
              onTap: () async {
                final DateTime? picked = await showCupertinoModalPopup(
                  context: context,
                  builder: (BuildContext context) => Container(
                    height: 216,
                    padding: const EdgeInsets.only(top: 6.0),
                    margin: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    child: SafeArea(
                      top: false,
                      child: CupertinoDatePicker(
                        initialDateTime: DateTime.tryParse(meal['date']) ?? DateTime.now(),
                        mode: CupertinoDatePickerMode.date,
                        onDateTimeChanged: (DateTime newDate) {
                          dateController.text = newDate.toIso8601String().split('T')[0];
                        },
                      ),
                    ),
                  ),
                );
                if (picked != null) {
                  dateController.text = picked.toIso8601String().split('T')[0];
                }
              },
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _updateMeal(
                meal['id'],
                nameController.text,
                dateController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showBarcodeInputDialog(BuildContext context, int mealId) {
    final barcodeController = TextEditingController();
    
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Enter Barcode'),
        message: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: CupertinoTextField(
            controller: barcodeController,
            placeholder: 'Enter product barcode',
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              if (barcodeController.text.isNotEmpty) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String token = prefs.getString('token') ?? '';

                final response = await http.get(
                  Uri.parse('http://localhost:8000/food_items/scan/${barcodeController.text}'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                );

                if (response.statusCode == 200) {
                  final List<dynamic> results = json.decode(response.body);
                  if (results.isNotEmpty) {
                    final food = results[0];
                    Navigator.pop(context);
                    
                    final result = await Navigator.pushNamed(
                      context,
                      '/food-details',
                      arguments: {
                        'food': food,
                        'mealId': mealId,
                      },
                    );

                    if (result == true) {
                      _fetchMealFoodItems(mealId);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No food found with this barcode. Try another barcode or use search.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  print("Barcode search error: ${response.statusCode}, Body: ${response.body}");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error searching for food. Please try again.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: const Text('Search'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Meals',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (username != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: UserProfileMenu(username: username!),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: meals.length,
              itemBuilder: (context, index) {
                final meal = meals[index];
                final mealId = meal['id'];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Icon(CupertinoIcons.cart_fill,
                              color: kPrimaryBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal['name'],
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  "Date: ${meal['date']}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(
                              CupertinoIcons.ellipsis,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              showCupertinoModalPopup(
                                context: context,
                                builder: (context) => CupertinoActionSheet(
                                  actions: [
                                    CupertinoActionSheetAction(
                                      child: const Text('Edit Meal'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditMealDialog(meal);
                                      },
                                    ),
                                    CupertinoActionSheetAction(
                                      isDestructiveAction: true,
                                      child: const Text('Delete Meal'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteMeal(mealId);
                                      },
                                    ),
                                  ],
                                  cancelButton: CupertinoActionSheetAction(
                                    child: const Text('Cancel'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      children: [
                        Column(
                          children: [
                            ...(mealFoodItems[mealId]?.map<Widget>((food) {
                              int foodId = food['food_id'];
                              double totalCalories = food['quantity'] * food['calories_per_item'];
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: CupertinoListTile(
                                  title: Text(
                                    food['food_name'],
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Total Calories: ${totalCalories.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  leading: Icon(CupertinoIcons.pencil_circle,
                                      color: kPrimaryBlue),
                                  trailing: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: Icon(CupertinoIcons.minus_circle,
                                        color: Colors.red[400]),
                                    onPressed: () => _removeFoodFromMeal(mealId, foodId),
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
                                    if (result == true) {
                                      _fetchMealFoodItems(mealId);
                                    }
                                  },
                                ),
                              );
                            }).toList() ?? []),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CupertinoSearchTextField(
                                      placeholder: "Search Food to Add",
                                      onChanged: (value) {
                                        _searchDebounceTimers[mealId]?.cancel();
                                        setState(() {
                                          mealSearchQueries[mealId] = value;
                                          if (value.isEmpty) {
                                            isSearchingMeal[mealId] = false;
                                            _searchFutures[mealId] = Future.value([]);
                                          } else {
                                            isSearchingMeal[mealId] = true;
                                          }
                                        });

                                        if (value.isNotEmpty) {
                                          _searchDebounceTimers[mealId] = Timer(
                                            const Duration(milliseconds: 500),
                                            () {
                                              if (mounted) {
                                                setState(() {
                                                  _searchFutures[mealId] =
                                                      searchFoodItems(value);
                                                });
                                              }
                                            },
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    child: Icon(CupertinoIcons.barcode_viewfinder,
                                        color: kPrimaryBlue),
                                    onPressed: () =>
                                        _showBarcodeInputDialog(context, mealId),
                                  ),
                                ],
                              ),
                            ),
                            if (isSearchingMeal[mealId] == true)
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: _searchFutures[mealId] ?? Future.value([]),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CupertinoActivityIndicator(),
                                    );
                                  } else if (snapshot.hasError) {
                                    return Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        'Error: ${snapshot.error}',
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    );
                                  } else if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Text('No food found.'),
                                    );
                                  } else {
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: snapshot.data!.length,
                                      itemBuilder: (context, index) {
                                        final food = snapshot.data![index];
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: CupertinoListTile(
                                            title: Text(
                                              food['name'],
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            trailing: CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              child: Text(
                                                'Add',
                                                style: TextStyle(
                                                    color: kPrimaryBlue),
                                              ),
                                              onPressed: () async {
                                                bool isAlreadyAdded =
                                                    mealFoodItems[mealId]?.any(
                                                            (item) =>
                                                                item['food_id'] ==
                                                                food['id']) ??
                                                        false;

                                                if (isAlreadyAdded) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          "This food is already in the meal. Tap on it to edit the quantity."),
                                                    ),
                                                  );
                                                  return;
                                                }

                                                if (food['id'] == 0) {
                                                  final savedFood =
                                                      await addFoodToDB(food);
                                                  if (savedFood != null) {
                                                    _addFoodToMeal(
                                                        mealId,
                                                        savedFood['id'],
                                                        1.0);
                                                  }
                                                } else {
                                                  _addFoodToMeal(
                                                      mealId, food['id'], 1.0);
                                                }
                                              },
                                            ),
                                            onTap: () async {
                                              final result =
                                                  await Navigator.pushNamed(
                                                context,
                                                '/food-details',
                                                arguments: {
                                                  'food': food,
                                                  'mealId': mealId,
                                                },
                                              );
                                              if (result == true) {
                                                _fetchMealFoodItems(mealId);
                                              }
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kPrimaryBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            final RenderBox button = context.findRenderObject() as RenderBox;
            final position = button.localToGlobal(Offset.zero);
            
            showCupertinoModalPopup(
              context: context,
              barrierDismissible: true,
              builder: (context) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Positioned(
                      top: position.dy - 220,
                      right: 16,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 220,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Add New',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      child: const Icon(CupertinoIcons.xmark),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                pressedOpacity: 0.7,
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.cart_fill, color: kPrimaryBlue),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Create Meal',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result = await Navigator.pushNamed(context, '/create-meal');
                                  if (result == true) {
                                    _fetchMeals();
                                  }
                                },
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                pressedOpacity: 0.7,
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(CupertinoIcons.plus_circle_fill, color: kPrimaryBlue),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Create Food Item',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result = await Navigator.pushNamed(
                                    context,
                                    '/food-details',
                                  );
                                  if (result == true) {
                                    _fetchFoodItems();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
          backgroundColor: kPrimaryBlue,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: getCurrentIndex(context),
        onTap: (index) => handleNavigation(index, context),
      ),
    );
  }
}
