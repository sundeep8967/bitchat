import 'base_viewmodel.dart';
import '../services/mesh_service.dart';

class OnboardingViewModel extends BaseViewModel {
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  Future<void> enterMesh() async {
    setState(ViewState.busy);
    _isNavigating = true;
    
    // Start mesh service
    await MeshService().startMesh();
    
    // Brief initialization delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(ViewState.idle);
  }
}
