/// Represents an equalizer frequency band
class EqualizerBand {
  final double frequency; // Hz
  final String label; // Display label (e.g., "60 Hz", "1 kHz")
  double gain; // dB gain (-15 to +15)

  EqualizerBand({
    required this.frequency,
    required this.label,
    this.gain = 0.0,
  });

  EqualizerBand copyWith({
    double? frequency,
    String? label,
    double? gain,
  }) {
    return EqualizerBand(
      frequency: frequency ?? this.frequency,
      label: label ?? this.label,
      gain: gain ?? this.gain,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'label': label,
      'gain': gain,
    };
  }

  factory EqualizerBand.fromJson(Map<String, dynamic> json) {
    return EqualizerBand(
      frequency: json['frequency']?.toDouble() ?? 0.0,
      label: json['label'] ?? '',
      gain: json['gain']?.toDouble() ?? 0.0,
    );
  }
}

/// Represents a complete equalizer preset
class EqualizerPreset {
  final String name;
  final List<EqualizerBand> bands;
  final bool isCustom;

  EqualizerPreset({
    required this.name,
    required this.bands,
    this.isCustom = false,
  });

  EqualizerPreset copyWith({
    String? name,
    List<EqualizerBand>? bands,
    bool? isCustom,
  }) {
    return EqualizerPreset(
      name: name ?? this.name,
      bands: bands ?? this.bands.map((b) => b.copyWith()).toList(),
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bands': bands.map((b) => b.toJson()).toList(),
      'isCustom': isCustom,
    };
  }

  factory EqualizerPreset.fromJson(Map<String, dynamic> json) {
    return EqualizerPreset(
      name: json['name'] ?? '',
      bands: (json['bands'] as List?)
              ?.map((b) => EqualizerBand.fromJson(b))
              .toList() ??
          [],
      isCustom: json['isCustom'] ?? false,
    );
  }
}

/// Equalizer configuration and settings
class EqualizerConfig {
  bool enabled;
  String currentPresetName;
  List<EqualizerBand> currentBands;
  List<EqualizerPreset> customPresets;

  EqualizerConfig({
    this.enabled = false,
    this.currentPresetName = 'Flat',
    required this.currentBands,
    this.customPresets = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'currentPresetName': currentPresetName,
      'currentBands': currentBands.map((b) => b.toJson()).toList(),
      'customPresets': customPresets.map((p) => p.toJson()).toList(),
    };
  }

  factory EqualizerConfig.fromJson(Map<String, dynamic> json) {
    return EqualizerConfig(
      enabled: json['enabled'] ?? false,
      currentPresetName: json['currentPresetName'] ?? 'Flat',
      currentBands: (json['currentBands'] as List?)
              ?.map((b) => EqualizerBand.fromJson(b))
              .toList() ??
          [],
      customPresets: (json['customPresets'] as List?)
              ?.map((p) => EqualizerPreset.fromJson(p))
              .toList() ??
          [],
    );
  }
}

/// Default equalizer bands (10-band equalizer)
class EqualizerDefaults {
  static List<EqualizerBand> get defaultBands => [
        EqualizerBand(frequency: 31, label: '31 Hz'),
        EqualizerBand(frequency: 62, label: '62 Hz'),
        EqualizerBand(frequency: 125, label: '125 Hz'),
        EqualizerBand(frequency: 250, label: '250 Hz'),
        EqualizerBand(frequency: 500, label: '500 Hz'),
        EqualizerBand(frequency: 1000, label: '1 kHz'),
        EqualizerBand(frequency: 2000, label: '2 kHz'),
        EqualizerBand(frequency: 4000, label: '4 kHz'),
        EqualizerBand(frequency: 8000, label: '8 kHz'),
        EqualizerBand(frequency: 16000, label: '16 kHz'),
      ];

