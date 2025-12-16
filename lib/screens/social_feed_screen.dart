import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:characters/characters.dart';
import '../services/snap_service.dart';
import '../services/friend_service.dart';
import '../models/friend.dart';
import 'profile_setup_screen.dart';
import 'dart:math' as math;

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  // Brand Colors
  static const Color _snapRed = Color(0xFFFF5252);
  static const Color _snapBlue = Color(0xFF448AFF);
  static const Color _snapPurple = Color(0xFFAA00FF);
  
  // Data
  List<Friend> _friends = [];
  Map<String, Snap> _latestSnaps = {}; // Cache latest snap per friend
  StreamSubscription<Snap>? _snapSubscription;
  bool _isLoading = true;
  
  // Search
  final _searchController = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToSnaps();
  }
  
  Future<void> _loadData() async {
    await FriendService.instance.init();
    
    // Load active snaps to sync status
    try {
      final snaps = await SnapService.instance.getActiveSnaps();
      for (final snap in snaps) {
        _latestSnaps[snap.senderAlias] = snap; // Assuming alias is username
      }
    } catch (e) {
      print('Failed to load snaps: $e');
    }

    _refreshFriends();
  }

  void _subscribeToSnaps() {
    _snapSubscription = SnapService.instance.snapStream.listen((snap) async {
       if (mounted) {
         setState(() {
           _latestSnaps[snap.senderAlias] = snap;
         });
         
         // Update Friend Status
         if (FriendService.instance.isFriend(snap.senderAlias)) {
           await FriendService.instance.updateFriendStatus(snap.senderAlias, FriendStatus.newSnap);
           _refreshFriends();
           
           HapticFeedback.heavyImpact(); // Notify user
         }
       }
    });
  }

  void _refreshFriends() {
    setState(() {
      _friends = List.from(FriendService.instance.friends);
      
      // Sync status from available snaps
      for (var i = 0; i < _friends.length; i++) {
        final f = _friends[i];
        if (_latestSnaps.containsKey(f.username)) {
           // If we have a snap, ensure status reflects it (unless already opened?)
           // For now, simpler: if cached snap exists, it's "New Snap" unless logic says otherwise
           // Real implementation would track "viewed" state per snap ID
        }
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _snapSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Mesh Gradient Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    Color(0xFF2E3A59), // Deep Blue-Grey
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // 2. Glass Header
                _buildHeader(),
                
                // 3. Friends List
                Expanded(
                  child: _friends.isEmpty && !_isLoading
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(top: 10, bottom: 100),
                          itemCount: _friends.length,
                          itemBuilder: (context, index) {
                            return _buildFriendRow(_friends[index], index);
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // 4. Large Camera FAB (Snapchat style)
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onCameraTap,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.transparent, // Outline style
                  ),
                  child: Center(
                    child: Container(
                       width: 68, height: 68,
                       decoration: const BoxDecoration(
                         shape: BoxShape.circle,
                         color: Colors.white24, // Slight fill
                       ),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05), duration: 2.seconds),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // User Avatar (Left)
          GestureDetector(
            onTap: _openProfileSetup,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
              child: const Icon(LucideIcons.user, color: Colors.white, size: 20),
            ),
          ),
          
          // Title
          const Text(
            'Friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          
          // Add Friend (Right)
          GestureDetector(
            onTap: _showSearchSheet,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.userPlus, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRow(Friend friend, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Open Snap logic
          HapticFeedback.lightImpact();
          final snap = _latestSnaps[friend.username];
          
          if (snap != null) {
            // Open Snap
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => _SnapViewerScreen(snap: snap)),
            );
            
            // Mark as opened
            FriendService.instance.updateFriendStatus(friend.username, FriendStatus.opened).then((_) {
               _refreshFriends();
            });
          } else {
            // Chat or Empty
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No new snaps from ${friend.displayName}')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _getAvatarColor(friend.username),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Center(
                  child: Text(
                    friend.username.isNotEmpty 
                        ? friend.username.characters.first.toUpperCase() 
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Name & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName.isNotEmpty ? friend.displayName : '@${friend.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _getStatusIcon(friend.status),
                        const SizedBox(width: 8),
                        Text(
                          _getStatusText(friend.status, friend.lastInteraction ?? friend.addedAt),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Quick Action (Camera/Chat)
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.camera, color: Colors.white54, size: 20),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.messageCircle, color: Colors.white54, size: 20),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _getStatusIcon(FriendStatus status) {
    switch (status) {
      case FriendStatus.newSnap:
        return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: _snapRed,
            borderRadius: BorderRadius.circular(2),
            boxShadow: const [BoxShadow(color: _snapRed, blurRadius: 4)],
          ),
        );
      case FriendStatus.opened: // Hollow red square
         return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            border: Border.all(color: _snapRed, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case FriendStatus.newChat:
        return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
             color: _snapBlue,
             borderRadius: BorderRadius.circular(6), // Circle
             boxShadow: const [BoxShadow(color: _snapBlue, blurRadius: 4)],
          ),
        );
      default: // Added / Sent (Grey arrow)
        return Icon(LucideIcons.send, size: 12, color: Colors.grey[400]);
    }
  }

  String _getStatusText(FriendStatus status, DateTime time) {
    final timeStr = _formatTime(time);
    switch (status) {
      case FriendStatus.newSnap: return "New Snap • $timeStr";
      case FriendStatus.opened: return "Opened • $timeStr";
      case FriendStatus.newChat: return "New Chat • $timeStr";
      case FriendStatus.sent: return "Delivered • $timeStr";
      case FriendStatus.added: return "Added • $timeStr";
    }
  }

  Color _getAvatarColor(String seed) {
    final colors = [
      Colors.pink[400]!,
      Colors.purple[400]!, 
      Colors.blue[400]!,
      Colors.teal[400]!,
      Colors.orange[400]!,
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.users, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
             "No friends yet",
             style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _showSearchSheet, 
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Find Friends"),
          ),
        ],
      ),
    );
  }

  // ========== ACTIONS & SEARCH ==========

  void _onCameraTap() async {
    HapticFeedback.mediumImpact();
    // Simplified Camera Action for now
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📸 Take Snap (Coming Soon)')));
  }

  void _openProfileSetup() async {
    // Check if user already has a profile
    final prefs = await SharedPreferences.getInstance();
    final existingUsername = prefs.getString('username');
    final existingDisplayName = prefs.getString('displayName') ?? prefs.getString('nickname');
    
    if (existingUsername != null && existingUsername.isNotEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile: @$existingUsername')));
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
      );
      if (result != null && mounted) {
        setState(() {}); // Force rebuild
      }
    }
  }

  void _showSearchSheet() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF121212),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)),
              ),
              
              // Search Input
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Find friends...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (query) => _performSearch(query, setSheetState),
                ),
              ),
              
              // Results List
              Expanded(
                 child: _isSearching 
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                           final user = _searchResults[index];
                           final username = user['username'] ?? '';
                           final isAdded = FriendService.instance.isFriend(username);
                           
                           return ListTile(
                             leading: CircleAvatar(
                               backgroundColor: _getAvatarColor(username),
                               child: Text(username.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white)),
                             ),
                             title: Text('@$username', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             trailing: isAdded
                               ? const Icon(LucideIcons.check, color: Colors.green)
                               : ElevatedButton(
                                   onPressed: () {
                                      _addFriend(user);
                                      setSheetState((){}); // Refresh UI
                                   },
                                   style: ElevatedButton.styleFrom(
                                     backgroundColor: Colors.white,
                                     foregroundColor: Colors.black,
                                     padding: const EdgeInsets.symmetric(horizontal: 16),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                   ),
                                   child: const Text("Add"),
                                 ),
                           );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performSearch(String query, Function setSheetState) async {
    if (query.length < 2) {
      setSheetState(() => _searchResults = []);
      return;
    }
    
    setSheetState(() => _isSearching = true);
    
    try {
      final results = await SnapService.instance.searchUsername(query);
      if (mounted) {
        setSheetState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      setSheetState(() => _isSearching = false);
    }
  }

  void _addFriend(Map<String, String> user) async {
    HapticFeedback.mediumImpact();
    await FriendService.instance.addFriend(user);
    _refreshFriends(); // Update main list
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Added @${user['username']}"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

/// Simple Snap Viewer Screen
class _SnapViewerScreen extends StatelessWidget {
  final Snap snap;
  
  const _SnapViewerScreen({required this.snap});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Display snap content (image or placeholder)
            if (snap.contentType.startsWith('image/'))
              Image.memory(
                snap.content,
                fit: BoxFit.contain,
              )
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    String.fromCharCodes(snap.content),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            
            // Top bar with sender info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[700],
                        child: Text(
                          snap.senderAlias.isNotEmpty 
                              ? snap.senderAlias[0].toUpperCase() 
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        snap.senderAlias,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Tap to close hint
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Tap to close',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
