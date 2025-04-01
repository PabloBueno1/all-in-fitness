import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../mixins/navigation_mixin.dart';
import '../widgets/goal_recommendations_card.dart';

// iOS-style constants
const kBackgroundColor = Color(0xFFF2F2F7);
const kCardBackground = Colors.white;
const kPrimaryBlue = Color(0xFF007AFF);
const kSecondaryText = Color(0xFF8E8E93);
const kBorderRadius = 16.0;
const kSpacing = 16.0;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with NavigationMixin {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  String? editingField;
  bool isNewUser = false;

  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _heightController = TextEditingController();
  String? _selectedGender;
  String? _selectedFitnessLevel;
  String? _selectedDietaryPreference;

  final List<String> _genders = ['male', 'female', 'other'];
  final List<String> _fitnessLevels = ['beginner', 'intermediate', 'advanced'];
  final List<String> _dietaryPreferences = ['none', 'vegetarian', 'vegan', 'keto', 'paleo'];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _targetWeightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://localhost:8000/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          profile = data;
          _weightController.text = data['weight']?.toString() ?? '';
          _targetWeightController.text = data['target_weight']?.toString() ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _selectedGender = data['gender'];
          _selectedFitnessLevel = data['fitness_level'];
          _selectedDietaryPreference = data['dietary_preferences'];
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          isNewUser = true;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.put(
        Uri.parse('http://localhost:8000/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'weight': double.tryParse(_weightController.text),
          'height': double.tryParse(_heightController.text),
          'gender': _selectedGender,
          'fitness_level': _selectedFitnessLevel,
          'dietary_preferences': _selectedDietaryPreference,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          editingField = null;
          isNewUser = false;
        });
        _fetchProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile created successfully')),
          );
          // After profile is created, navigate to goals page
          Navigator.pushReplacementNamed(context, '/goals');
        }
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create profile')),
        );
      }
    }
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse('http://localhost:8000/users/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'weight': double.tryParse(_weightController.text),
          'height': double.tryParse(_heightController.text),
          'gender': _selectedGender,
          'fitness_level': _selectedFitnessLevel,
          'dietary_preferences': _selectedDietaryPreference,
          'target_weight': double.tryParse(_targetWeightController.text),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile created successfully')),
          );
          // Add a small delay to ensure the snackbar is visible
          await Future.delayed(const Duration(milliseconds: 500));
          // After profile is created, navigate to goals page
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/goals');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create profile')),
          );
        }
      }
    } catch (e) {
      print('Error creating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create profile')),
        );
      }
    }
  }

  void _showGenderPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Gender'),
        actions: _genders.map((gender) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedGender = gender);
              Navigator.pop(context);
            },
            child: Text(gender),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showFitnessLevelPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Fitness Level'),
        actions: _fitnessLevels.map((level) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedFitnessLevel = level);
              Navigator.pop(context);
            },
            child: Text(level),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showDietaryPreferencesPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Dietary Preferences'),
        actions: _dietaryPreferences.map((pref) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedDietaryPreference = pref);
              Navigator.pop(context);
            },
            child: Text(pref),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(kSpacing),
      padding: const EdgeInsets.all(kSpacing * 2),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.person_crop_circle_badge_plus,
            size: 64,
            color: kPrimaryBlue,
          ),
          const SizedBox(height: kSpacing * 2),
          const Text(
            'Welcome to Fitness App!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: kSpacing),
          const Text(
            'Let\'s create your profile to get started with your fitness journey.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: kSecondaryText,
            ),
          ),
          const SizedBox(height: kSpacing * 2),
          CupertinoButton.filled(
            onPressed: () {
              setState(() => isNewUser = false);
            },
            child: const Text('Create Profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: kSpacing,
        vertical: kSpacing / 2,
      ),
      decoration: BoxDecoration(
        color: kCardBackground,
        borderRadius: BorderRadius.circular(kBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: child,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    TextInputType? keyboardType,
  }) {
    final isEditing = editingField == label;
    return Padding(
      padding: const EdgeInsets.all(kSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(
                  isEditing ? CupertinoIcons.checkmark : CupertinoIcons.pencil,
                  color: kPrimaryBlue,
                ),
                onPressed: () {
                  if (isEditing) {
                    _updateProfile();
                  } else {
                    setState(() => editingField = label);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: controller,
            keyboardType: keyboardType,
            suffix: suffix != null 
              ? Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(suffix),
                )
              : null,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            enabled: isEditing,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    final isEditing = editingField == label;
    return Padding(
      padding: const EdgeInsets.all(kSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(
                  isEditing ? CupertinoIcons.checkmark : CupertinoIcons.pencil,
                  color: kPrimaryBlue,
                ),
                onPressed: () {
                  if (isEditing) {
                    _updateProfile();
                  } else {
                    setState(() => editingField = label);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isEditing
                ? () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        title: Text(label),
                        actions: items.map((item) {
                          return CupertinoActionSheetAction(
                            onPressed: () {
                              onChanged(item);
                              Navigator.pop(context);
                              _updateProfile();
                            },
                            child: Text(item),
                          );
                        }).toList(),
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context),
                          isDestructiveAction: true,
                          child: const Text('Cancel'),
                        ),
                      ),
                    );
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value ?? 'Select $label',
                    style: TextStyle(
                      color: value == null ? kSecondaryText : Colors.black,
                    ),
                  ),
                  if (isEditing)
                    const Icon(
                      CupertinoIcons.chevron_down,
                      color: kPrimaryBlue,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateProfileForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoTextField(
            controller: _weightController,
            placeholder: 'Current Weight (lbs)',
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey5),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _targetWeightController,
            placeholder: 'Target Weight (lbs)',
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey5),
            ),
          ),
          const SizedBox(height: 16),
          CupertinoTextField(
            controller: _heightController,
            placeholder: 'Height (inches)',
            keyboardType: TextInputType.number,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CupertinoColors.systemGrey5),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showGenderPicker(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedGender ?? 'Select Gender',
                    style: TextStyle(
                      color: _selectedGender == null ? CupertinoColors.systemGrey : CupertinoColors.black,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: CupertinoColors.systemGrey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showFitnessLevelPicker(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedFitnessLevel ?? 'Select Fitness Level',
                    style: TextStyle(
                      color: _selectedFitnessLevel == null ? CupertinoColors.systemGrey : CupertinoColors.black,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: CupertinoColors.systemGrey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _showDietaryPreferencesPicker(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CupertinoColors.systemGrey5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDietaryPreference ?? 'Select Dietary Preferences',
                    style: TextStyle(
                      color: _selectedDietaryPreference == null ? CupertinoColors.systemGrey : CupertinoColors.black,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_down,
                    color: CupertinoColors.systemGrey,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          CupertinoButton(
            color: kPrimaryBlue,
            onPressed: _createProfile,
            child: const Text('Create Profile'),
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
        backgroundColor: kBackgroundColor,
        elevation: 0,
        title: Text(
          isNewUser ? 'Create Profile' : 'Profile',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : isNewUser
              ? _buildCreateProfileForm()
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField(
                            controller: _weightController,
                            label: 'Weight',
                            suffix: 'lbs',
                            keyboardType: TextInputType.number,
                          ),
                          _buildTextField(
                            controller: _heightController,
                            label: 'Height',
                            suffix: 'inches',
                            keyboardType: TextInputType.number,
                          ),
                          _buildDropdown(
                            label: 'Gender',
                            value: _selectedGender,
                            items: _genders,
                            onChanged: (value) => setState(() => _selectedGender = value),
                          ),
                          _buildDropdown(
                            label: 'Fitness Level',
                            value: _selectedFitnessLevel,
                            items: _fitnessLevels,
                            onChanged: (value) => setState(() => _selectedFitnessLevel = value),
                          ),
                          _buildDropdown(
                            label: 'Dietary Preferences',
                            value: _selectedDietaryPreference,
                            items: _dietaryPreferences,
                            onChanged: (value) => setState(() => _selectedDietaryPreference = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: getCurrentIndex(context),
        onTap: (index) => handleNavigation(index, context),
      ),
    );
  }
} 