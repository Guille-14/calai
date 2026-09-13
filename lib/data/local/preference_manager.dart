import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_data.dart';

class PreferenceManager {
  static const String _userDataKey = 'userData';

  final SharedPreferences prefs;

  PreferenceManager(this.prefs);

  Future<void> saveUserData(UserData userData) async {
    final userDataJson = jsonEncode(userData.toJson());
    await prefs.setString(_userDataKey, userDataJson);
  }

  UserData? getUserData() {
    final userDataJson = prefs.getString(_userDataKey);
    if (userDataJson != null) {
      final Map<String, dynamic> userDataMap = jsonDecode(userDataJson);
      return UserData.fromJson(userDataMap);
    }
    return null;
  }

  Future<void> clearUserData() async {
    await prefs.remove(_userDataKey);
  }

  double getCalorieGoal() {
    final userData = getUserData();
    return userData?.estimatedCalories.toDouble() ?? 2000.0;
  }

  int getProteinGoal() {
    final userData = getUserData();
    return userData?.proteinGoal ?? 150;
  }

  int getCarbsGoal() {
    final userData = getUserData();
    return userData?.carbsGoal ?? 250;
  }

  int getFatGoal() {
    final userData = getUserData();
    return userData?.fatGoal ?? 65;
  }
}
