import 'base_viewmodel.dart';

class OnboardingViewModel extends BaseViewModel {
  bool _isNavigating = false;
  bool get isNavigating => _isNavigating;

  Future<void> enterMesh() async {
    setState(ViewState.busy);
    _isNavigating = true;
    
    // Simulate some initialization or permission checks
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(ViewState.idle);
    // Navigation should be handled by the View based on state or callback
  }
}
