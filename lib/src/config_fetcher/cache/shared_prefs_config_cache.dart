import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/cache/config_cache.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/models/plc_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Implementation of ConfigCache using SharedPreferences
class SharedPrefsConfigCache implements ConfigCache {
  /// Creates a new SharedPrefsConfigCache
  SharedPrefsConfigCache({Logger? logger}) 
      : _logger = logger ?? Logger('SharedPrefsConfigCache');
  
  final Logger _logger;
  
  static const String _configsKey = 'plc_configs';
  static const String _lastUpdateKey = 'plc_configs_last_update';
  
  @override
  Future<void> saveConfigs(List<PlcConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = configs.map((config) => config.toJson()).toList();
      final configsString = jsonEncode(configsJson);
      
      await prefs.setString(_configsKey, configsString);
      await setLastUpdateTime(DateTime.now());
      
      _logger.fine('Saved ${configs.length} configs to cache');
    } catch (e, stackTrace) {
      _logger.severe('Error saving configs to cache', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<List<PlcConfig>> getConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsString = prefs.getString(_configsKey);
      
      if (configsString == null) {
        _logger.fine('No configs found in cache');
        return [];
      }
      
      final configsJson = jsonDecode(configsString) as List<dynamic>;
      final configs = configsJson
          .map((json) => DefaultPlcConfig.fromJson(json as Map<String, dynamic>))
          .toList();
      
      _logger.fine('Retrieved ${configs.length} configs from cache');
      return configs;
    } catch (e, stackTrace) {
      _logger.severe('Error retrieving configs from cache', e, stackTrace);
      return [];
    }
  }
  
  @override
  Future<PlcConfig?> getConfig(String id) async {
    try {
      final configs = await getConfigs();
      return configs.firstWhere((config) => config.id == id);
    } catch (e) {
      _logger.fine('Config with ID $id not found in cache');
      return null;
    }
  }
  
  @override
  Future<bool> hasConfig(String id) async {
    try {
      final config = await getConfig(id);
      return config != null;
    } catch (e) {
      return false;
    }
  }
  
  @override
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configsKey);
      await prefs.remove(_lastUpdateKey);
      _logger.fine('Cache cleared');
    } catch (e, stackTrace) {
      _logger.severe('Error clearing cache', e, stackTrace);
      rethrow;
    }
  }
  
  @override
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastUpdateKey);
      
      if (timestamp == null) {
        return null;
      }
      
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e, stackTrace) {
      _logger.severe('Error getting last update time', e, stackTrace);
      return null;
    }
  }
  
  @override
  Future<void> setLastUpdateTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUpdateKey, time.millisecondsSinceEpoch);
    } catch (e, stackTrace) {
      _logger.severe('Error setting last update time', e, stackTrace);
      rethrow;
    }
  }
}
