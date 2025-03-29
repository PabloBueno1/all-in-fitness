import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';

class FoodDetailsPage extends StatefulWidget {
  const FoodDetailsPage({super.key});

  @override
  _FoodDetailsPageState createState() => _FoodDetailsPageState();
}

class _FoodDetailsPageState extends State<FoodDetailsPage> {
  late Map<String, dynamic> food;
  late int mealId;
  late TextEditingController quantityController;
  bool _isLoading = false;
  
  double totalCalories = 0;
  double totalProtein = 0;
  double totalCarbs = 0;
  double totalFats = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    food = args['food'];
    mealId = args['mealId'];
    double initialQuantity = food['quantity'] ?? 1;
    quantityController = TextEditingController(text: initialQuantity.toString());

    _updateMacros(initialQuantity);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: CupertinoColors.white),
        ),
        backgroundColor: isError ? CupertinoColors.destructiveRed : kPrimaryBlue,
      ),
    );
  }

  /// Update macro values when quantity changes
  void _updateMacros(double quantity) {
    setState(() {
      double caloriesValue = food['calories_per_item'] ?? food['calories'] ?? 0;

      totalCalories = caloriesValue * quantity;
      totalProtein = (food['protein'] ?? 0) * quantity;
      totalCarbs = (food['carbs'] ?? 0) * quantity;
      totalFats = (food['fats'] ?? 0) * quantity;
    });
  }

  /// Update food quantity in meal
  Future<void> _updateFoodQuantity() async {
    setState(() => _isLoading = true);
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';
      double? quantity = double.tryParse(quantityController.text);

      if (token.isEmpty || quantity == null || quantity <= 0) {
        _showSnackBar("Enter a valid quantity.", isError: true);
        return;
      }

      final response = await http.patch(
        Uri.parse('http://localhost:8000/meal_food_items/$mealId/${food['food_id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({"quantity": quantity}),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        _showSnackBar("Quantity updated successfully!");
      } else if (response.statusCode == 404) {
        _showSnackBar("Food is not in the meal!", isError: true);
      } else {
        _showSnackBar("Failed to update quantity.", isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Add food to meal
  Future<void> _addFoodToMeal() async {
    setState(() => _isLoading = true);
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        _showSnackBar("Authentication error: Please log in again.", isError: true);
        return;
      }

      double? quantity = double.tryParse(quantityController.text);
      if (quantity == null || quantity <= 0) {
        _showSnackBar("Enter a valid quantity.", isError: true);
        return;
      }

      // If the food is USDA (id = 0), first save it to the DB
      if (food['id'] == 0) {
        final savedFood = await _addFoodToDB(food);
        if (savedFood != null) {
          food = savedFood;
        } else {
          return;
        }
      }

      final response = await http.post(
        Uri.parse('http://localhost:8000/meal_food_items'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "meal_id": mealId,
          "food_item_id": food['id'],
          "quantity": quantity,
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        _showSnackBar("Food added successfully!");
      } else if (response.statusCode == 422) {
        _showSnackBar("This food is already added to the meal!", isError: true);
      } else {
        _showSnackBar("Failed to add food.", isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  /// Save food to database if it comes from USDA (id = 0)
  Future<Map<String, dynamic>?> _addFoodToDB(Map<String, dynamic> food) async {
    final response = await http.post(
      Uri.parse('http://localhost:8000/food_items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(food),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final savedFood = json.decode(response.body);
      return {
        ...food,
        'id': savedFood['id'],
      };
    } else {
      _showSnackBar("Error saving food to database.", isError: true);
      return null;
    }
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: kSecondaryText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(
            CupertinoIcons.back,
            color: kPrimaryBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          food['name'] ?? "Food Details",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(
                  "Serving Size",
                  (food['serving_size'] ?? 0) > 0 ? '${food['serving_size']}g' : '1 serving',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        "Calories",
                        "${totalCalories.toStringAsFixed(1)} kcal",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        "Protein",
                        "${totalProtein.toStringAsFixed(1)}g",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        "Carbs",
                        "${totalCarbs.toStringAsFixed(1)}g",
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        "Fats",
                        "${totalFats.toStringAsFixed(1)}g",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CupertinoColors.systemGrey5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Quantity",
                        style: TextStyle(
                          color: kSecondaryText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        placeholder: "Enter quantity",
                        onChanged: (value) {
                          double? quantity = double.tryParse(value);
                          if (quantity != null && quantity > 0) {
                            _updateMacros(quantity);
                          }
                        },
                        decoration: BoxDecoration(
                          border: Border.all(color: CupertinoColors.systemGrey4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CupertinoActivityIndicator())
                else ...[
                  CupertinoButton(
                    color: kPrimaryBlue,
                    onPressed: _addFoodToMeal,
                    child: const Text("Add to Meal"),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    color: CupertinoColors.systemGrey5,
                    onPressed: _updateFoodQuantity,
                    child: const Text(
                      "Update Quantity",
                      style: TextStyle(color: CupertinoColors.black),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
