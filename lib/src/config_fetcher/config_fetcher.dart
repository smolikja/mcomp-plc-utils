import 'package:logging/logging.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/cache/shared_prefs_config_cache.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/repository/config_repository.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/repository/firebase_config_repository.dart';

/// Fetches PLC configurations from Firebase with caching support
class ConfigFetcher {
  static final _logger = Logger('ConfigFetcher');
  static ConfigRepository? _repository;

  /// Initialize the ConfigFetcher with custom dependencies
  ///
  /// [repository] - Custom repository implementation
  /// [cacheValidityDuration] - How long the cache is considered valid
  static void initialize({
    ConfigRepository? repository,
    Duration cacheValidityDuration = const Duration(hours: 1),
  }) {
    if (repository != null) {
      _repository = repository;
      _logger.info('ConfigFetcher initialized with custom repository');
      return;
    }

    // Create default repository with SharedPreferences cache
    final cache = SharedPrefsConfigCache(logger: _logger);
    _repository = FirebaseConfigRepository(
      cache: cache,
      logger: _logger,
      cacheValidityDuration: cacheValidityDuration,
    );

    _logger.info('ConfigFetcher initialized with default repository');
  }

  /// Get the repository instance, creating it if necessary
  static ConfigRepository _getRepository() {
    if (_repository == null) {
      initialize();
    }
    return _repository!;
  }

  /// Fetch user's PLCs from Firebase Storage with caching
  ///
  /// Returns list of assigned PLCs as Map of String to dynamic
  /// [forceRefresh] - If true, forces a refresh from the remote source
  /// Throws [Exception] if current user is null or email is null
  /// Returns empty list if no PLCs are found
  static Future<List<Map<String, dynamic>>> fetchUserPlcs({
    bool forceRefresh = false,
  }) async {
    try {
      final configs = await _getRepository().fetchConfigs(
        forceRefresh: forceRefresh,
      );

      return configs.map((config) => config.toJson()).toList();
    } catch (e, stackTrace) {
      _logger.severe('Error fetching user PLCs', e, stackTrace);
      rethrow;
    }
  }

  /// Fetch a specific PLC configuration by ID
  ///
  /// [id] - The ID of the PLC to fetch
  /// [forceRefresh] - If true, forces a refresh from the remote source
  /// Returns the PLC configuration or null if not found
  static Future<Map<String, dynamic>?> fetchPlc(
    String id, {
    bool forceRefresh = false,
  }) async {
    try {
      final config = await _getRepository().fetchConfig(
        id,
        forceRefresh: forceRefresh,
      );

      return config?.toJson();
    } catch (e, stackTrace) {
      _logger.severe('Error fetching PLC with ID: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Clear the configuration cache
  static Future<void> clearCache() async {
    await _getRepository().clearCache();
    _logger.info('Configuration cache cleared');
  }
}
