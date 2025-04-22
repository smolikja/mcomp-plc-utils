import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/cache/config_cache.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/models/plc_config.dart';
import 'package:mcomp_plc_utils/src/config_fetcher/repository/config_repository.dart';

/// Implementation of ConfigRepository using Firebase
class FirebaseConfigRepository implements ConfigRepository {
  /// Creates a new FirebaseConfigRepository
  /// 
  /// [cache] - The cache to use for storing configurations
  /// [logger] - Optional logger for logging events
  /// [cacheValidityDuration] - How long the cache is considered valid (default: 1 hour)
  FirebaseConfigRepository({
    required this.cache,
    Logger? logger,
    this.cacheValidityDuration = const Duration(hours: 1),
  }) : _logger = logger ?? Logger('FirebaseConfigRepository');

  /// The cache used for storing configurations
  final ConfigCache cache;
  
  /// How long the cache is considered valid
  final Duration cacheValidityDuration;
  
  final Logger _logger;
  
  static const String _configFileExtension = '.json';
  static const String _firestoreCollection = 'plcs';
  static const String _firestoreKeyUsers = 'users';
  static const String _firestoreKeyEmail = 'email';
  static const String _firestoreKeyUid = 'uid';
  static const int _oneMegabyte = 1024 * 1024;
  
  @override
  Future<List<PlcConfig>> fetchConfigs({bool forceRefresh = false}) async {
    _logger.fine('Fetching configs, forceRefresh: $forceRefresh');
    
    // Check if we should use cache
    if (!forceRefresh) {
      final lastUpdateTime = await cache.getLastUpdateTime();
      final configs = await cache.getConfigs();
      
      if (lastUpdateTime != null && 
          configs.isNotEmpty && 
          DateTime.now().difference(lastUpdateTime) < cacheValidityDuration) {
        _logger.fine('Using cached configs, count: ${configs.length}');
        return configs;
      }
    }
    
    // Fetch from remote
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await currentUser?.reload();
      
      if (currentUser == null || currentUser.email == null) {
        throw Exception('Current user is null or has no email');
      }
      
      final identifiers = await _fetchPlcIdentifiers(
        userEmail: currentUser.email!,
        userUid: currentUser.uid,
      );
      
      if (identifiers == null || identifiers.isEmpty) {
        _logger.warning('No PLC identifiers found for user');
        return [];
      }
      
      final configs = await _fetchPlcConfigs(identifiers);
      
      // Save to cache
      if (configs.isNotEmpty) {
        await cache.saveConfigs(configs);
      }
      
      return configs;
    } catch (e, stackTrace) {
      _logger.severe('Error fetching configs from remote', e, stackTrace);
      
      // Try to use cache as fallback
      if (forceRefresh) {
        final cachedConfigs = await cache.getConfigs();
        if (cachedConfigs.isNotEmpty) {
          _logger.info('Using cached configs as fallback after remote error');
          return cachedConfigs;
        }
      }
      
      rethrow;
    }
  }
  
  @override
  Future<PlcConfig?> fetchConfig(String id, {bool forceRefresh = false}) async {
    _logger.fine('Fetching config for ID: $id, forceRefresh: $forceRefresh');
    
    // Check if we should use cache
    if (!forceRefresh) {
      final lastUpdateTime = await cache.getLastUpdateTime();
      final config = await cache.getConfig(id);
      
      if (lastUpdateTime != null && 
          config != null && 
          DateTime.now().difference(lastUpdateTime) < cacheValidityDuration) {
        _logger.fine('Using cached config for ID: $id');
        return config;
      }
    }
    
    // Fetch all configs and find the one we need
    final configs = await fetchConfigs(forceRefresh: forceRefresh);
    try {
      return configs.firstWhere((config) => config.id == id);
    } catch (e) {
      _logger.warning('Config with ID $id not found');
      return null;
    }
  }
  
  @override
  Future<void> clearCache() async {
    await cache.clearCache();
  }
  
  /// Fetches PLC identifiers from Firestore
  Future<List<String>?> _fetchPlcIdentifiers({
    required String userEmail,
    required String userUid,
  }) async {
    try {
      final documents = await FirebaseFirestore.instance
          .collection(_firestoreCollection)
          .where(
        _firestoreKeyUsers,
        arrayContains: {
          _firestoreKeyEmail: userEmail,
          _firestoreKeyUid: userUid,
        },
      ).get();
      
      _logger.fine('Found ${documents.docs.length} PLC documents');
      
      final plcIds = <String>[];
      for (final doc in documents.docs) {
        _logger.fine('PLC ID: ${doc.id}');
        plcIds.add(doc.id);
      }
      
      return plcIds.isEmpty ? null : plcIds;
    } catch (e, stackTrace) {
      _logger.severe('Error fetching PLC identifiers', e, stackTrace);
      rethrow;
    }
  }
  
  /// Fetches PLC configurations from Firebase Storage
  Future<List<PlcConfig>> _fetchPlcConfigs(List<String> identifiers) async {
    final configs = <PlcConfig>[];
    final storageRef = FirebaseStorage.instance.ref();
    
    for (final plcId in identifiers) {
      try {
        final pathReference = storageRef.child(plcId + _configFileExtension);
        
        // Get metadata for version checking
        final metadata = await pathReference.getMetadata();
        _logger.fine('Config metadata for $plcId: ${metadata.customMetadata}');
        
        // Get the data
        final data = await pathReference.getData(_oneMegabyte);
        
        if (data == null || data.isEmpty) {
          _logger.warning('Empty data for PLC ID: $plcId');
          continue;
        }
        
        final dataString = utf8.decode(data);
        final configMap = jsonDecode(dataString) as Map<String, dynamic>;
        
        // Ensure the ID is set
        if (!configMap.containsKey('id')) {
          configMap['id'] = plcId;
        }
        
        configs.add(DefaultPlcConfig.fromJson(configMap));
        _logger.fine('Fetched config for PLC ID: $plcId');
      } catch (e, stackTrace) {
        _logger.severe('Error fetching config for PLC ID: $plcId', e, stackTrace);
        // Continue with other configs
      }
    }
    
    _logger.info('Fetched ${configs.length} PLC configurations');
    return configs;
  }
}
