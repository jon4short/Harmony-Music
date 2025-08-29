import 'package:harmonic/native_bindings/andrid_utils.dart';
import 'package:jni/jni.dart';
import 'package:get/get.dart';
import 'media_kit_equalizer.dart';
import '../utils/logger.dart';

class EqualizerService {
  /// Open built-in equalizer UI (primary) or system equalizer (fallback)
  static Future<bool> openEqualizer([int? sessionId]) async {
    try {
      // For Nothing devices, prefer system equalizer due to audio conflicts
      final isNothingDevice = await _isNothingDevice();

      if (isNothingDevice) {
        Logger.info('Nothing device detected, using system equalizer',
            'EqualizerService');
        return openSystemEqualizer(sessionId ?? 0);
      }

      // First try to show built-in Media Kit equalizer
      if (Get.isRegistered<MediaKitEqualizer>()) {
        // Navigate to built-in equalizer screen
        Get.toNamed('/equalizer');
        return true;
      }

      // Fallback to system equalizer
      return openSystemEqualizer(sessionId ?? 0);
    } catch (e) {
      Logger.error('Error opening equalizer: $e', 'EqualizerService');
      return openSystemEqualizer(sessionId ?? 0);
    }
  }

  /// Open system equalizer (Android native) - Public for fallback access
  static bool openSystemEqualizer(int sessionId) {
    try {
      JObject activity = JObject.fromReference(Jni.getCurrentActivity());
      JObject context =
          JObject.fromReference(Jni.getCachedApplicationContext());
      final success = Equalizer().openEqualizer(sessionId, context, activity);
      activity.release();
      context.release();
      return success;
    } catch (e) {
      Logger.error('Error opening system equalizer: $e', 'EqualizerService');
      return false;
    }
  }

  static void initAudioEffect(int sessionId) {
    JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
    Equalizer().initAudioEffect(sessionId, context);
    context.release();
  }

  static void endAudioEffect(int sessionId) {
    JObject context = JObject.fromReference(Jni.getCachedApplicationContext());
    Equalizer().endAudioEffect(sessionId, context);
    context.release();
  }

  /// Check if device is a Nothing device
  static Future<bool> _isNothingDevice() async {
    try {
      // Check device manufacturer and model
      const manufacturer =
          String.fromEnvironment('FLUTTER_BUILD_MODEL', defaultValue: '');
      const model =
          String.fromEnvironment('FLUTTER_BUILD_BRAND', defaultValue: '');

      // Check for Nothing brand indicators
      if (manufacturer.toLowerCase().contains('nothing') ||
          model.toLowerCase().contains('nothing')) {
        return true;
      }

      // You can also check Android Build properties if needed
      return false;
    } catch (e) {
      Logger.error('Error checking device type: $e', 'EqualizerService');
      return false;
    }
  }
}
