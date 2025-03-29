import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';

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
        "is_custom": true,
      }),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true);
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    String? suffix,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CupertinoTextField(
        controller: controller,
        placeholder: placeholder,
        suffix: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  suffix,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            : null,
        keyboardType: keyboardType ?? TextInputType.text,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          border: Border.all(color: CupertinoColors.systemGrey4),
          borderRadius: BorderRadius.circular(8),
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
          'Add Food',
          style: TextStyle(
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
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: CupertinoColors.destructiveRed),
                      textAlign: TextAlign.center,
                    ),
                  ),
                _buildTextField(
                  controller: _foodNameController,
                  placeholder: 'Food Name',
                ),
                _buildTextField(
                  controller: _servingSizeController,
                  placeholder: 'Serving Size',
                  suffix: 'grams',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: _caloriesController,
                  placeholder: 'Calories',
                  suffix: 'kcal',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: _proteinController,
                  placeholder: 'Protein',
                  suffix: 'g',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: _carbsController,
                  placeholder: 'Carbs',
                  suffix: 'g',
                  keyboardType: TextInputType.number,
                ),
                _buildTextField(
                  controller: _fatsController,
                  placeholder: 'Fats',
                  suffix: 'g',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                CupertinoButton(
                  color: kPrimaryBlue,
                  onPressed: _addFoodItem,
                  child: const Text('Add Food'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
