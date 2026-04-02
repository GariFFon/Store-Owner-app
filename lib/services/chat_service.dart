import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:exanor/services/api_service.dart';

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderRole; // 'CUSTOMER', 'STORE', 'ADMIN'
  final String content;
  final String messageType; // 'TEXT', 'IMAGE', 'SYSTEM_EVENT'
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderRole,
    required this.content,
    this.messageType = 'TEXT',
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      roomId: json['roomId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderRole: json['senderRole'] ?? 'UNKNOWN',
      content: json['content'] ?? '',
      messageType: json['messageType'] ?? 'TEXT',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : DateTime.now(),
    );
  }
}

class ChatService {
  static final ChatService _instance = ChatService._internal();

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  IO.Socket? _socket;
  String? _currentRoomId;
  String? _myUserId;

  /// The authenticated user's ID, extracted from the JWT token.
  String? get myUserId => _myUserId;

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onMessageReceived => _messageController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  final _connectedAckController = StreamController<dynamic>.broadcast();
  Stream<dynamic> get onConnectedAck => _connectedAckController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Resolve the correct chat server URL.
  /// On a real device you MUST use your machine's LAN IP (e.g. 192.168.x.x).
  /// On Android emulator use 10.0.2.2, on iOS simulator use localhost.
  String _getChatUrl() {
    const bool isLocalDev = false;

    if (isLocalDev) {
      const String lanIp = '192.168.1.5';
      if (Platform.isAndroid) return 'http://10.0.2.2:4000';
      if (Platform.isIOS) return 'http://localhost:4000';
      return 'http://$lanIp:4000';
    }

    return 'https://exanor-chat-service.onrender.com';
  }

  Future<void> connect(String orderId) async {
    if (_socket != null && _socket!.connected) {
      if (_currentRoomId == orderId) return;
      disconnect();
    }

    try {
      final token = await ApiService.getAccessToken();
      if (token == null) {
        developer.log('ChatService: ❌ Cannot connect — no auth token');
        return;
      }

      // Decode JWT to extract userId immediately (before socket connects)
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = json.decode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          );
          _myUserId = (payload['sub'] ?? payload['user_id'] ?? '').toString();
          developer.log('ChatService: 👤 My userId = $_myUserId');
        }
      } catch (e) {
        developer.log('ChatService: ⚠️ JWT decode failed: $e');
      }

      final url = _getChatUrl();
      developer.log('ChatService: 🔌 Connecting to $url/chat ...');

      // ── IMPORTANT: The NestJS gateway uses namespace "/chat" ──
      _socket = IO.io(
        '$url/chat',                // ← must include the /chat namespace
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );

      _socket!.onConnect((_) {
        developer.log('ChatService: ✅ Socket connected!');
        _connectionController.add(true);
        _joinRoom(orderId);
      });

      _socket!.onDisconnect((_) {
        developer.log('ChatService: 🔌 Socket disconnected');
        _connectionController.add(false);
      });

      _socket!.onError((data) {
        developer.log('ChatService: ❌ Socket error → $data');
      });

      _socket!.onConnectError((data) {
        developer.log('ChatService: ❌ Connect error → $data');
      });

      // ── Listen for the server's "connected" ack ──
      _socket!.on('connected', (data) {
        developer.log('ChatService: 🤝 Server ack → $data');
        _connectedAckController.add(data);
      });

      // ── Listen for incoming messages (NestJS emits "new_message") ──
      _socket!.on('new_message', (data) {
        developer.log('ChatService: 💬 new_message → $data');
        try {
          final message =
              ChatMessage.fromJson(Map<String, dynamic>.from(data));
          _messageController.add(message);
        } catch (e) {
          developer.log('ChatService: ❌ parse error — $e');
        }
      });

      // ── Listen for room_joined confirmation ──
      _socket!.on('room_joined', (data) {
        developer.log('ChatService: 📥 room_joined → $data');
      });

      // ── Listen for errors from server ──
      _socket!.on('error', (data) {
        developer.log('ChatService: ⚠️ Server error event → $data');
      });

      _socket!.connect();
    } catch (e) {
      developer.log('ChatService: ❌ Exception during connect: $e');
    }
  }

  /// Join a specific order room — NestJS event is "join_room" (snake_case)
  void _joinRoom(String orderId) {
    if (_socket != null && _socket!.connected) {
      developer.log('ChatService: 📥 Emitting join_room for $orderId');
      _socket!.emit('join_room', {'roomId': orderId});
      _currentRoomId = orderId;
    }
  }

  /// Send a message — NestJS event is "send_message" (snake_case)
  void sendMessage(String orderId, String content) {
    if (_socket != null && _socket!.connected) {
      developer.log('ChatService: 📤 Sending message to room $orderId');
      _socket!.emit('send_message', {
        'roomId': orderId,
        'content': content,
        'messageType': 'TEXT',
      });
    } else {
      developer.log('ChatService: ⚠️ Cannot send — socket not connected');
    }
  }

  void disconnect() {
    developer.log('ChatService: 🔌 Disconnecting...');
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _currentRoomId = null;
    _connectionController.add(false);
  }
}
