import '../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/app_translations.dart';
import '../../core/utils/calorie_calculator.dart';
import '../../data/local/preference_manager.dart';
import '../../data/models/user_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  double? weight;
  double? height;
  int? age;
  String? activityLevel;
  String? gender;
  int estimatedCalories = 0;
  String? userGoal;

  late final Map<String, String> activityLevelDescriptions;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = AppTranslations.of(context);
    activityLevelDescriptions = {
      'Sedentary': t.translate('sedentary'),
      'Light': t.translate('light'),
      'Moderate': t.translate('moderate'),
      'Active': t.translate('active'),
      'Very Active': t.translate('very_active'),
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  /// Devuelve true si los datos son válidos y se guardaron.
  /// Antes usaba `weight!`/`height!`/etc. sin validar y crasheaba
  /// ("Null check operator used on a null value") al avanzar con campos vacíos.
  Future<bool> _savePreferences() async {
    final w = weight;
    final h = height;
    final a = age;
    final al = activityLevel;
    final g = gender;
    final goal = userGoal;

    if (w == null || h == null || a == null || al == null || g == null || goal == null) {
      _showValidationError('Completa todos los campos antes de continuar');
      return false;
    }
    if (w < 25 || w > 400) {
      _showValidationError('Introduce un peso válido (25–400 kg)');
      return false;
    }
    if (h < 80 || h > 260) {
      _showValidationError('Introduce una altura válida (80–260 cm)');
      return false;
    }
    if (a < 5 || a > 120) {
      _showValidationError('Introduce una edad válida (5–120 años)');
      return false;
    }

    final maintenanceCalories = CalorieCalculator.fallbackEstimateCalories(
      weight: w,
      height: h,
      age: a,
      activityLevel: al,
      gender: g,
    );

    final adjustedCalories = CalorieCalculator.calculateCaloriesBasedOnGoal(
      maintenanceCalories: maintenanceCalories,
      goal: goal,
    );

    final macroGoals = CalorieCalculator.calculateMacroGoals(
      calories: adjustedCalories,
      goal: goal,
    );

    setState(() {
      estimatedCalories = adjustedCalories;
    });

    final userData = UserData(
      weight: w,
      height: h,
      age: a,
      activityLevel: al,
      gender: g,
      goal: goal,
      estimatedCalories: adjustedCalories,
      proteinGoal: macroGoals['proteinGoal']!,
      fatGoal: macroGoals['fatGoal']!,
      carbsGoal: macroGoals['carbsGoal']!,
    );

    final prefManager =
        PreferenceManager(await SharedPreferences.getInstance());
    await prefManager.saveUserData(userData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    return true;
  }

  void _nextPage() {
    if (_currentPage < 6) {
      if (_currentPage == 5) {
        // Guarda y solo avanza si los datos son válidos.
        _savePreferences().then((ok) {
          if (!ok || !mounted) return;
          _pageController.nextPage(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
        return;
      }
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _skipToMain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    final prefManager = PreferenceManager(prefs);
    final userData = UserData(
      weight: 70,
      height: 170,
      age: 25,
      activityLevel: 'Moderate',
      gender: 'Other',
      goal: 'Maintenance',
      estimatedCalories: 2000,
      proteinGoal: 50,
      fatGoal: 65,
      carbsGoal: 250,
    );
    await prefManager.saveUserData(userData);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Widget _buildPage(String titleKey, String assetPath, Widget inputField) {
    final t = AppTranslations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 7,
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  t.translate(titleKey),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                inputField,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLevelDropdown() {
    return Column(
      children: [
        DropdownButton<String>(
          value: activityLevel,
          isExpanded: true,
          dropdownColor: AppColors.elevatedCardBackground,
          style: const TextStyle(color: AppColors.textPrimary),
          iconEnabledColor: AppColors.textPrimary,
          items: activityLevelDescriptions.entries
              .map((entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text(
                          entry.value,
                          style:
                              const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (value) => setState(() => activityLevel = value),
          hint: Text(AppTranslations.of(context).translate('activity_level'),
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      appBar: _currentPage == 0
          ? AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                TextButton(
                  onPressed: _skipToMain,
                  child: Text(
                    t.translate('skip'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            )
          : null,
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _currentPage = index),
        children: [
          _buildPage(
            'enter_weight',
            'assets/onboarding/onboarding_weight.png',
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (value) => weight = double.tryParse(value),
              decoration: InputDecoration(
                labelText: t.translate('weight_in_kg'),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          _buildPage(
            'enter_height',
            'assets/onboarding/onboarding_height.png',
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (value) => height = double.tryParse(value),
              decoration: InputDecoration(
                labelText: t.translate('height_in_cm'),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          _buildPage(
            'enter_age',
            'assets/onboarding/onboarding_age.png',
            TextField(
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (value) => age = int.tryParse(value),
              decoration: InputDecoration(
                labelText: t.translate('age_in_years'),
                labelStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          _buildPage(
            'select_activity_level',
            'assets/onboarding/onboarding_activity_level.png',
            _buildActivityLevelDropdown(),
          ),
          _buildPage(
            'select_gender',
            'assets/onboarding/onboarding_gender.png',
            DropdownButton<String>(
              value: gender,
              isExpanded: true,
              dropdownColor: AppColors.elevatedCardBackground,
              style: const TextStyle(color: AppColors.textPrimary),
              iconEnabledColor: AppColors.textPrimary,
              items: ['Male', 'Female', 'Other']
                  .map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(t.translate(g.toLowerCase()),
                          style: const TextStyle(color: AppColors.textPrimary))))
                  .toList(),
              onChanged: (value) => setState(() => gender = value),
              hint: Text(t.translate('select_gender_hint'),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          _buildPage(
            'select_goal',
            'assets/onboarding/onboarding_goal.png',
            DropdownButton<String>(
              value: userGoal,
              isExpanded: true,
              dropdownColor: AppColors.elevatedCardBackground,
              style: const TextStyle(color: AppColors.textPrimary),
              iconEnabledColor: AppColors.textPrimary,
              items: ['Weight Loss', 'Maintenance', 'Muscle Gain']
                  .map((goal) => DropdownMenuItem(
                      value: goal,
                      child: Text(
                          t.translate(goal.toLowerCase().replaceAll(' ', '_')),
                          style: const TextStyle(color: AppColors.textPrimary))))
                  .toList(),
              onChanged: (value) => setState(() => userGoal = value),
              hint: Text(t.translate('select_goal'),
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          _buildWelcomePage(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
          ),
          child: _currentPage == 6
              ? Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.background.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.background,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      t.translate('finish'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      height: 48,
                      width: 120,
                      child: TextButton(
                        onPressed: _currentPage > 0
                            ? () => _pageController.previousPage(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                )
                            : null,
                        child: Text(
                          _currentPage > 0 ? t.translate('back') : '',
                          style: const TextStyle(
                              fontSize: 16, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      width: 120,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.background,
                        ),
                        child: Text(
                          t.translate('next'),
                          style: const TextStyle(
                              fontSize: 16, color: AppColors.background),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    final t = AppTranslations.of(context);
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Image.asset(
            'assets/onboarding/onboarding_welcome.png',
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  t.translate('welcome'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.translate('your_daily_target'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$estimatedCalories ${t.translate('kcal')}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
