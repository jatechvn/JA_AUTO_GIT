// lib/modules/native_bridge.dart
import 'dart:io' show Platform;

import 'native/win_core.dart';
import 'native/mac_core.dart';
import 'native/linux_core.dart';

abstract class NativeEngine {
  dynamic heavyCompute(dynamic dataInput);
}

class NativeBridge {
  final String osName;
  NativeEngine? engine;

  NativeBridge() : osName = Platform.operatingSystem {
    _initializeEngine();
  }

  void _initializeEngine() {
    try {
      if (Platform.isWindows) {
        engine = WindowsNativeEngine();
      } else if (Platform.isMacOS) {
        engine = MacNativeEngine();
      } else if (Platform.isLinux) {
        engine = LinuxNativeEngine();
      }
    } catch (e) {
      // Fallback to pure Dart computation
    }
  }

  dynamic executeHeavyTask(dynamic dataInput) {
    if (engine != null) {
      return engine!.heavyCompute(dataInput);
    }
    return _pureDartFallback(dataInput);
  }

  dynamic _pureDartFallback(dynamic dataInput) {
    return dataInput;
  }
}

final nativeAgent = NativeBridge();
