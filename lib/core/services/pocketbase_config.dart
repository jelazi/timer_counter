import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../data/repositories/settings_repository.dart';

enum PocketBaseConfigSource { bundledAsset, settingsOverride }

class PocketBaseConnectionResult {
  final bool isSuccess;
  final String message;
  final String? userId;
  final String? userEmail;

  const PocketBaseConnectionResult.success({required this.message, this.userId, this.userEmail}) : isSuccess = true;

  const PocketBaseConnectionResult.failure(this.message) : isSuccess = false, userId = null, userEmail = null;
}

/// Loads PocketBase configuration from bundled asset.
/// Returns null if the config file doesn't exist or contains placeholder values.
class PocketBaseConfig {
  final String url;
  final String email;
  final String password;
  final PocketBaseConfigSource source;

  const PocketBaseConfig({required this.url, required this.email, required this.password, required this.source});

  static bool _isValidValue(String value, {required bool allowExamplePlaceholder}) {
    if (value.trim().isEmpty) return false;
    if (!allowExamplePlaceholder && value.contains('example.com')) return false;
    return true;
  }

  static bool isValid({required String url, required String email, required String password}) {
    if (!_isValidValue(url, allowExamplePlaceholder: false)) return false;
    if (!_isValidValue(email, allowExamplePlaceholder: false)) return false;
    if (password.trim().isEmpty || password == 'your-password-here') return false;
    return true;
  }

  static PocketBaseConfig? fromSettings(SettingsRepository settingsRepository) {
    final url = settingsRepository.getPocketBaseUrl().trim();
    final email = settingsRepository.getPocketBaseEmail().trim();
    final password = settingsRepository.getPocketBasePassword().trim();

    if (!isValid(url: url, email: email, password: password)) return null;

    return PocketBaseConfig(url: url, email: email, password: password, source: PocketBaseConfigSource.settingsOverride);
  }

  /// Tries to load config from `lib/config/pocketbase_config.json` asset.
  /// Returns `null` if the file is missing, unreadable, or has placeholder data.
  static Future<PocketBaseConfig?> loadBundled() async {
    try {
      final raw = await rootBundle.loadString('lib/config/pocketbase_config.json');
      final map = json.decode(raw) as Map<String, dynamic>;

      final url = (map['url'] as String?)?.trim() ?? '';
      final email = (map['email'] as String?)?.trim() ?? '';
      final password = (map['password'] as String?)?.trim() ?? '';

      // Reject placeholder / empty values
      if (!isValid(url: url, email: email, password: password)) return null;

      return PocketBaseConfig(url: url, email: email, password: password, source: PocketBaseConfigSource.bundledAsset);
    } catch (e) {
      debugPrint('[PocketBaseConfig] Config not found or invalid – sync disabled. ($e)');
      return null;
    }
  }

  static Future<PocketBaseConfig?> loadEffective(SettingsRepository settingsRepository) async {
    final override = fromSettings(settingsRepository);
    if (override != null) return override;
    return loadBundled();
  }

  static Future<PocketBaseConnectionResult> testConnection({required String url, required String email, required String password}) async {
    if (!isValid(url: url, email: email, password: password)) {
      return const PocketBaseConnectionResult.failure('Missing or invalid PocketBase URL, email, or password.');
    }

    try {
      final pocketBase = PocketBase(url);
      final auth = await pocketBase.collection('users').authWithPassword(email, password);
      final resolvedEmail = auth.record.getStringValue('email');
      return PocketBaseConnectionResult.success(
        message: resolvedEmail.isNotEmpty ? 'Authenticated as $resolvedEmail' : 'Authenticated successfully',
        userId: auth.record.id,
        userEmail: resolvedEmail.isNotEmpty ? resolvedEmail : null,
      );
    } on ClientException catch (e) {
      final message = e.response['message']?.toString() ?? e.toString();
      return PocketBaseConnectionResult.failure(message);
    } catch (e) {
      return PocketBaseConnectionResult.failure(e.toString());
    }
  }
}
