/// Abstract class representing a PLC configuration
abstract class PlcConfig {
  /// Unique identifier of the PLC
  String get id;
  
  /// Convert the configuration to a JSON map
  Map<String, dynamic> toJson();
  
  /// Create a configuration from a JSON map
  static PlcConfig fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('Subclasses must implement fromJson');
  }
}

/// Default implementation of PlcConfig that can be used directly
class DefaultPlcConfig implements PlcConfig {
  /// Creates a new DefaultPlcConfig with the given data
  DefaultPlcConfig({
    required this.id,
    required this.data,
  });
  
  /// Creates a DefaultPlcConfig from a JSON map
  factory DefaultPlcConfig.fromJson(Map<String, dynamic> json) {
    return DefaultPlcConfig(
      id: json['id'] as String,
      data: json,
    );
  }
  
  @override
  final String id;
  
  /// The raw configuration data
  final Map<String, dynamic> data;
  
  @override
  Map<String, dynamic> toJson() => data;
}
