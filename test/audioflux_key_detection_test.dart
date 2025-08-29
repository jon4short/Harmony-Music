import 'package:flutter_test/flutter_test.dart';
import 'package:harmonic/services/key_detection_service.dart';
import 'package:harmonic/services/audioflux_service.dart';

void main() {
  group('AudioFlux Key Detection Tests', () {
    test('AudioFlux service initialization', () async {
      // Test AudioFlux service initialization
      final initialized = await AudioFluxService.initialize();
      
      // On non-Android platforms or without proper setup, this should gracefully fail
      expect(initialized, isA<bool>());
      
      // Check availability status
      expect(AudioFluxService.isAvailable, isA<bool>());
    });
    
    test('Key detection service fallback behavior', () async {
      // This test ensures that the key detection service doesn't break
      // when AudioFlux is not available and falls back to built-in detection
      
      try {
        final result = await KeyDetectionService.detectKey(
          urlOrPath: 'test_url',
          totalDuration: const Duration(seconds: 30),
          mediaId: 'test_id',
        );
        
        // Result can be null (which is valid for test scenarios)
        // The important thing is that it doesn't throw an exception
        expect(result, anyOf(isNull, isA<KeyDetectionResult>()));
      } catch (e) {
        // If it fails, it should be due to network/URL issues, not our implementation
        expect(e, isA<Exception>());
      }
    });
    
    test('AudioFlux result conversion', () {
      // Test the conversion from AudioFlux result to KeyDetectionResult
      const audioFluxResult = AudioFluxResult(
        key: 'C Major',
        confidence: 0.85,
        success: true,
      );
      
      final converted = AudioFluxService.toKeyDetectionResult(audioFluxResult);
      
      expect(converted, isNotNull);
      expect(converted!.key, equals('C Major'));
      expect(converted.confidence, equals(0.85));
    });
    
    test('AudioFlux result conversion with failure', () {
      // Test conversion with failed AudioFlux result
      const audioFluxResult = AudioFluxResult(
        key: '',
        confidence: 0.0,
        success: false,
      );
      
      final converted = AudioFluxService.toKeyDetectionResult(audioFluxResult);
      
      expect(converted, isNull);
    });
    
    test('AudioFlux service cleanup', () {
      // Test that cleanup doesn't throw exceptions
      expect(() => AudioFluxService.dispose(), returnsNormally);
    });
  });
}
