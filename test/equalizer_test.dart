import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:harmonic/models/equalizer.dart';
import 'package:harmonic/services/media_kit_equalizer.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Simple mock for testing - no external dependency needed
class MockDirectory {
  static String get tempPath => '/tmp/test';
}

void main() {
  group('Equalizer Tests', () {
    late MediaKitEqualizer equalizer;

    setUpAll(() async {
      // Register GetX service for testing
      Get.testMode = true;

      // Mock Hive box for testing without file system
      if (!Hive.isBoxOpen('AppPrefs')) {
        try {
          await Hive.initFlutter();
          await Hive.openBox('AppPrefs');
        } catch (e) {
          // Ignore Hive initialization errors in tests
        }
      }
    });

    setUp(() {
      equalizer = MediaKitEqualizer();
      Get.put(equalizer, permanent: true);
    });

    tearDown(() {
      Get.reset();
    });

    tearDownAll(() async {
      await Hive.close();
    });

    test('Equalizer should initialize with default settings', () async {
      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      expect(equalizer.enabled, false);
      expect(equalizer.currentPreset, 'Flat');
      expect(equalizer.currentBands.length, 10);
      expect(equalizer.presets.length, greaterThan(0));
    });

    test('Equalizer should have correct default frequency bands', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final bands = equalizer.currentBands;
      expect(bands.length, 10);

      // Check some key frequencies
      expect(bands.any((b) => b.frequency == 31), true);
      expect(bands.any((b) => b.frequency == 1000), true);
      expect(bands.any((b) => b.frequency == 16000), true);

      // All bands should start with 0 gain for Flat preset
      for (final band in bands) {
        expect(band.gain, 0.0);
      }
    });

    test('Equalizer should load default presets', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final presets = equalizer.presets;
      expect(presets.length, greaterThanOrEqualTo(6));

      // Check for required presets
      final presetNames = presets.map((p) => p.name).toList();
      expect(presetNames, contains('Flat'));
      expect(presetNames, contains('Rock'));
      expect(presetNames, contains('Pop'));
      expect(presetNames, contains('Jazz'));
      expect(presetNames, contains('Classical'));
      expect(presetNames, contains('Bass Boost'));
    });

    test('Equalizer should enable/disable correctly', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      expect(equalizer.enabled, false);

      await equalizer.setEnabled(true);
      expect(equalizer.enabled, true);

      await equalizer.setEnabled(false);
      expect(equalizer.enabled, false);
    });

    test('Equalizer should apply presets correctly', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // Apply Rock preset
      await equalizer.applyPreset('Rock');
      expect(equalizer.currentPreset, 'Rock');

      // Rock preset should have bass boost
      final bassFreq =
          equalizer.currentBands.firstWhere((b) => b.frequency == 31);
      expect(bassFreq.gain, greaterThan(0));
    });

    test('Equalizer should update individual bands', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // Update first band (31 Hz)
      await equalizer.updateBand(0, 5.0);

      expect(equalizer.currentBands[0].gain, 5.0);
      expect(equalizer.currentPreset, 'Custom');
    });

    test('Equalizer should clamp gain values', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // Try to set gain beyond limits
      await equalizer.updateBand(0, 20.0);
      expect(equalizer.currentBands[0].gain, 15.0); // Should be clamped to max

      await equalizer.updateBand(0, -20.0);
      expect(equalizer.currentBands[0].gain, -15.0); // Should be clamped to min
    });

    test('Equalizer should save and load custom presets', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // Modify some bands
      await equalizer.updateBand(0, 3.0);
      await equalizer.updateBand(1, -2.0);

      // Save as custom preset
      await equalizer.saveAsPreset('My Custom');

      // Check that preset was added
      final presetNames = equalizer.presets.map((p) => p.name).toList();
      expect(presetNames, contains('My Custom'));

      // Apply flat preset to reset
      await equalizer.applyPreset('Flat');
      expect(equalizer.currentBands[0].gain, 0.0);

      // Apply custom preset
      await equalizer.applyPreset('My Custom');
      expect(equalizer.currentBands[0].gain, 3.0);
      expect(equalizer.currentBands[1].gain, -2.0);
    });

    test('Equalizer should delete custom presets', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // Create and save a custom preset
      await equalizer.updateBand(0, 5.0);
      await equalizer.saveAsPreset('Delete Me');

      var presetNames = equalizer.presets.map((p) => p.name).toList();
      expect(presetNames, contains('Delete Me'));

      // Delete the preset
      await equalizer.deletePreset('Delete Me');

      presetNames = equalizer.presets.map((p) => p.name).toList();
      expect(presetNames, isNot(contains('Delete Me')));
    });

    test('Equalizer should not delete built-in presets', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      final initialCount = equalizer.presets.length;

      // Try to delete a built-in preset
      await equalizer.deletePreset('Rock');

      // Should still be there
      expect(equalizer.presets.length, initialCount);
      final presetNames = equalizer.presets.map((p) => p.name).toList();
      expect(presetNames, contains('Rock'));
    });

    test('Equalizer should reset to flat', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      // Apply a preset with gains
      await equalizer.applyPreset('Rock');
      expect(equalizer.currentPreset, 'Rock');

      // Reset to flat
      await equalizer.resetToFlat();
      expect(equalizer.currentPreset, 'Flat');

      // All gains should be 0
      for (final band in equalizer.currentBands) {
        expect(band.gain, 0.0);
      }
    });

    test('Equalizer models should serialize/deserialize correctly', () {
      final band = EqualizerBand(frequency: 1000, label: '1 kHz', gain: 5.0);
      final json = band.toJson();
      final restored = EqualizerBand.fromJson(json);

      expect(restored.frequency, band.frequency);
      expect(restored.label, band.label);
      expect(restored.gain, band.gain);
    });
  });
}
