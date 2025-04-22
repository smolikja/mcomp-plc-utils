import 'package:equatable/equatable.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Entity representing a WebSocket connection
///
/// This is a simple data model without business logic
class WebSocketChannelEntity extends Equatable {
  /// Creates a new WebSocketChannelEntity
  ///
  /// [plcId] - Unique identifier for the PLC
  /// [address] - WebSocket address (without wss:// prefix)
  /// [channel] - The WebSocket channel
  /// [isConnected] - Whether the channel is currently connected
  const WebSocketChannelEntity({
    required this.plcId,
    required this.address,
    required this.channel,
    this.isConnected = true,
  });

  /// Unique identifier for the PLC
  final String plcId;

  /// WebSocket address (without wss:// prefix)
  final String address;

  /// The WebSocket channel
  final WebSocketChannel channel;

  /// Whether the channel is currently connected
  final bool isConnected;

  /// WebSocket address prefix
  static const String addressPrefix = 'wss://';

  /// Protocols to use for WebSocket connection
  static const List<String> protocols = ['devs'];

  /// Creates a copy of this entity with the given fields replaced
  WebSocketChannelEntity copyWith({
    String? plcId,
    String? address,
    WebSocketChannel? channel,
    bool? isConnected,
  }) {
    return WebSocketChannelEntity(
      plcId: plcId ?? this.plcId,
      address: address ?? this.address,
      channel: channel ?? this.channel,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  List<Object?> get props => [plcId, address, channel, isConnected];
}
