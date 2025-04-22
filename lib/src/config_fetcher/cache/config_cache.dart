import 'package:mcomp_plc_utils/src/config_fetcher/models/plc_config.dart';

/// Interface for caching PLC configurations
abstract class ConfigCache {
  /// Saves a list of PLC configurations to the cache
  Future<void> saveConfigs(List<PlcConfig> configs);
  
  /// Retrieves all cached PLC configurations
  Future<List<PlcConfig>> getConfigs();
  
  /// Retrieves a specific PLC configuration by ID
  Future<PlcConfig?> getConfig(String id);
  
  /// Checks if the cache contains a configuration for the given ID
  Future<bool> hasConfig(String id);
  
  /// Clears all cached configurations
  Future<void> clearCache();
  
  /// Gets the timestamp of the last cache update
  Future<DateTime?> getLastUpdateTime();
  
  /// Sets the timestamp of the last cache update
  Future<void> setLastUpdateTime(DateTime time);
}
