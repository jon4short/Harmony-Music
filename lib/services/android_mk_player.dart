import 'dart:math';

import 'package:media_kit/media_kit.dart';

/// Minimal Android-only media_kit player wrapper to enable speed & pitch.
/// Note: This is an initial integration. Background notifications &
/// playback state streams are still managed by AudioService.
class AndroidMKPlayer {
  // Enable independent pitch control (preserve tempo)
  final Player _player = Player(configuration: const PlayerConfiguration(pitch: true));

  Future<void> openUrl(String url) async {
    await _player.open(Media(url));
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setRate(double rate) => _player.setRate(rate);

  /// Apply pitch in semitones while preserving tempo.
  /// This uses mpv audio filter options. Implementation TBD.
  Future<void> setPitchSemitones(int semis) async {
    // Factor: 2^(semitones/12)
    final factor = pow(2.0, semis / 12.0).toDouble();
    // media_kit provides Player.setPitch when PlayerConfiguration.pitch is true
    await _player.setPitch(factor);
  }

  // Accessors for position/duration if needed later.
  Stream<Duration> get positionStream => _player.stream.position;
  Stream<Duration?> get durationStream => _player.stream.duration;
  Future<Duration?> get duration async => _player.state.duration;
  Future<Duration> get position async => _player.state.position;
}
