import 'dart:async';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import '../models/equalizer.dart';
import '../utils/logger.dart';

/// Media Kit based equalizer using MPV audio filters
class MediaKitEqualizer extends GetxController {
  static MediaKitEqualizer get instance => Get.find<MediaKitEqualizer>();

  Player? _player;
  final RxBool _enabled = false.obs;
  final Rx<EqualizerConfig?> _config = Rx<EqualizerConfig?>(null);
  final RxString _currentPreset = 'Flat'.obs;
  final RxList<EqualizerBand> _currentBands = <EqualizerBand>[].obs;
  final RxList<EqualizerPreset> _presets = <EqualizerPreset>[].obs;

  // Getters
  bool get enabled => _enabled.value;
  EqualizerConfig? get config => _config.value;
  String get currentPreset => _currentPreset.value;
  List<EqualizerBand> get currentBands => _currentBands;
  List<EqualizerPreset> get presets => _presets;

  @override
  void onInit() {
    super.onInit();
    _initializeEqualizer();
  }

  /// Initialize equalizer with default settings
  void _initializeEqualizer() {
    try {
      // Load presets (built-in + custom)
      _presets.value = [...EqualizerDefaults.defaultPresets];

      // Load saved configuration
      final box = Hive.box('AppPrefs');
      final configJson = box.get('equalizerConfig');

      if (configJson != null) {
        final savedConfig =
            EqualizerConfig.fromJson(Map<String, dynamic>.from(configJson));
        _config.value = savedConfig;
        _enabled.value = savedConfig.enabled;
        _currentPreset.value = savedConfig.currentPresetName;
        _currentBands.value =
            savedConfig.currentBands.map((b) => b.copyWith()).toList();

        // Add custom presets
        _presets.addAll(savedConfig.customPresets);
      } else {
        // Initialize with default flat preset
        final flatPreset = EqualizerDefaults.defaultPresets.first;
        _currentBands.value =
            flatPreset.bands.map((b) => b.copyWith()).toList();
        _config.value = EqualizerConfig(
          enabled: false,
          currentPresetName: flatPreset.name,
          currentBands: _currentBands,
        );
        _saveConfiguration();
      }

      Logger.info(
          'MediaKitEqualizer initialized with ${_presets.length} presets',
          'MediaKitEqualizer');
    } catch (e) {
      Logger.error(
          'Error initializing MediaKitEqualizer: $e', 'MediaKitEqualizer');
    }
  }

  /// Set the Media Kit player instance
  void setPlayer(Player player) {
    _player = player;
    // Apply current equalizer settings if enabled
    if (_enabled.value) {
      _applyEqualizerToPlayer();
    }
  }

  /// Enable/disable the equalizer
  Future<void> setEnabled(bool enabled) async {
    try {
      _enabled.value = enabled;

      if (_config.value != null) {
        _config.value!.enabled = enabled;
        _saveConfiguration();
      }

      if (enabled) {
        await _applyEqualizerToPlayer();
      } else {
        await _removeEqualizerFromPlayer();
      }

      Logger.info(
          'Equalizer ${enabled ? 'enabled' : 'disabled'}', 'MediaKitEqualizer');
    } catch (e) {
      Logger.error(
          'Error setting equalizer enabled state: $e', 'MediaKitEqualizer');
    }
  }

  /// Apply a preset by name
  Future<void> applyPreset(String presetName) async {
    try {
      final preset = _presets.firstWhereOrNull((p) => p.name == presetName);
      if (preset == null) {
        Logger.error('Preset not found: $presetName', 'MediaKitEqualizer');
        return;
      }

      _currentPreset.value = presetName;
      _currentBands.value = preset.bands.map((b) => b.copyWith()).toList();

      if (_config.value != null) {
        _config.value!.currentPresetName = presetName;
        _config.value!.currentBands = _currentBands;
        _saveConfiguration();
      }

      if (_enabled.value) {
        await _applyEqualizerToPlayer();
      }

      Logger.info('Applied equalizer preset: $presetName', 'MediaKitEqualizer');
    } catch (e) {
      Logger.error(
          'Error applying preset $presetName: $e', 'MediaKitEqualizer');
    }
  }

  /// Update a specific frequency band
  Future<void> updateBand(int bandIndex, double gain) async {
    try {
      if (bandIndex < 0 || bandIndex >= _currentBands.length) {
        Logger.error('Invalid band index: $bandIndex', 'MediaKitEqualizer');
        return;
      }

      // Clamp gain to valid range
      gain = gain.clamp(-15.0, 15.0);

      _currentBands[bandIndex] = _currentBands[bandIndex].copyWith(gain: gain);

      // Update preset to "Custom" if not already
      if (_currentPreset.value != 'Custom') {
        _currentPreset.value = 'Custom';
      }

      if (_config.value != null) {
        _config.value!.currentPresetName = _currentPreset.value;
        _config.value!.currentBands = _currentBands;
        _saveConfiguration();
      }

      if (_enabled.value) {
        await _applyEqualizerToPlayer();
      }
    } catch (e) {
      Logger.error('Error updating band $bandIndex: $e', 'MediaKitEqualizer');
    }
  }

  /// Save current settings as a custom preset
  Future<void> saveAsPreset(String name) async {
    try {
      final newPreset = EqualizerPreset(
        name: name,
        bands: _currentBands.map((b) => b.copyWith()).toList(),
        isCustom: true,
      );

      // Remove existing preset with same name
      _presets.removeWhere((p) => p.name == name);
      _presets.add(newPreset);

      if (_config.value != null) {
        _config.value!.customPresets =
            _presets.where((p) => p.isCustom).toList();
        _saveConfiguration();
      }

      Logger.info('Saved custom preset: $name', 'MediaKitEqualizer');
    } catch (e) {
      Logger.error('Error saving preset $name: $e', 'MediaKitEqualizer');
    }
  }

