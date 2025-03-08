import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateFoodPage extends StatefulWidget {
  const CreateFoodPage({super.key});

  @override
  _CreateFoodPageState createState() => _CreateFoodPageState();
}

class _CreateFoodPageState extends State<CreateFoodPage> {
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatsController = TextEditingController();
  String? _errorMessage;

  /// Function to add a new food item
  Future<void> _addFoodItem() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    // Validate Inputs: Ensure proper numeric conversion
    double? servingSize = double.tryParse(_servingSizeController.text);
    int? calories = int.tryParse(_caloriesController.text);
    double? protein = double.tryParse(_proteinController.text);
    double? carbs = double.tryParse(_carbsController.text);
    double? fats = double.tryParse(_fatsController.text);

    // Ensure values are not null, else assign default 0
    servingSize ??= 0.0;
    calories ??= 0;
    protein ??= 0.0;
    carbs ??= 0.0;
    fats ??= 0.0;

    // Ensure the name is not empty
    if (_foodNameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Food name cannot be empty.";
      });
      return;
    }

    final response = await http.post(
      Uri.parse('http://localhost:8000/food_items'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "name": _foodNameController.text.trim(),
        "serving_size": servingSize,
        "calories": calories,
        "protein": protein,
        "carbs": carbs,
        "fats": fats,
        "is_custom": true,  // ✅ Ensure this field is always included
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true); // Close page and refresh food list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food item added successfully!")),
      );
    } else {
      setState(() {
        _errorMessage = "Error: Unable to add food. Please check inputs.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manually Add Food")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _foodNameController,
              decoration: const InputDecoration(labelText: "Food Name"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _servingSizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Serving Size (grams)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Calories"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Protein (g)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _carbsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Carbs (g)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fatsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Fats (g)"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addFoodItem,
              child: const Text("Add Food"),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
