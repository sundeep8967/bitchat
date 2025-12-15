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
    
    // Simulate some initialization or permission checks
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(ViewState.idle);
    // Navigation should be handled by the View based on state or callback
  }
}
