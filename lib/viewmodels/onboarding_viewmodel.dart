import 'package:shared_preferences/shared_preferences.dart';
import 'base_viewmodel.dart';
import '../services/mesh_service.dart';

class OnboardingViewModel extends BaseViewModel {
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  Future<void> enterMesh(String nickname) async {
    setState(ViewState.busy);
    _isNavigating = true;
    
    // Set nickname in native layer
    await MeshService().setNickname(nickname);
    await MeshService().startMesh(); // Ensure mesh is started
    
    // Save nickname to SharedPreferences for profile use
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', nickname);
    // Also use as displayName if not set
    if (prefs.getString('displayName') == null) {
      await prefs.setString('displayName', nickname);
    }
    
    // Simulate some initialization or permission checks
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(ViewState.idle);
    // Navigation should be handled by the View based on state or callback
  }
}

