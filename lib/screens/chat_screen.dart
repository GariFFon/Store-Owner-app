import 'package:flutter/material.dart';
import 'package:exanor/services/chat_service.dart';
import 'package:exanor/services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;

  const ChatScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isConnected = false;
  String? _myUserId; // Track our own userId to filter echoed messages

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    // Connect first — this decodes the JWT and sets myUserId immediately
    await _chatService.connect(widget.orderId);
    _myUserId = _chatService.myUserId;
    debugPrint('ChatScreen: My userId = $_myUserId');

    // Now load history (userId is available for isMe checks)
    _loadHistory();

    // Listen for incoming messages from Socket.IO
    _chatService.onMessageReceived.listen((message) {
      if (!mounted) return;
      // Skip our own echoed messages (we already added them optimistically)
      if (_myUserId != null && message.senderId == _myUserId) return;
      setState(() => _messages.add(message));
      _scrollToBottom();
    });

    _chatService.onConnectionChanged.listen((connected) {
      if (!mounted) return;
      setState(() => _isConnected = connected);
    });

    // Also listen for connected ack as backup
    _chatService.onConnectedAck.listen((data) {
      if (!mounted) return;
      if (data is Map && data['userId'] != null) {
        _myUserId = data['userId'].toString();
      }
    });
  }

  Future<void> _loadHistory() async {
    try {
      final response = await ApiService.getOrderChatHistory(widget.orderId);
      final List<dynamic> data = response['data'] ?? [];
      if (mounted) {
        setState(() {
          _messages = data.map((e) => ChatMessage.fromJson(e)).toList();
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Chat history load failed (expected during dev): $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || !_isConnected) return;

    _chatService.sendMessage(widget.orderId, text);

    // Optimistically add to UI
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        roomId: widget.orderId,
        senderId: _myUserId ?? 'ME',
        senderRole: 'STORE',
        content: text,
        createdAt: DateTime.now(),
      ));
    });

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _chatService.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    // Use ONLY senderId to identify "my" messages — senderRole is unreliable in history
    final isMe = msg.senderId == _myUserId || msg.senderId == 'ME';
    final isSystem = msg.messageType == 'SYSTEM_EVENT' || msg.senderId == 'SYSTEM';
    final isAdmin = msg.senderRole == 'ADMIN' || msg.senderRole == 'SUPPORT';

    // System messages (room created, etc.) — centered grey pill
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
             msg.content,
             style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
             textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Admin/support messages — centered red pill
    if (isAdmin) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
             "Exanor Support: " + msg.content,
             style: TextStyle(color: Colors.red.shade800, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFF97316) : Colors.white, // Orange for Store
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: !isMe ? const Radius.circular(4) : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.content,
              style: TextStyle(color: isMe ? Colors.white : const Color(0xFF334155), fontSize: 15, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              "${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}",
              style: TextStyle(color: isMe ? Colors.white70 : const Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             const Text("Customer Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
             Row(
               children: [
                 Container(
                   width: 8, height: 8,
                   decoration: BoxDecoration(color: _isConnected ? Colors.green : Colors.orange, shape: BoxShape.circle),
                 ),
                 const SizedBox(width: 4),
                 Text(_isConnected ? "Live Chat" : "Connecting...", style: const TextStyle(fontSize: 12, color: Colors.grey)),
               ],
             )
           ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined, color: Colors.red),
            onPressed: () async {
               await ApiService.createTicket(widget.orderId, "SUPPORT_REQUESTED");
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Support team notified!")));
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_messages[index]);
                  },
              ),
          ),
          Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12, left: 12, top: 12, right: 12),
            decoration: const BoxDecoration(
               color: Colors.white,
               boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Type a response...",
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
