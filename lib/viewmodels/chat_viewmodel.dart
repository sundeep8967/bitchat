import 'base_viewmodel.dart';
import '../services/mesh_service.dart';

class ChatViewModel extends BaseViewModel {
  final MeshService _meshService = MeshService();
  final List<Map<String, dynamic>> _messages = [];
  
  // Current chat recipient (peer ID)
  String? _recipientId;
  String? get recipientId => _recipientId;

  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  
  ChatViewModel() {
    _initService();
  }
  
  void setRecipient(String peerId) {
    _recipientId = peerId;
    _messages.clear(); // Clear messages when switching conversations
    notifyListeners();
  }
  
  void _initService() {
    _meshService.messageStream.listen((message) {
      // Only add messages from current conversation
      if (_recipientId == null || message.senderId == _recipientId) {
        _messages.add({
          'text': message.content,
          'isMe': false,
          'isSystem': false,
          'senderId': message.senderId,
          'timestamp': message.timestamp,
        });
        notifyListeners();
      }
    });
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty || _recipientId == null) return;
    
    // Add locally immediately (optimistic UI)
    _messages.add({
      'text': text,
      'isMe': true, 
      'isSystem': false,
      'timestamp': DateTime.now(),
    });
    notifyListeners();

    // Send via Mesh to specific recipient
    _meshService.sendMessage(_recipientId!, text);
  }
  
  /// Send broadcast message to all peers
  void sendBroadcast(String text) {
    if (text.trim().isEmpty) return;
    
    _messages.add({
      'text': text,
      'isMe': true, 
      'isSystem': false,
      'isBroadcast': true,
      'timestamp': DateTime.now(),
    });
    notifyListeners();

    // Use "broadcast" as special recipient ID
    _meshService.sendMessage("broadcast", text);
  }
}

