import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateMealPage extends StatefulWidget {
  const CreateMealPage({super.key});

  @override
  _CreateMealPageState createState() => _CreateMealPageState();
}

class _CreateMealPageState extends State<CreateMealPage> {
  final TextEditingController _mealNameController = TextEditingController();
  DateTime selectedDate = DateTime.now();

  /// Create a meal in the backend and return to `MealsPage`
  Future<void> _createMeal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('http://localhost:8000/meals'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        "name": _mealNameController.text,
        "date": selectedDate.toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meal created successfully!")),
      );

      // Go back to MealsPage and refresh the list
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to create meal.")),
      );
    }
  }

  /// Select a date using a date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Meal")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _mealNameController,
              decoration: const InputDecoration(labelText: "Meal Name"),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text("Date: ${selectedDate.toLocal()}".split(' ')[0]),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createMeal,
              child: const Text("Create Meal"),
            ),
          ],
        ),
      ),
    );
  }
}
