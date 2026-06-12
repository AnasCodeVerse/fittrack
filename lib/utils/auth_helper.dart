import 'package:shared_preferences/shared_preferences.dart';

class AuthHelper {
  static const String _userKey = 'app_username';
  static const String _passKey = 'app_password';
  static const String _loggedInKey = 'is_logged_in';

  // Default credentials - changeable in settings
  static const String defaultUsername = 'anasx1';
  static const String defaultPassword = 'fit2025';

  static Future<void> initDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_userKey)) {
      await prefs.setString(_userKey, defaultUsername);
      await prefs.setString(_passKey, defaultPassword);
    }
  }

  static Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedUser = prefs.getString(_userKey) ?? defaultUsername;
    final storedPass = prefs.getString(_passKey) ?? defaultPassword;
    if (username == storedUser && password == storedPass) {
      await prefs.setBool(_loggedInKey, true);
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<String> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey) ?? defaultUsername;
  }

  static Future<bool> changeCredentials(String currentPass, String newUsername, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPass = prefs.getString(_passKey) ?? defaultPassword;
    if (currentPass != storedPass) return false;
    await prefs.setString(_userKey, newUsername);
    await prefs.setString(_passKey, newPassword);
    return true;
  }
}
