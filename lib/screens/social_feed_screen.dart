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
import 'dart:ui';


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
      backgroundColor: const Color(0xFFFAFAFA), // Very light grey/white
      body: Stack(
        children: [
          // 1. Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 70, // Space for Header
                  bottom: 100, // Space for FAB
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stories Rail
                    _buildStoriesRail(),
                    
                    const SizedBox(height: 16),
                    
                    // Persistent Search Bar (Find People)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: _showSearchSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.search, color: Colors.grey[500], size: 20),
                              const SizedBox(width: 12),
                              Text(
                                "Find people...",
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    
                    // "Messages" Label
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            "Messages",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.filter, size: 12, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text("Recent", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              
              // Friends List
              _friends.isEmpty && !_isLoading
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildFriendRow(_friends[index], index),
                        childCount: _friends.length,
                      ),
                    ),
            ],
          ),

          // 2. Glass Header
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withOpacity(0.7), // Frosted
                  child: SafeArea(child: _buildHeader()),
                ),
              ),
            ),
          ),
          
          // 3. Glass FAB (Bottom Center)
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _onCameraTap,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E75FF), Color(0xFF8C52FF)], // Blue -> Purple
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E75FF).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(LucideIcons.camera, color: Colors.white, size: 32),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile (Left)
          GestureDetector(
             onTap: _openProfileSetup,
             child: Container(
               width: 42, height: 42,
               decoration: BoxDecoration(
                 color: Colors.white,
                 shape: BoxShape.circle,
                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
               ),
               child: const Icon(LucideIcons.user, color: Colors.black87, size: 22),
             ),
          ),

          // Title (Center)
          Expanded(
            child: Center(
              child: Image.network(
                "https://cdn-icons-png.flaticon.com/512/3670/3670151.png", // Simplified logo placeholder or Text
                height: 28,
                errorBuilder: (c,e,s) => const Text(
                  "bitchat", 
                  style: TextStyle(
                    fontFamily: 'Zapfino', // Or generic cursive if unavailable, but aiming for sleek
                    fontSize: 22, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black
                  ),
                ),
              ),
            ),
          ),
          
          // Actions (Right)
          Row(
            children: [
              _buildHeaderIcon(LucideIcons.search, _showSearchSheet),
              const SizedBox(width: 12),
              _buildHeaderIcon(LucideIcons.userPlus, _showFriendRequests),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }

  Widget _buildStoriesRail() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 1 + (_friends.isEmpty ? 0 : 5), // Mock "My Story" + Top 5 friends
        itemBuilder: (context, index) {
          if (index == 0) return _buildMyStory();
          // Mock data for rail
          final fIndex = (index - 1) % _friends.length;
          return _buildStoryItem(_friends[fIndex]);
        },
      ),
    );
  }

  Widget _buildMyStory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Icon(LucideIcons.user, color: Colors.grey),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.plus, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text("My Story", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStoryItem(Friend friend) {
    final hasSnap = _latestSnaps.containsKey(friend.username);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final snap = _latestSnaps[friend.username];
        if (snap != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _SnapViewerScreen(snap: snap)));
          FriendService.instance.updateFriendStatus(friend.username, FriendStatus.opened).then((_) {
            _refreshFriends();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No new stories from ${friend.displayName}')),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasSnap 
                  ? LinearGradient(
                      colors: [Colors.purple[400]!, Colors.blue[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.grey[300]!, Colors.grey[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              ),
              child: Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                     friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              friend.username.length > 8 ? '${friend.username.substring(0,7)}...' : friend.username,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendRow(Friend friend, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 0, // Flat look
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Action
            final snap = _latestSnaps[friend.username];
            if (snap != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => _SnapViewerScreen(snap: snap)));
              FriendService.instance.updateFriendStatus(friend.username, FriendStatus.opened).then((_) {
                 _refreshFriends();
              });
            } else {
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wait for ${friend.displayName} to send a Snap!')));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _getAvatarColor(friend.username).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _getAvatarColor(friend.username),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName.isNotEmpty ? friend.displayName : '@${friend.username}',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _getStatusIcon(friend.status),
                          const SizedBox(width: 6),
                          Text(
                            _getStatusText(friend.status, friend.lastInteraction ?? friend.addedAt),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Quick Actions (Icon only)
                if (FriendService.instance.isFriend(friend.username)) ...[
                  IconButton(
                    icon: const Icon(LucideIcons.camera, size: 20, color: Colors.grey),
                    onPressed: _onCameraTap,
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.messageSquare, size: 20, color: Colors.grey),
                    onPressed: () {}, // Chat
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  // ... (Keep existing helpers like _getStatusIcon, _getStatusText, _getAvatarColor etc.)

  Widget _getStatusIcon(FriendStatus status) {
    switch (status) {
      case FriendStatus.newSnap:
        return Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: _snapRed,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case FriendStatus.opened:
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
             borderRadius: BorderRadius.circular(6), 
          ),
        );
      default:
        return Icon(LucideIcons.send, size: 14, color: Colors.grey[400]);
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
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Container(
               padding: const EdgeInsets.all(24),
               decoration: const BoxDecoration(
                 color: Color(0xFFF2F2F7),
                 shape: BoxShape.circle,
               ),
               child: Icon(LucideIcons.users, size: 48, color: Colors.grey[400]),
             ),
             const SizedBox(height: 16),
             Text(
                "No friends yet",
                style: TextStyle(color: Colors.grey[900], fontSize: 18, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 24),
             Container(
               height: 50,
               decoration: BoxDecoration(
                 gradient: const LinearGradient(
                   colors: [Color(0xFF2E75FF), Color(0xFF8C52FF)],
                 ),
                 borderRadius: BorderRadius.circular(25),
                 boxShadow: [
                   BoxShadow(
                     color: const Color(0xFF2E75FF).withOpacity(0.3),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
               child: ElevatedButton(
                 onPressed: _showSearchSheet,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.transparent,
                   shadowColor: Colors.transparent,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 32),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                 ), 
                 child: const Text("Find Friends", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
             ),
          ],
        ),
      ),
    );
  }

  // ========== ACTIONS & SEARCH ==========

  void _onCameraTap() async {
    HapticFeedback.mediumImpact();
    // 1. Pick Image (Lower quality for faster P2P mesh transfer)
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
    
    if (image != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
             SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
             SizedBox(width: 16),
             Text('Sending Snap via P2P & Internet...')
          ]),
          duration: Duration(seconds: 10),
        ),
      );

      try {
        final bytes = await image.readAsBytes();
        
        // 2. Send via Service (Both Mesh + Nostr)
        final success = await SnapService.instance.broadcastSnap(
          content: bytes,
          globalBroadcast: true, // Try Internet too
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sent! 🐘 (Mesh + Relay)"), 
              backgroundColor: Color(0xFF2E75FF),
            )
          );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to send. using offline mesh only."))
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"))
          );
      }
    }
  }

  void _showFriendRequests() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final requests = FriendService.instance.pendingRequests;
          
          return Container(
            height: 450,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 36, height: 5,
                  margin: const EdgeInsets.only(top: 8, bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Friend Requests",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (requests.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E75FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${requests.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: requests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.userPlus, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "No pending requests",
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          final username = request['username'] ?? '';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getAvatarColor(username),
                                  radius: 24,
                                  child: Text(
                                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('Wants to add you', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                    ],
                                  ),
                                ),
                                // Accept
                                IconButton(
                                  onPressed: () async {
                                    await FriendService.instance.acceptRequest(username);
                                    setSheetState(() {});
                                    _refreshFriends();
                                    HapticFeedback.lightImpact();
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2E75FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.check, color: Colors.white, size: 18),
                                  ),
                                ),
                                // Decline
                                IconButton(
                                  onPressed: () async {
                                    await FriendService.instance.declineRequest(username);
                                    setSheetState(() {});
                                    HapticFeedback.lightImpact();
                                  },
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(LucideIcons.x, color: Colors.grey[600], size: 18),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openProfileSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final existingUsername = prefs.getString('username');
    
    if (existingUsername != null && existingUsername.isNotEmpty) {
       showDialog(
         context: context,
         builder: (ctx) => AlertDialog(
           title: Text('@$existingUsername'),
           content: const Text("Profile editing coming soon."),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
           ],
         ),
       );
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
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 36, height: 5,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2.5)),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                 child: Row(
                  children: [
                    Text(
                      "Find Friends",
                      style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.black, fontSize: 17),
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (query) => _performSearch(query, setSheetState),
                  ),
                ),
              ),
              
              // Results List
              Expanded(
                 child: _isSearching 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(top: 16),
                        itemCount: _searchResults.length,
                        separatorBuilder: (c, i) => const Divider(height: 1, indent: 76, color: Color(0xFFE5E5EA)),
                        itemBuilder: (context, index) {
                           final user = _searchResults[index];
                           final username = user['username'] ?? '';
                           final isAdded = FriendService.instance.isFriend(username);
                           
                           return ListTile(
                             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                             leading: CircleAvatar(
                               backgroundColor: _getAvatarColor(username),
                               radius: 20,
                               child: Text(username.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                             ),
                             title: Text('@$username', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 17)),
                             trailing: isAdded
                               ? const Icon(LucideIcons.check, color: Colors.green)
                               : Container(
                                   height: 30,
                                   decoration: BoxDecoration(
                                     color: const Color(0xFFF2F2F7),
                                     borderRadius: BorderRadius.circular(15),
                                   ),
                                   child: ElevatedButton(
                                     onPressed: () {
                                        _addFriend(user);
                                        setSheetState((){}); 
                                     },
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: Colors.transparent,
                                       foregroundColor: Colors.black,
                                       shadowColor: Colors.transparent,
                                       padding: const EdgeInsets.symmetric(horizontal: 16),
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                     ),
                                     child: const Text("Add", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                   ),
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
