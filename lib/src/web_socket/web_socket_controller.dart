import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:mcomp_plc_utils/src/web_socket/bos/ws_get_message_bo.dart'
    show WsGetMessageBO;
import 'package:mcomp_plc_utils/src/web_socket/bos/ws_set_message_bo.dart';
import 'package:mcomp_plc_utils/src/web_socket/bos/ws_set_messgae_payload_bo.dart';
import 'package:mcomp_plc_utils/src/web_socket/entities/web_socket_channel_entity.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Controller for managing WebSocket connections to PLCs
class WebSocketController {
  /// Get the singleton instance of WebSocketController
  factory WebSocketController() {
    return _webSocketController;
  }

  WebSocketController._internal() {
    // Start the heartbeat timer
    _startHeartbeatTimer();
  }

  // Constants
  static const _kWssUpdateBody = '{"intent": "list"}';
  static const _kHeartbeatMessage = '{"intent": "ping"}';

  // Configuration
  /// Heartbeat interval in milliseconds (default: 30 seconds)
  static int heartbeatInterval = 30000;

  /// Whether to automatically reconnect on connection loss (default: true)
  static bool autoReconnect = true;

  /// Maximum number of reconnection attempts (default: 10)
  static int maxReconnectAttempts = 10;

  /// Base delay for reconnection attempts in milliseconds (default: 1 second)
  static int baseReconnectDelay = 1000;

  /// Maximum delay for reconnection attempts in milliseconds (default: 30 seconds)
  static int maxReconnectDelay = 30000;

  // Singleton instance
  static final WebSocketController _webSocketController =
      WebSocketController._internal();

  // State
  final List<WebSocketChannelEntity> _openedChannels = [];
  final Map<String, Timer?> _reconnectTimers = {};
  final Map<String, int> _reconnectAttempts = {};
  Timer? _heartbeatTimer;

  /// Get all open WebSocket channels
  List<WebSocketChannelEntity> get channels => _openedChannels;

  final _logger = Logger('WebSocketController');

  // MARK: - Connection

  /// Connect to WebSocket
  ///
  /// [plcId] - PLC identifier
  /// [address] - WebSocket address (without wss:// prefix)
  /// [autoReconnect] - Whether to automatically reconnect on connection loss (default: uses global setting)
  void connect({
    required String plcId,
    required String address,
    bool? autoReconnect,
  }) {
    if (_openedChannels.any((channel) => channel.plcId == plcId)) {
      _logger.warning(
        'WebSocket for $plcId, address: $address is already connected',
      );
      return;
    }

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(WebSocketChannelEntity.addressPrefix + address),
        protocols: WebSocketChannelEntity.protocols,
      );

      final wsChannel = WebSocketChannelEntity(
        plcId: plcId,
        address: address,
        channel: channel,
      );

      _openedChannels.add(wsChannel);

      // Set up stream subscription to detect disconnection
      _setupChannelListeners(wsChannel);

      // Send initial update request
      channel.sink.add(_kWssUpdateBody);

