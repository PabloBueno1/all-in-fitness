import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FoodDetailsPage extends StatefulWidget {
  const FoodDetailsPage({super.key});

  @override
  _FoodDetailsPageState createState() => _FoodDetailsPageState();
}

class _FoodDetailsPageState extends State<FoodDetailsPage> {
  late Map<String, dynamic> food;
  late int mealId;
  late TextEditingController quantityController;
  
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

  /// ✅ Update macro values when quantity changes
  void _updateMacros(double quantity) {
    setState(() {
      double caloriesValue = food['calories_per_item'] ?? food['calories'] ?? 0;

      totalCalories = caloriesValue * quantity;
      totalProtein = (food['protein'] ?? 0) * quantity;
      totalCarbs = (food['carbs'] ?? 0) * quantity;
      totalFats = (food['fats'] ?? 0) * quantity;
    });
  }

  /// ✅ Update food quantity in meal
  Future<void> _updateFoodQuantity() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    double? quantity = double.tryParse(quantityController.text);

    if (token.isEmpty || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid quantity.")),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quantity updated successfully!")),
      );
    } else if (response.statusCode == 404) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food is not in the meal!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update quantity.")),
      );
    }
  }

  /// When the user adds food from db we use foo[id] if it already exists we use food[food_id]
  Future<void> _addFoodToMeal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication error: Please log in again.")),
      );
      return;
    }

    double? quantity = double.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid quantity.")),
      );
      return;
    }
    // ✅ If the food is USDA (id = 0), first save it to the DB
    if (food['id'] == 0) {
      final savedFood = await _addFoodToDB(food);
      if (savedFood != null) {
        food = savedFood; // ✅ Update food object with new database ID
      } else {
        return; // Stop if saving food failed
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
      Navigator.pop(context, true); // ✅ Return `true` so MealsPage refreshes
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food added successfully!")),
      );
    } else if (response.statusCode == 422) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This food is already added to the meal!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add food.")),
      );
    }
  }
  
  /// ✅ Save food to database if it comes from USDA (id = 0)
  Future<Map<String, dynamic>?> _addFoodToDB(Map<String, dynamic> food) async {
    final response = await http.post(
      Uri.parse('http://localhost:8000/food_items'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(food),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final savedFood = json.decode(response.body);
      return {
        ...food, // ✅ Keep original food data
        'id': savedFood['id'], // ✅ Update with new database ID
      };
    } else {
      print('❌ Failed to add food item to DB. Status: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving food to database.")),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(food['name'] ?? "Food Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Serving Size: ${(food['serving_size'] ?? 0) > 0 ? '${food['serving_size']}g' : '1 serving'}"),
            const SizedBox(height: 10),
            Text("Calories: ${totalCalories.toStringAsFixed(2)} kcal"),
            Text("Protein: ${totalProtein.toStringAsFixed(2)}g"),
            Text("Carbs: ${totalCarbs.toStringAsFixed(2)}g"),
            Text("Fats: ${totalFats.toStringAsFixed(2)}g"),
            const SizedBox(height: 20),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Quantity"),
              onChanged: (value) {
                double? quantity = double.tryParse(value);
                if (quantity != null && quantity > 0) {
                  _updateMacros(quantity);
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addFoodToMeal,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text("Add to Meal"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity, 
              child: ElevatedButton.icon(
                onPressed: _updateFoodQuantity,
                icon: const Icon(Icons.update),
                label: const Text("Update Quantity"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
