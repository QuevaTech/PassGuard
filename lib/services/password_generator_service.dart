import 'dart:math';
import 'package:flutter/material.dart';

class PasswordGeneratorService {
  static const String _lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numberChars = '0123456789';
  static const String _symbolChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  static const String _similarChars = 'il1Lo0O';
  static const String _ambiguousChars = '{}[]()/\\\'"`~,;.<>';

  // Generate password with specified options
  static String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
    bool excludeSimilar = false,
    bool excludeAmbiguous = false,
  }) {
    if (length < 4) {
      throw Exception('Password length must be at least 4 characters');
    }

    final random = Random.secure();

    String charset = '';
    List<String> requiredChars = [];

    if (includeLowercase) {
      String chars = _lowercaseChars;
      if (excludeSimilar) {
        chars = chars.replaceAll(RegExp('[$_similarChars]'), '');
      }
      if (excludeAmbiguous) {
        chars = chars.replaceAll(RegExp('[$_ambiguousChars]'), '');
      }
      charset += chars;
      if (chars.isNotEmpty) {
        requiredChars.add(_getRandomChar(chars, random));
      }
    }

    if (includeUppercase) {
      String chars = _uppercaseChars;
      if (excludeSimilar) {
        chars = chars.replaceAll(RegExp('[$_similarChars]'), '');
      }
      if (excludeAmbiguous) {
        chars = chars.replaceAll(RegExp('[$_ambiguousChars]'), '');
      }
      charset += chars;
      if (chars.isNotEmpty) {
        requiredChars.add(_getRandomChar(chars, random));
      }
    }

    if (includeNumbers) {
      String chars = _numberChars;
      if (excludeSimilar) {
        chars = chars.replaceAll(RegExp('[$_similarChars]'), '');
      }
      if (excludeAmbiguous) {
        chars = chars.replaceAll(RegExp('[$_ambiguousChars]'), '');
      }
      charset += chars;
      if (chars.isNotEmpty) {
        requiredChars.add(_getRandomChar(chars, random));
      }
    }

    if (includeSymbols) {
      String chars = _symbolChars;
      if (excludeSimilar) {
        chars = chars.replaceAll(RegExp('[$_similarChars]'), '');
      }
      if (excludeAmbiguous) {
        chars = chars.replaceAll(RegExp('[$_ambiguousChars]'), '');
      }
      charset += chars;
      if (chars.isNotEmpty) {
        requiredChars.add(_getRandomChar(chars, random));
      }
    }

    if (charset.isEmpty) {
      throw Exception('At least one character type must be selected');
    }
    final passwordChars = <String>[];

    // Add required characters first
    for (final char in requiredChars) {
      passwordChars.add(char);
    }

    // Fill remaining length with random characters
    while (passwordChars.length < length) {
      passwordChars.add(_getRandomChar(charset, random));
    }

    // Shuffle the password characters
    passwordChars.shuffle(random);

    return passwordChars.join();
  }

  // Get random character from string using the provided Random instance.
  static String _getRandomChar(String chars, Random random) {
    final index = random.nextInt(chars.length);
    return chars[index];
  }

  // Calculate password strength score (0-100)
  static int calculateStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;
    bool hasLower = false;
    bool hasUpper = false;
    bool hasNumber = false;
    bool hasSymbol = false;

    for (final char in password.runes) {
      final c = String.fromCharCode(char);
      if (_lowercaseChars.contains(c)) hasLower = true;
      if (_uppercaseChars.contains(c)) hasUpper = true;
      if (_numberChars.contains(c)) hasNumber = true;
      if (_symbolChars.contains(c)) hasSymbol = true;
    }

    // Length scoring
    if (password.length >= 8) score += 25;
    if (password.length >= 12) score += 15;
    if (password.length >= 16) score += 10;

    // Character diversity scoring
    if (hasLower) score += 10;
    if (hasUpper) score += 10;
    if (hasNumber) score += 10;
    if (hasSymbol) score += 15;

    // Bonus for mixed case
    if (hasLower && hasUpper) score += 5;

    // Bonus for numbers and symbols
    if (hasNumber && hasSymbol) score += 5;

    return score.clamp(0, 100);
  }

  // Get password strength level
  static String getStrengthLevel(int score) {
    if (score < 50) return 'weak';
    if (score < 75) return 'medium';
    return 'strong';
  }

  // Get password strength color
  static Color getStrengthColor(int score) {
    if (score < 50) return Colors.red;
    if (score < 75) return Colors.orange;
    return Colors.green;
  }

  // Check if password is weak
  static bool isWeakPassword(String password) {
    return calculateStrength(password) < 50;
  }

  // Generate multiple password options
  static List<String> generateMultiplePasswords({
    int count = 5,
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
    bool excludeSimilar = false,
    bool excludeAmbiguous = false,
  }) {
    final passwords = <String>[];
    for (int i = 0; i < count; i++) {
      passwords.add(generatePassword(
        length: length,
        includeUppercase: includeUppercase,
        includeLowercase: includeLowercase,
        includeNumbers: includeNumbers,
        includeSymbols: includeSymbols,
        excludeSimilar: excludeSimilar,
        excludeAmbiguous: excludeAmbiguous,
      ));
    }
    return passwords;
  }

  // Validate password meets basic security requirements
  static bool isValidPassword(String password) {
    if (password.length < 8) return false;
    
    bool hasLower = false;
    bool hasUpper = false;
    bool hasNumber = false;
    bool hasSymbol = false;

    for (final char in password.runes) {
      final c = String.fromCharCode(char);
      if (_lowercaseChars.contains(c)) hasLower = true;
      if (_uppercaseChars.contains(c)) hasUpper = true;
      if (_numberChars.contains(c)) hasNumber = true;
      if (_symbolChars.contains(c)) hasSymbol = true;
    }

    // Must have at least 3 of 4 character types
    int charTypes = 0;
    if (hasLower) charTypes++;
    if (hasUpper) charTypes++;
    if (hasNumber) charTypes++;
    if (hasSymbol) charTypes++;

    return charTypes >= 3;
  }
}