      _logger.info('WebSocket connected to $plcId, address: $address');
    } catch (e) {
      _logger.severe(
        'WebSocket connection to $plcId, address: $address error: $e',
      );
    }
  }

  /// Connect to multiple WebSockets
  ///
  /// [connections] - List of PLC ID and WebSocket address pairs
  void connectAll(List<({String plcId, String address})> connections) {
    for (final connection in connections) {
      connect(plcId: connection.plcId, address: connection.address);
    }
  }

  /// Set up listeners for a WebSocket channel
  void _setupChannelListeners(WebSocketChannelEntity wsChannel) {
    // Listen for done events to detect disconnection
    wsChannel.channel.stream.listen(
      null,
      onDone: () {
        _logger.warning(
          'WebSocket connection to ${wsChannel.plcId} closed unexpectedly',
        );

        // Update the channel with isConnected = false
        _updateChannelConnectionState(wsChannel.plcId, false);

        // Start reconnection if auto-reconnect is enabled
        if (autoReconnect) {
          _startReconnection(wsChannel.plcId);
        }
      },
      onError: (error) {
        _logger.severe(
          'WebSocket error for ${wsChannel.plcId}: $error',
        );

        // Update the channel with isConnected = false
        _updateChannelConnectionState(wsChannel.plcId, false);

        // Start reconnection if auto-reconnect is enabled
        if (autoReconnect) {
          _startReconnection(wsChannel.plcId);
        }
      },
    );
  }

  /// Update the connection state of a channel
  void _updateChannelConnectionState(String plcId, bool isConnected) {
    final index =
        _openedChannels.indexWhere((channel) => channel.plcId == plcId);
    if (index != -1) {
      final channel = _openedChannels[index];
      _openedChannels[index] = channel.copyWith(isConnected: isConnected);
    }
  }

  /// Calculate the delay for the next reconnection attempt using exponential backoff
  int _getNextReconnectDelay(String plcId) {
    final attempts = _reconnectAttempts[plcId] ?? 0;
    // Calculate delay with exponential backoff: baseDelay * 2^attempts
    // But cap it at maxReconnectDelay
    final delay = baseReconnectDelay * (1 << attempts);
    return delay < maxReconnectDelay ? delay : maxReconnectDelay;
  }

  /// Start reconnection attempts for a channel
  void _startReconnection(String plcId) {
    // Cancel any existing reconnection timer
    _stopReconnection(plcId);

    // Reset reconnection attempts
    _reconnectAttempts[plcId] = 0;

    // Schedule reconnection
    _scheduleReconnect(plcId);
  }

  /// Stop reconnection attempts for a channel
  void _stopReconnection(String plcId) {
    _reconnectTimers[plcId]?.cancel();
    _reconnectTimers[plcId] = null;
    _reconnectAttempts.remove(plcId);
  }

  /// Schedule the next reconnection attempt
  void _scheduleReconnect(String plcId) {
    final attempts = _reconnectAttempts[plcId] ?? 0;

    if (attempts >= maxReconnectAttempts) {
      _logger.severe('Maximum reconnection attempts reached for $plcId');
      _stopReconnection(plcId);
      return;
    }

    final delay = _getNextReconnectDelay(plcId);
    _logger.info(
      'Scheduling reconnection attempt ${attempts + 1} for $plcId in ${delay}ms',
    );

    _reconnectTimers[plcId] = Timer(
      Duration(milliseconds: delay),
      () => _attemptReconnect(plcId),
    );
  }

  /// Attempt to reconnect to the WebSocket
  void _attemptReconnect(String plcId) {
    // Increment reconnection attempts
    _reconnectAttempts[plcId] = (_reconnectAttempts[plcId] ?? 0) + 1;

    // Find the channel
    final index =
        _openedChannels.indexWhere((channel) => channel.plcId == plcId);
    if (index == -1) {
      _logger.warning('Cannot reconnect: channel $plcId not found');
      _stopReconnection(plcId);
      return;
    }

    final channel = _openedChannels[index];

    try {
      _logger.info(
        'Attempting to reconnect to ${channel.plcId} at ${channel.address} (attempt ${_reconnectAttempts[plcId]})',
      );

      // Close the old channel if it's still open
      try {
        channel.channel.sink.close();
      } catch (e) {
        // Ignore errors when closing the old channel
      }

      // Create a new channel
      final newChannel = WebSocketChannel.connect(
        Uri.parse(WebSocketChannelEntity.addressPrefix + channel.address),
        protocols: WebSocketChannelEntity.protocols,
      );

      // Create a new entity with the new channel and isConnected = true
      final newEntity = channel.copyWith(
        channel: newChannel,
        isConnected: true,
      );

      // Replace the old entity with the new one
      _openedChannels[index] = newEntity;

      // Set up listeners for the new channel
      _setupChannelListeners(newEntity);

      // Send initial update request
      newChannel.sink.add(_kWssUpdateBody);

      _logger.info(
        'Successfully reconnected to ${channel.plcId} at ${channel.address}',
      );
      _stopReconnection(plcId);
    } catch (e) {
      _logger.warning(
        'Failed to reconnect to ${channel.plcId} at ${channel.address}: $e',
      );
      _scheduleReconnect(plcId);
    }
  }

  // MARK: - Disconnection

  /// Disconnect WebSocket
  ///
  /// [plcId] - PLC identifier
  void disconnect(String plcId) {
    try {
      final channel = _openedChannels.firstWhere(
        (channel) => channel.plcId == plcId,
      );
      _disconnectChannel(channel);
      _openedChannels.remove(channel);
    } catch (e) {
      _logger.severe(
        'WebSocket for $plcId is not connected and tries to disconnect, error: $e',
      );
    }
  }

  /// Disconnect all WebSockets
  void disconnectAll() {
    for (final channel in _openedChannels.toList()) {
      _disconnectChannel(channel);
    }
    _openedChannels.clear();
  }

  /// Request State Update
  ///
  /// [plcId] - PLC identifier
  /// [deviceIds] - List of device identifiers
  void requestStateUpdate({
    required String plcId,
    required List<String> deviceIds,
  }) {
    final channel = _findChannel(plcId);
    if (channel == null || !channel.isConnected) {
      _logger
          .warning('Cannot request state update: channel $plcId not connected');
      return;
    }

    final message = jsonEncode(
      WsGetMessageBO(payload: deviceIds),
    );
    _logger.info(
      'Requesting state update of devices: $deviceIds, on PLC: $plcId',
    );

    try {
      channel.channel.sink.add(message);
    } catch (e) {
      _logger.severe('Error sending state update request: $e');
      _updateChannelConnectionState(plcId, false);
      if (autoReconnect) {
        _startReconnection(plcId);
      }
    }
  }

  /// Disconnect WebSocket channel
  ///
  /// [channel] - WebSocket channel to disconnect
  void _disconnectChannel(WebSocketChannelEntity channel) {
    try {
      // Stop any reconnection attempts
      _stopReconnection(channel.plcId);

      // Close the channel
      try {
        channel.channel.sink.close();
      } catch (e) {
        _logger.warning('Error closing channel for ${channel.plcId}: $e');
      }

      _logger.info(
        'WebSocket for ${channel.plcId} with ${channel.address} disconnected',
      );
    } catch (e) {
      _logger.severe(
        'WebSocket for ${channel.plcId} with ${channel.address} disconnect error: $e',
      );
    }
  }

  // MARK: - Sending messages

  /// Update device
  ///
  /// [plcId] - PLC identifier
  /// [deviceId] - Device identifier
  /// [update] - Update properties
  void updateDevice({
    required String plcId,
    required String deviceId,
    required Map<String, dynamic> update,
  }) {
    final message = jsonEncode(
      WsSetMessageBO(
        payload: [WsSetMessgaePayloadBO(id: deviceId, update: update)],
      ),
    );
    sendMessage(plcId: plcId, message: message);
  }

  /// Send message to WebSocket
  ///
  /// [plcId] - PLC identifier
  /// [message] - Message to send
  void sendMessage({
    required String plcId,
    required String message,
  }) {
    final channel = _findChannel(plcId);
    if (channel == null) {
      _logger.warning('Cannot send message: channel $plcId not found');
      return;
    }

    if (!channel.isConnected) {
      _logger.warning('Cannot send message: channel $plcId not connected');
      return;
    }

    try {
      channel.channel.sink.add(message);
    } catch (e) {
      _logger.severe('Error sending message to $plcId: $e');
      _updateChannelConnectionState(plcId, false);
      if (autoReconnect) {
        _startReconnection(plcId);
      }
    }
  }

  // MARK: - Heartbeat

  /// Start the heartbeat timer
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: heartbeatInterval),
      (_) => _sendHeartbeat(),
    );
    _logger
        .fine('Heartbeat timer started with interval ${heartbeatInterval}ms');
  }

  /// Stop the heartbeat timer
  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.fine('Heartbeat timer stopped');
  }

  /// Send heartbeat to all connected channels
  void _sendHeartbeat() {
    if (_openedChannels.isEmpty) {
      return;
    }

    _logger.fine('Sending heartbeat to ${_openedChannels.length} channels');

    for (final channel in _openedChannels) {
      if (!channel.isConnected) continue;

      try {
        channel.channel.sink.add(_kHeartbeatMessage);
      } catch (e) {
        _logger.warning('Error sending heartbeat to ${channel.plcId}: $e');
        _updateChannelConnectionState(channel.plcId, false);
        if (autoReconnect) {
          _startReconnection(channel.plcId);
        }
      }
    }
  }

  /// Find a channel by PLC ID
  WebSocketChannelEntity? _findChannel(String plcId) {
    try {
      return _openedChannels.firstWhere((channel) => channel.plcId == plcId);
    } catch (e) {
      return null;
    }
  }

  /// Dispose of resources
  void dispose() {
    _stopHeartbeatTimer();

    // Stop all reconnection timers
    for (final plcId in _reconnectTimers.keys.toList()) {
      _stopReconnection(plcId);
    }

    disconnectAll();
  }
}
