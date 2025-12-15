import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/chat_viewmodel.dart';

class ChatScreen extends StatelessWidget {
  final String peerName;
  final String peerId;

  const ChatScreen({
    super.key, 
    required this.peerName,
    required this.peerId,
  });

  @override
  Widget build(BuildContext context) {
    // Note: Creating a new instance or using an existing provider depends on scope.
    // For this simple example, we'll re-use the global ChatViewModel injected in main.
    // Ideally, we'd scope a new ChatViewModel for this specific peerId.
    
    final TextEditingController controller = TextEditingController();
    final ScrollController scrollController = ScrollController();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F0F), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Consumer<ChatViewModel>(
                  builder: (context, model, child) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (scrollController.hasClients) {
                        scrollController.animateTo(
                          scrollController.position.maxScrollExtent,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    });
                    
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: model.messages.length,
                      itemBuilder: (context, index) {
                        final msg = model.messages[index];
                        return _buildMessageBubble(context, msg);
                      },
                    );
                  },
                ),
              ),
              _buildInputArea(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Map<String, dynamic> msg) {
    final isMe = msg['isMe'] as bool;
    final isSystem = msg['isSystem'] as bool;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Text(
            msg['text'],
            style: const TextStyle(color: AppTheme.primary, fontSize: 10),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe ? AppTheme.instagramGradient : null,
          color: isMe ? null : AppTheme.surface,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? Radius.zero : null,
            bottomLeft: isMe ? null : Radius.zero,
          ),
          border: isMe ? null : Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
              if (isMe) 
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
          ],
        ),
        child: Text(
          msg['text'],
          style: TextStyle(
            color: isMe ? Colors.black : Colors.white,
            fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppTheme.secondary.withOpacity(0.2),
            child: Text(peerName[0], style: const TextStyle(color: AppTheme.secondary)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                peerName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
                  const SizedBox(width: 4),
                  const Text(
                    'Direct Link Encrypted',
                    style: TextStyle(color: AppTheme.primary, fontSize: 10, letterSpacing: 0.5),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(LucideIcons.moreVertical, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (text) {
                   context.read<ChatViewModel>().sendMessage(text);
                   controller.clear();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
               context.read<ChatViewModel>().sendMessage(controller.text);
               controller.clear();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.send, color: Colors.black, size: 20),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1)),
        ],
      ),
    );
  }
}
