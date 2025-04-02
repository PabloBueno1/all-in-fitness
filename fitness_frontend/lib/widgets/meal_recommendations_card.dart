import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';

class MealRecommendationsCard extends StatefulWidget {
  const MealRecommendationsCard({Key? key}) : super(key: key);

  @override
  _MealRecommendationsCardState createState() => _MealRecommendationsCardState();
}

class _MealRecommendationsCardState extends State<MealRecommendationsCard> {
  bool _isExpanded = false;
  bool _isLoading = false;
  Map<String, dynamic>? _recommendations;

  Future<void> _fetchRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:8000/meals/recommendations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _recommendations = json.decode(response.body);
          _isExpanded = true;  // Auto-expand when we get new recommendations
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to fetch recommendations')),
          );
        }
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching recommendations')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMacroRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            label == 'Calories' ? '${value.toStringAsFixed(1)} kcal' : '${value.toStringAsFixed(1)}g',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Get personalized meal recommendations based on your remaining daily goals.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            color: kPrimaryBlue,
            borderRadius: BorderRadius.circular(8),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.sparkles, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Generate AI Recommendations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            onPressed: _fetchRecommendations,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          // Header
          CupertinoListTile(
            title: Row(
              children: [
                const Text(
                  'Meal Recommendations',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CupertinoActivityIndicator(),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_recommendations != null && !_isLoading)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      CupertinoIcons.refresh,
                      color: kPrimaryBlue,
                    ),
                    onPressed: _fetchRecommendations,
                  ),
                if (_recommendations != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _isExpanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      color: kPrimaryBlue,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
              ],
            ),
          ),

          // Content
          if (_recommendations == null && !_isLoading)
            _buildGenerateButton()
          else if (_isExpanded && _recommendations != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Remaining Macros Section
                  const Text(
                    'Remaining Macros',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMacroRow(
                    'Calories',
                    _recommendations!['remaining_macros']['calories'],
                  ),
                  _buildMacroRow(
                    'Protein',
                    _recommendations!['remaining_macros']['protein'],
                  ),
                  _buildMacroRow(
                    'Carbs',
                    _recommendations!['remaining_macros']['carbs'],
                  ),
                  _buildMacroRow(
                    'Fats',
                    _recommendations!['remaining_macros']['fats'],
                  ),
                  const SizedBox(height: 16),

                  // Recommended Meal Section
                  if (_recommendations!['recommendations']['success'] &&
                      _recommendations!['recommendations']['data'] != null) ...[
                    const Text(
                      'Recommended Meal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recommendations!['recommendations']['data']
                                ['meal_name'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Ingredients:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          ...(_recommendations!['recommendations']['data']
                                  ['ingredients'] as List)
                              .map((ingredient) => Text(
                                    '• $ingredient',
                                    style: const TextStyle(fontSize: 14),
                                  )),
                          const SizedBox(height: 8),
                          const Text(
                            'Instructions:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          ...(_recommendations!['recommendations']['data']
                                  ['instructions'] as List)
                              .map((step) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• $step',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  )),
                          const SizedBox(height: 8),
                          const Text(
                            'Nutrition Facts:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          _buildMacroRow(
                            'Calories',
                            _recommendations!['recommendations']['data']
                                ['macros']['calories'].toDouble(),
                          ),
                          _buildMacroRow(
                            'Protein',
                            _recommendations!['recommendations']['data']
                                ['macros']['protein'].toDouble(),
                          ),
                          _buildMacroRow(
                            'Carbs',
                            _recommendations!['recommendations']['data']
                                ['macros']['carbs'].toDouble(),
                          ),
                          _buildMacroRow(
                            'Fats',
                            _recommendations!['recommendations']['data']
                                ['macros']['fats'].toDouble(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 