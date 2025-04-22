import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Entity representing a WebSocket connection with reconnection capabilities
class WebSocketChannelEntity extends Equatable {
  /// Creates a new WebSocketChannelEntity
  ///
  /// [plcId] - Unique identifier for the PLC
  /// [address] - WebSocket address (without wss:// prefix)
  /// [channel] - The WebSocket channel
  /// [isConnected] - Whether the channel is currently connected
  /// [onReconnect] - Callback to execute after successful reconnection
  /// [logger] - Optional logger for logging events
  WebSocketChannelEntity({
    required this.plcId,
    required this.address,
    required this.channel,
    this.isConnected = true,
    this.onReconnect,
    Logger? logger,
  }) : _logger = logger ?? Logger('WebSocketChannelEntity:$plcId');

  /// Unique identifier for the PLC
  final String plcId;

  /// WebSocket address (without wss:// prefix)
  final String address;

  /// The WebSocket channel
  WebSocketChannel channel;

  /// Whether the channel is currently connected
  bool isConnected;

  /// Callback to execute after successful reconnection
  final void Function(WebSocketChannelEntity channel)? onReconnect;

  /// Logger for this channel
  final Logger _logger;

  /// Timer for reconnection attempts
  Timer? _reconnectTimer;

  /// Number of reconnection attempts
  int _reconnectAttempts = 0;

  /// Maximum number of reconnection attempts
  static const int maxReconnectAttempts = 10;

  /// Base delay for reconnection attempts (in milliseconds)
  static const int baseReconnectDelay = 1000; // 1 second

  /// Maximum delay for reconnection attempts (in milliseconds)
  static const int maxReconnectDelay = 30000; // 30 seconds

  /// Protocols to use for WebSocket connection
  static const List<String> protocols = ['devs'];

  /// WebSocket address prefix
  static const String addressPrefix = 'wss://';

  /// Calculate the delay for the next reconnection attempt using exponential backoff
  int get _nextReconnectDelay {
    // Calculate delay with exponential backoff: baseDelay * 2^attempts
    // But cap it at maxReconnectDelay
    final delay = baseReconnectDelay * (1 << _reconnectAttempts);
    return delay < maxReconnectDelay ? delay : maxReconnectDelay;
  }

  /// Start reconnection attempts
  void startReconnection() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) {
      _logger.fine('Reconnection already in progress');
      return;
    }

    isConnected = false;
    _reconnectAttempts = 0;
    _scheduleReconnect();
  }

  /// Stop reconnection attempts
  void stopReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  /// Schedule the next reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _logger.severe('Maximum reconnection attempts reached');
      stopReconnection();
      return;
    }

    final delay = _nextReconnectDelay;
    _logger.info(
        'Scheduling reconnection attempt ${_reconnectAttempts + 1} in ${delay}ms');

    _reconnectTimer = Timer(Duration(milliseconds: delay), _attemptReconnect);
  }

  /// Attempt to reconnect to the WebSocket
  void _attemptReconnect() {
    _reconnectAttempts++;

    try {
      _logger.info(
          'Attempting to reconnect to $plcId at $address (attempt $_reconnectAttempts)');

      // Close the old channel if it's still open
      try {
        channel.sink.close();
      } catch (e) {
        // Ignore errors when closing the old channel
      }

      // Create a new channel
      channel = WebSocketChannel.connect(
        Uri.parse(addressPrefix + address),
        protocols: protocols,
      );

      // Mark as connected
      isConnected = true;

      // Call the reconnect callback if provided
      if (onReconnect != null) {
        onReconnect!(this);
      }

      _logger.info('Successfully reconnected to $plcId at $address');
      stopReconnection();
    } catch (e) {
      _logger.warning('Failed to reconnect to $plcId at $address: $e');
      _scheduleReconnect();
    }
  }

  /// Dispose of resources
  void dispose() {
    stopReconnection();
    try {
      channel.sink.close();
    } catch (e) {
      _logger.warning('Error closing channel: $e');
    }
  }

  @override
  List<Object?> get props => [plcId, address, channel, isConnected];
}
