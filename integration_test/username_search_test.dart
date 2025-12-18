import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bitchat/services/snap_service.dart';

/// Integration test for NIP-50 username search functionality
/// 
/// This test verifies that the username search works correctly
/// using the NIP-50 full-text search capability with relay.nostr.band
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NIP-50 Username Search Tests', () {
    
    testWidgets('Search for common Nostr username returns results', (tester) async {
      // Initialize the app just enough to allow method channel calls
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return const Scaffold(
                body: Center(child: Text('Search Test')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Test searching for a common Nostr username
      // "jack" is the creator of Nostr and should always be found
      final results = await SnapService.instance.searchUsername('jack');
      
      print('🔍 Search for "jack" returned ${results.length} results');
      for (final result in results) {
        print('  📥 Found: ${result['username']} (${result['pubkey']?.substring(0, 16)}...)');
      }
      
      // Should find at least one user named jack
      expect(results.isNotEmpty, true, reason: 'Should find users matching "jack"');
    });
    
    testWidgets('Search for unique BitChat username', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return const Scaffold(
                body: Center(child: Text('Search Test')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Search for a unique username that may have been created
      final results = await SnapService.instance.searchUsername('emu7');
      
      print('🔍 Search for "emu7" returned ${results.length} results');
      for (final result in results) {
        print('  📥 Found: ${result['name']} (${result['pubkey']?.substring(0, 16)}...)');
      }
      
      // Log whether we found it (may or may not exist)
      if (results.isEmpty) {
        print('⚠️ No results found - username may not be published to relays yet');
      } else {
        print('✅ Found emu7!');
      }
    });
    
    testWidgets('Search for non-existent username returns empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return const Scaffold(
                body: Center(child: Text('Search Test')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      
      // Search for a username that definitely doesn't exist
      final results = await SnapService.instance.searchUsername('zzzznonexistent12345xyz');
      
      print('🔍 Search for non-existent username returned ${results.length} results');
      
      // Should find no users
      expect(results.isEmpty, true, reason: 'Should not find non-existent username');
    });
  });
}
