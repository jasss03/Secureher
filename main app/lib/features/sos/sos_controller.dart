import 'package:flutter/foundation.dart';

typedef SosStartHandler =
    Future<void> Function({
      String? triggerSource,
      bool activateSirenImmediately,
    });

class SosController extends ChangeNotifier {
  SosStartHandler? _startHandler;
  VoidCallback? _openSosTab;
  bool _isActive = false;
  bool _isActivating = false;
  bool _travelAloneMode = false;

  bool get isActive => _isActive;
  bool get travelAloneMode => _travelAloneMode;

  void bindStartHandler(SosStartHandler handler) {
    _startHandler = handler;
  }

  void unbindStartHandler(SosStartHandler handler) {
    _startHandler = null;
  }

  void bindOpenSosTab(VoidCallback handler) {
    _openSosTab = handler;
  }

  Future<void> activate({
    String? triggerSource,
    bool activateSirenImmediately = true,
  }) async {
    if (_isActive || _isActivating) return;
    _isActivating = true;
    try {
      _openSosTab?.call();
      final handler = _startHandler;
      if (handler != null) {
        await handler(
          triggerSource: triggerSource,
          activateSirenImmediately: activateSirenImmediately,
        );
      }
    } finally {
      _isActivating = false;
    }
  }

  void setActive(bool active) {
    if (_isActive == active) return;
    _isActive = active;
    notifyListeners();
  }

  void setTravelAlone(bool active) {
    if (_travelAloneMode == active) return;
    _travelAloneMode = active;
    notifyListeners();
  }
}
