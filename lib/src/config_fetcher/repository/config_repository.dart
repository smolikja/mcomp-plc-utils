import 'package:mcomp_plc_utils/src/config_fetcher/models/plc_config.dart';

/// Interface for a repository that provides PLC configurations
abstract class ConfigRepository {
  /// Fetches all PLC configurations for the current user
  /// 
  /// [forceRefresh] - If true, forces a refresh from the remote source
  /// Returns a list of PLC configurations
  Future<List<PlcConfig>> fetchConfigs({bool forceRefresh = false});
  
  /// Fetches a specific PLC configuration by ID
  /// 
  /// [id] - The ID of the PLC configuration to fetch
  /// [forceRefresh] - If true, forces a refresh from the remote source
  /// Returns the PLC configuration or null if not found
  Future<PlcConfig?> fetchConfig(String id, {bool forceRefresh = false});
  
  /// Clears the local cache of configurations
  Future<void> clearCache();
}
