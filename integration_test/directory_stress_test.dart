import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bitchat/services/snap_service.dart';
import 'package:bitchat/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Directory Stress Test', (WidgetTester tester) async {
    app.main();
    await tester.pumpAndSettle();

    print("\n🚀 STARTING DIRECTORY STRESS TEST...\n");
    
    // Run the native stress test
    final report = await SnapService.instance.runDirectoryStressTest();
    
    print("\n===========================================");
    print("           STRESS TEST REPORT");
    print("===========================================");
    print(report);
    print("===========================================\n");
    
    expect(report, contains("SUCCESS"));
  });
}
