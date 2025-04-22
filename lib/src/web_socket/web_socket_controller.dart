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
        logger: _logger,
        onReconnect: _onChannelReconnected,
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
        wsChannel.isConnected = false;

        // Start reconnection if auto-reconnect is enabled
        if (autoReconnect) {
          wsChannel.startReconnection();
        }
      },
      onError: (error) {
        _logger.severe(
          'WebSocket error for ${wsChannel.plcId}: $error',
        );
        wsChannel.isConnected = false;

        // Start reconnection if auto-reconnect is enabled
        if (autoReconnect) {
          wsChannel.startReconnection();
        }
      },
    );
  }

  /// Callback when a channel is reconnected
  void _onChannelReconnected(WebSocketChannelEntity channel) {
    _logger.info('Channel ${channel.plcId} reconnected, setting up listeners');

    // Set up listeners for the new channel
    _setupChannelListeners(channel);

    // Send initial update request
    channel.channel.sink.add(_kWssUpdateBody);
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
      channel.isConnected = false;
      if (autoReconnect) {
        channel.startReconnection();
      }
    }
  }

  /// Disconnect WebSocket channel
  ///
  /// [channel] - WebSocket channel to disconnect
  void _disconnectChannel(WebSocketChannelEntity channel) {
    try {
      // Stop any reconnection attempts
      channel.stopReconnection();

      // Dispose the channel
      channel.dispose();

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
      channel.isConnected = false;
      if (autoReconnect) {
        channel.startReconnection();
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
        channel.isConnected = false;
        if (autoReconnect) {
          channel.startReconnection();
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
    disconnectAll();
  }
}