  static List<EqualizerPreset> get defaultPresets => [
        EqualizerPreset(name: 'Flat', bands: defaultBands),
        EqualizerPreset(
          name: 'Rock',
          bands: [
            EqualizerBand(frequency: 31, label: '31 Hz', gain: 5.0),
            EqualizerBand(frequency: 62, label: '62 Hz', gain: 3.0),
            EqualizerBand(frequency: 125, label: '125 Hz', gain: -2.0),
            EqualizerBand(frequency: 250, label: '250 Hz', gain: -3.0),
            EqualizerBand(frequency: 500, label: '500 Hz', gain: -1.0),
            EqualizerBand(frequency: 1000, label: '1 kHz', gain: 2.0),
            EqualizerBand(frequency: 2000, label: '2 kHz', gain: 4.0),
            EqualizerBand(frequency: 4000, label: '4 kHz', gain: 6.0),
            EqualizerBand(frequency: 8000, label: '8 kHz', gain: 4.0),
            EqualizerBand(frequency: 16000, label: '16 kHz', gain: 3.0),
          ],
        ),
        EqualizerPreset(
          name: 'Pop',
          bands: [
            EqualizerBand(frequency: 31, label: '31 Hz', gain: -1.0),
            EqualizerBand(frequency: 62, label: '62 Hz', gain: 2.0),
            EqualizerBand(frequency: 125, label: '125 Hz', gain: 4.0),
            EqualizerBand(frequency: 250, label: '250 Hz', gain: 4.0),
            EqualizerBand(frequency: 500, label: '500 Hz', gain: 1.0),
            EqualizerBand(frequency: 1000, label: '1 kHz', gain: -1.0),
            EqualizerBand(frequency: 2000, label: '2 kHz', gain: -1.0),
            EqualizerBand(frequency: 4000, label: '4 kHz', gain: 1.0),
            EqualizerBand(frequency: 8000, label: '8 kHz', gain: 3.0),
            EqualizerBand(frequency: 16000, label: '16 kHz', gain: 4.0),
          ],
        ),
        EqualizerPreset(
          name: 'Jazz',
          bands: [
            EqualizerBand(frequency: 31, label: '31 Hz', gain: 2.0),
            EqualizerBand(frequency: 62, label: '62 Hz', gain: 1.0),
            EqualizerBand(frequency: 125, label: '125 Hz', gain: 1.0),
            EqualizerBand(frequency: 250, label: '250 Hz', gain: 2.0),
            EqualizerBand(frequency: 500, label: '500 Hz', gain: 3.0),
            EqualizerBand(frequency: 1000, label: '1 kHz', gain: 3.0),
            EqualizerBand(frequency: 2000, label: '2 kHz', gain: 1.0),
            EqualizerBand(frequency: 4000, label: '4 kHz', gain: 1.0),
            EqualizerBand(frequency: 8000, label: '8 kHz', gain: 2.0),
            EqualizerBand(frequency: 16000, label: '16 kHz', gain: 2.0),
          ],
        ),
        EqualizerPreset(
          name: 'Classical',
          bands: [
            EqualizerBand(frequency: 31, label: '31 Hz', gain: 0.0),
            EqualizerBand(frequency: 62, label: '62 Hz', gain: 0.0),
            EqualizerBand(frequency: 125, label: '125 Hz', gain: 0.0),
            EqualizerBand(frequency: 250, label: '250 Hz', gain: 0.0),
            EqualizerBand(frequency: 500, label: '500 Hz', gain: 0.0),
            EqualizerBand(frequency: 1000, label: '1 kHz', gain: -1.0),
            EqualizerBand(frequency: 2000, label: '2 kHz', gain: -1.0),
            EqualizerBand(frequency: 4000, label: '4 kHz', gain: -1.0),
            EqualizerBand(frequency: 8000, label: '8 kHz', gain: 3.0),
            EqualizerBand(frequency: 16000, label: '16 kHz', gain: 4.0),
          ],
        ),
        EqualizerPreset(
          name: 'Bass Boost',
          bands: [
            EqualizerBand(frequency: 31, label: '31 Hz', gain: 7.0),
            EqualizerBand(frequency: 62, label: '62 Hz', gain: 6.0),
            EqualizerBand(frequency: 125, label: '125 Hz', gain: 5.0),
            EqualizerBand(frequency: 250, label: '250 Hz', gain: 3.0),
            EqualizerBand(frequency: 500, label: '500 Hz', gain: 1.0),
            EqualizerBand(frequency: 1000, label: '1 kHz', gain: 0.0),
            EqualizerBand(frequency: 2000, label: '2 kHz', gain: 0.0),
            EqualizerBand(frequency: 4000, label: '4 kHz', gain: 0.0),
            EqualizerBand(frequency: 8000, label: '8 kHz', gain: 0.0),
            EqualizerBand(frequency: 16000, label: '16 kHz', gain: 0.0),
          ],
        ),
        EqualizerPreset(
          name: 'Vocal Boost',
          bands: [
            EqualizerBand(frequency: 31, label: '31 Hz', gain: -2.0),
            EqualizerBand(frequency: 62, label: '62 Hz', gain: -3.0),
            EqualizerBand(frequency: 125, label: '125 Hz', gain: -2.0),
            EqualizerBand(frequency: 250, label: '250 Hz', gain: 1.0),
            EqualizerBand(frequency: 500, label: '500 Hz', gain: 4.0),
            EqualizerBand(frequency: 1000, label: '1 kHz', gain: 5.0),
            EqualizerBand(frequency: 2000, label: '2 kHz', gain: 4.0),
            EqualizerBand(frequency: 4000, label: '4 kHz', gain: 2.0),
            EqualizerBand(frequency: 8000, label: '8 kHz', gain: 1.0),
            EqualizerBand(frequency: 16000, label: '16 kHz', gain: 0.0),
          ],
        ),
      ];
}