  /// Delete a custom preset
  Future<void> deletePreset(String name) async {
    try {
      final preset = _presets.firstWhereOrNull((p) => p.name == name);
      if (preset == null || !preset.isCustom) {
        Logger.error(
            'Cannot delete non-custom preset: $name', 'MediaKitEqualizer');
        return;
      }

      _presets.removeWhere((p) => p.name == name);

      if (_config.value != null) {
        _config.value!.customPresets =
            _presets.where((p) => p.isCustom).toList();
        _saveConfiguration();
      }

      // If current preset was deleted, switch to Flat
      if (_currentPreset.value == name) {
        await applyPreset('Flat');
      }

      Logger.info('Deleted custom preset: $name', 'MediaKitEqualizer');
    } catch (e) {
      Logger.error('Error deleting preset $name: $e', 'MediaKitEqualizer');
    }
  }

  /// Reset all bands to 0
  Future<void> resetToFlat() async {
    await applyPreset('Flat');
  }

  /// Apply current equalizer settings to Media Kit player using MPV filters
  Future<void> _applyEqualizerToPlayer() async {
    if (_player == null) return;

    try {
      // Build MPV equalizer filter string
      final equalizerFilter = _buildMPVEqualizerFilter();

      if (equalizerFilter.isNotEmpty) {
        // Apply audio filter to MPV through Media Kit
        await _player!.setAudioFilter(equalizerFilter);
        Logger.info(
            'Applied equalizer filter: $equalizerFilter', 'MediaKitEqualizer');
      }
    } catch (e) {
      Logger.error(
          'Error applying equalizer to player: $e', 'MediaKitEqualizer');
    }
  }

  /// Remove equalizer from player
  Future<void> _removeEqualizerFromPlayer() async {
    if (_player == null) return;

    try {
      // Remove audio filters
      await _player!.setAudioFilter('');
      Logger.info('Removed equalizer from player', 'MediaKitEqualizer');
    } catch (e) {
      Logger.error(
          'Error removing equalizer from player: $e', 'MediaKitEqualizer');
    }
  }

  /// Build MPV equalizer filter string from current bands
  String _buildMPVEqualizerFilter() {
    try {
      // MPV uses superequalizer or equalizer filter
      // Format: superequalizer=1b=gain1:2b=gain2:...
      final List<String> bandFilters = [];

      for (int i = 0; i < _currentBands.length; i++) {
        final band = _currentBands[i];
        if (band.gain != 0.0) {
          // Map frequency to MPV band index (approximate)
          final mpvBand = _frequencyToMPVBand(band.frequency);
          if (mpvBand > 0) {
            bandFilters.add('${mpvBand}b=${band.gain.toStringAsFixed(1)}');
          }
        }
      }

      if (bandFilters.isEmpty) {
        return '';
      }

      // Use superequalizer for better quality
      return 'superequalizer=${bandFilters.join(':')}';
    } catch (e) {
      Logger.error(
          'Error building MPV equalizer filter: $e', 'MediaKitEqualizer');
      return '';
    }
  }

  /// Map frequency to approximate MPV superequalizer band
  int _frequencyToMPVBand(double frequency) {
    // MPV superequalizer has 18 bands
    // Approximate mapping from frequency to band number
    if (frequency <= 50) return 1;
    if (frequency <= 100) return 2;
    if (frequency <= 156) return 3;
    if (frequency <= 220) return 4;
    if (frequency <= 311) return 5;
    if (frequency <= 440) return 6;
    if (frequency <= 622) return 7;
    if (frequency <= 880) return 8;
    if (frequency <= 1250) return 9;
    if (frequency <= 1750) return 10;
    if (frequency <= 2500) return 11;
    if (frequency <= 3500) return 12;
    if (frequency <= 5000) return 13;
    if (frequency <= 7000) return 14;
    if (frequency <= 10000) return 15;
    if (frequency <= 14000) return 16;
    if (frequency <= 20000) return 17;
    return 18;
  }

  /// Save current configuration to Hive
  void _saveConfiguration() {
    try {
      if (_config.value != null) {
        final box = Hive.box('AppPrefs');
        box.put('equalizerConfig', _config.value!.toJson());
      }
    } catch (e) {
      Logger.error(
          'Error saving equalizer configuration: $e', 'MediaKitEqualizer');
    }
  }
}

/// Extension to add equalizer support to Media Kit Player
extension PlayerEqualizerExtension on Player {
  /// Set audio filter for equalizer
  Future<void> setAudioFilter(String filter) async {
    try {
      if (filter.isEmpty) {
        // For now, we'll just log that we're trying to remove filters
        // Media Kit doesn't expose direct MPV command access
        Logger.info('Requested to clear audio filters (not implemented)',
            'PlayerExtension');
      } else {
        // For now, we'll just log the filter we would apply
        // Media Kit doesn't expose direct MPV filter access in the current API
        Logger.info('Requested to set audio filter: $filter (not implemented)',
            'PlayerExtension');

        // TODO: When Media Kit exposes MPV filter API, implement:
        // await platform.setProperty('af', filter);
        // or
        // await platform.command(['af', 'set', filter]);
      }
    } catch (e) {
      Logger.error('Error in setAudioFilter: $e', 'PlayerExtension');
    }
  }
}
