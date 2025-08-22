import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_https/ffmpeg_kit.dart';
import 'package:hive/hive.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '/utils/helper.dart';
import '/services/stream_service.dart';

class KeyDetectionResult {
  final String key; // e.g., "C", "G#", "A minor"
  final double confidence; // 0..1
  const KeyDetectionResult(this.key, this.confidence);
}

class _ChromaBands {
  final List<double> full; // length 12, probability-normalized
  final List<double> bass; // length 12, probability-normalized (low octaves)
  _ChromaBands({required this.full, required this.bass});
}

class KeyDetectionService {
  static final Random _rng = Random();
  // Cancellation flag for in-flight detections
  static bool _cancelRequested = false;
  // Per-segment analysis length (seconds)
  static const double _segmentLengthSec = 10.0;

  // 12-TET pitch class labels
  static const List<String> _notes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  // Krumhansl-Schmuckler key profiles (normalized rough values)
  static const List<double> _majorProfile = [
    6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88
  ];
  static const List<double> _minorProfile = [
    6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17
  ];

  // Approximate Mixolydian profile (heuristic):
  // Emphasizes tonic (0), dominant (7), subdominant (5), mediant/second/sixth,
  // raises weight on b7 (10) and suppresses leading tone (11).
  // Values loosely based on Krumhansl major, adapted for modal center.
  static const List<double> _mixolydianProfile = [
    6.35, // 0: tonic
    2.40, // 1: b2
    3.40, // 2: 2
    2.10, // 3: b3
    4.10, // 4: 3
    4.40, // 5: 4
    2.40, // 6: b5
    5.19, // 7: 5
    2.40, // 8: b6
    3.70, // 9: 6
    3.60, // 10: b7 (elevated vs major)
    1.20, // 11: 7 (suppressed vs major)
  ];

  // Public API: detect key using 3 random 10s segments.
  static Future<KeyDetectionResult?> detectKey({
    required String urlOrPath,
    required Duration totalDuration,
    String? mediaId,
  }) async {
    try {
      // reset cancellation for this run
      _cancelRequested = false;
      final tmpDir = await getTemporaryDirectory();
      final double totalSec = totalDuration.inSeconds.toDouble();
      final bool shortTrack = totalSec < 60.0;

      // Resolve to the same direct HTTPS stream URL the app uses, if given a YT ID/URL.
      final String sourceUrl = await _resolvePlayableUrl(urlOrPath);

      // Manual override takes precedence if present
      if (mediaId != null) {
        final override = await getOverride(mediaId);
        if (override != null && override.isNotEmpty) {
          printINFO('Using manual key override for $mediaId: $override');
          return KeyDetectionResult(override, 1.0);
        }
      }

      // Build 3 x 10s segments centered around ~47.5s, with +/- 20s offsets to capture context.
      // For very short tracks, fall back to distributed windows picked by _pickWindows().
      double anchor = 47.5; // seconds
      List<double> starts;
      if (totalSec <= (_segmentLengthSec * 3) + 5) {
        // short track: pick up to 3 distributed windows
        starts = _pickWindows(totalSec, windows: 3, winSec: _segmentLengthSec)
            .map((s) => max(0.0, min(totalSec - _segmentLengthSec, s)))
            .toList();
      } else {
        final centers = <double>[anchor - 20.0, anchor, anchor + 20.0];
        starts = centers
            .map((c) => c - (_segmentLengthSec * 0.5))
            .map((s) => max(0.0, min(totalSec - _segmentLengthSec, s)))
            .toSet() // dedupe if clamps collide
            .toList()
          ..sort();
      }
      printINFO('Multi-segment starts: ${starts.map((s) => s.toStringAsFixed(2)).join(', ')} (len=${_segmentLengthSec.toStringAsFixed(1)}s)');
      final List<_ChromaBands> chromas = [];
      for (int i = 0; i < starts.length; i++) {
        if (_cancelRequested) return null;
        final start = starts[i];
        final outPath = '${tmpDir.path}/hm_key_${DateTime.now().millisecondsSinceEpoch}_$i.wav';
        final ok = await _extractWav(sourceUrl, start, _segmentLengthSec, outPath);
        if (!ok) continue;
        if (_cancelRequested) {
          try { File(outPath).deleteSync(); } catch (_) {}
          return null;
        }
        final chroma = await _chromaFromWav(outPath);
        if (chroma != null) chromas.add(chroma);
        // cleanup
        try { File(outPath).deleteSync(); } catch (_) {}
      }

      if (chromas.isEmpty) return null;

      // Median chroma across segments (more robust to sections with strong 5ths)
      final avg = List<double>.filled(12, 0.0);
      final avgBass = List<double>.filled(12, 0.0);
      for (int i = 0; i < 12; i++) {
        final fullCol = <double>[];
        final bassCol = <double>[];
        for (final c in chromas) {
          fullCol.add(c.full[i]);
          bassCol.add(c.bass[i]);
        }
        avg[i] = _median(fullCol);
        avgBass[i] = _median(bassCol);
      }

      // Probability-normalized chroma (for tonic/dominant heuristics)
      final avgSum = avg.fold(0.0, (a, b) => a + b) + 1e-12;
      final prob = [
        for (int i = 0; i < 12; i++) avg[i] / avgSum
      ];
      final avgBassSum = avgBass.fold(0.0, (a, b) => a + b) + 1e-12;
      final bassProb = [
        for (int i = 0; i < 12; i++) avgBass[i] / avgBassSum
      ];

      // Debug: print top-3 peaks in full and bass chroma
      List<int> _topK(List<double> v, int k) {
        final idx = List<int>.generate(12, (i) => i);
        idx.sort((a, b) => v[b].compareTo(v[a]));
        return idx.take(k).toList();
      }
      final topFull = _topK(prob, 3);
      final topBass = _topK(bassProb, 3);
      printINFO('Chroma peaks (full): ' +
          topFull.map((i) => '${_notes[i]}=${prob[i].toStringAsFixed(2)}').join(', '));
      printINFO('Chroma peaks (bass): ' +
          topBass.map((i) => '${_notes[i]}=${bassProb[i].toStringAsFixed(2)}').join(', '));

      // Determine best key across Major, Minor, and Mixolydian, allowing rotations
      final major = _bestKey(avg, prob, bassProb, _majorProfile, isMinor: false, debug: true, modeName: 'Major'); // (idx, score, name)
      final minor = _bestKey(avg, prob, bassProb, _minorProfile, isMinor: true, debug: true, modeName: 'Minor');
      final mix   = _bestKey(avg, prob, bassProb, _mixolydianProfile, isMinor: false, debug: true, modeName: 'Mixolydian');

      // Compare scores
      (int, double, String) best = major;
      String mode = 'Major';
      if (minor.$2 > best.$2) { best = minor; mode = 'Minor'; }
      if (mix.$2 > best.$2)   { best = mix;   mode = 'Mixolydian'; }

      // Strong tie-breaker: if both full and bass chroma agree on the same peak with decent margins,
      // force that pitch class as tonic (favor Major) to avoid dominant/profile confusions.
      final int peakFull = topFull.first;
      final int peakBass = topBass.first;
      if (peakFull == peakBass) {
        // second best margins
        double secondFull = topFull.length > 1 ? prob[topFull[1]] : 0.0;
        double secondBass = topBass.length > 1 ? bassProb[topBass[1]] : 0.0;
        final double gapFull = (prob[peakFull] - secondFull);
        final double gapBass = (bassProb[peakBass] - secondBass);
        // Tighten criteria: require decent gaps and avoid semitone near-ties around the peak; only force if profile confidence is modest
        final double leftNeighbor = prob[(peakFull + 11) % 12];
        final double rightNeighbor = prob[(peakFull + 1) % 12];
        final bool semitoneNearTie = max(leftNeighbor, rightNeighbor) > (prob[peakFull] - 0.02);
        final bool gapsOk = gapFull >= 0.08 && gapBass >= 0.05;
        final bool profileLowConf = best.$2 < 0.80;
        if (!gapsOk || semitoneNearTie || !profileLowConf) {
          printINFO('Block forcing: gapsOk=$gapsOk (full=${gapFull.toStringAsFixed(2)}, bass=${gapBass.toStringAsFixed(2)}), semitoneNearTie=$semitoneNearTie, profileConf=${best.$2.toStringAsFixed(2)}');
        } else if (best.$1 != peakFull) {
          final forcedNote = _notes[peakFull];
          // Pick mode: if b7 notably stronger than leading tone, use Mixolydian; otherwise Major
          final int b7Idx = (peakFull + 10) % 12;
          final int leadingIdx = (peakFull + 11) % 12; // semitone below tonic in major
          final bool mixoFavored = prob[b7Idx] > prob[leadingIdx] + 0.03;
          final String forcedMode = mixoFavored ? 'Mixolydian' : 'Major';
          final conf = (gapFull + gapBass).clamp(0.0, 1.0);
          printINFO('Forcing tonic by full+bass agreement: $forcedNote $forcedMode (gaps full=${gapFull.toStringAsFixed(2)}, bass=${gapBass.toStringAsFixed(2)}) (prev ${_notes[best.$1]} $mode)');
          best = (peakFull, conf, forcedNote);
          mode = forcedMode;
        }
      }

      // Final tonic tie-breaker: if the global full-chroma peak clearly dominates and is not weaker than its fifth in bass,
      // promote that pitch class as the tonic (favoring Major label), overriding profile picks.
      int globalIdx = 0;
      for (int i = 1; i < 12; i++) { if (prob[i] > prob[globalIdx]) globalIdx = i; }
      final int globalFifth = (globalIdx + 7) % 12;
      final double domMarginFull = prob[globalIdx] - prob[globalFifth];
      final double domMarginBass = bassProb[globalIdx] - bassProb[globalFifth];
      final double secondBest = [
        for (int i = 0; i < 12; i++) if (i != globalIdx) prob[i]
      ].reduce((a, b) => a > b ? a : b);
      final double peakGap = prob[globalIdx] - secondBest;
      // Be a bit more permissive: smaller peak gap and slight tolerance on bass margin
      final bool clearlyDominant = peakGap > 0.06 && domMarginFull > 0.03 && domMarginBass > -0.05;
      if (clearlyDominant && best.$1 != globalIdx) {
        final String forced = _notes[globalIdx];
        final double relConf = (peakGap + max(0.0, domMarginFull) + max(0.0, domMarginBass)).clamp(0.0, 1.0);
        printINFO('Forcing tonic by global-peak dominance: $forced (prev ${_notes[best.$1]} $mode)');
        best = (globalIdx, relConf, forced);
        mode = 'Major';
      }

      // Label formatting
      String label;
      if (mode == 'Minor') {
        label = best.$3; // already '<Note> minor'
      } else if (mode == 'Mixolydian') {
        label = '${_notes[best.$1]} Mixolydian';
      } else {
        label = _notes[best.$1]; // Major
      }
      final conf = best.$2;
      printINFO('Detected key: $label (conf=${conf.toStringAsFixed(2)})');
      return KeyDetectionResult(label, conf.clamp(0, 1));
    } catch (e) {
      printINFO('Key detection failed: $e');
      return null;
    }
  }

  // Allow external callers to cancel current detection & ffmpeg sessions.
  static void cancelOngoing() {
    _cancelRequested = true;
    try {
      FFmpegKit.cancel();
    } catch (_) {}
  }

  // Compute best correlation over 12 rotations of profile
  // Returns (index, score 0..1 approx, label)
  static (int, double, String) _bestKey(
    List<double> chroma,
    List<double> probChroma,
    List<double> bassProbChroma,
    List<double> profile, {
    required bool isMinor,
    bool debug = false,
    String modeName = '',
  }) {
    // normalize vectors (z-score) for correlation
    final c = _normalize(chroma);
    final p = _normalize(profile);
    double bestScore = -1e9;
    int bestIdx = 0;
    final cand = <(int, double)>[];
    double minScore = 1e9;
    double maxScore = -1e9;
    // Global peak and its index
    int maxIdx = 0;
    for (int i = 1; i < 12; i++) {
      if (probChroma[i] > probChroma[maxIdx]) maxIdx = i;
    }
    final double maxProb = probChroma[maxIdx];
    // Precompute global top-3 peaks for presence checks
    final fullIdx = List<int>.generate(12, (i) => i)..sort((a, b) => probChroma[b].compareTo(probChroma[a]));
    final bassIdx = List<int>.generate(12, (i) => i)..sort((a, b) => bassProbChroma[b].compareTo(bassProbChroma[a]));
    final top3Full = fullIdx.take(3).toList();
    final top3Bass = bassIdx.take(3).toList();

    for (int shift = 0; shift < 12; shift++) {
      double dot = 0.0;
      for (int i = 0; i < 12; i++) {
        dot += c[i] * p[(i + shift) % 12];
      }
      // Heuristics to discourage dominant (5th) mis-centering and encourage stable tonic
      final tonicIdx = shift % 12;
      final fifthIdx = (shift + 7) % 12;
      final b7Idx = (shift + 10) % 12; // Mixolydian characteristic
      final leftIdx = (tonicIdx + 11) % 12; // semitone below tonic
      final rightIdx = (tonicIdx + 1) % 12; // semitone above tonic
      final tonic = probChroma[tonicIdx];
      final fifth = probChroma[fifthIdx];
      final neighbors = 0.5 * (probChroma[leftIdx] + probChroma[rightIdx]);

      // If the 5th is notably stronger than the tonic, penalize more.
      // Helps avoid choosing the dominant as the key center.
      final double dominantPenalty = max(0.0, fifth - 0.9 * tonic) * 0.28;
      // If tonic stands out vs immediate neighbors, add a stronger bonus.
      final double tonicBonus = max(0.0, tonic - neighbors) * 0.24;

      // Global-peak awareness: penalize candidates whose tonic is far below the max chroma peak
      final double tonicGapPenalty = max(0.0, 0.90 * maxProb - tonic) * 0.45;

      // Reward when global maximum aligns with candidate tonic.
      final double tonicGlobalBonus = (maxIdx == tonicIdx) ? 0.40 * (tonic / (maxProb + 1e-12)) : 0.0;
      // Penalize when global maximum aligns with candidate fifth (dominant) and tonic isn't global.
      final double dominantGlobalPenalty = (maxIdx == fifthIdx && maxIdx != tonicIdx) ? 0.35 * (fifth / (maxProb + 1e-12)) : 0.0;

      // Bass-aware adjustment: prefer keys where the tonic is not weaker than the fifth in bass
      final bassTonic = bassProbChroma[tonicIdx];
      final bassFifth = bassProbChroma[fifthIdx];
      final double bassBonus = max(0.0, bassTonic - bassFifth) * 0.35;
      final double bassPenalty = max(0.0, bassFifth - bassTonic) * 0.18;

      // Mixolydian-specific: if b7 is the global peak and clearly stronger than tonic, downweight this mode
      double mixoPenalty = 0.0;
      if (modeName == 'Mixolydian' && maxIdx == b7Idx && (probChroma[b7Idx] > tonic + 0.08)) {
        mixoPenalty = 0.35 * ((probChroma[b7Idx] - tonic) / (probChroma[b7Idx] + 1e-12));
      }

      // Presence check: prefer candidates whose tonic appears among global top-3 peaks
      // Apply a gentle bonus if present; otherwise apply a penalty proportional to gap from the 3rd peak
      final thirdFull = probChroma[top3Full[min(2, top3Full.length - 1)]];
      final thirdBass = bassProbChroma[top3Bass[min(2, top3Bass.length - 1)]];
      final bool tonicInTopFull = top3Full.contains(tonicIdx);
      final bool tonicInTopBass = top3Bass.contains(tonicIdx);
      final double presenceBonusFull = tonicInTopFull
          ? 0.06 * max(0.0, tonic - thirdFull)
          : -0.06 * max(0.0, thirdFull - tonic);
      final double presenceBonusBass = tonicInTopBass
          ? 0.05 * max(0.0, bassProbChroma[tonicIdx] - thirdBass)
          : -0.05 * max(0.0, thirdBass - bassProbChroma[tonicIdx]);

      final score = dot
          - dominantPenalty
          - bassPenalty
          - tonicGapPenalty
          - dominantGlobalPenalty
          - mixoPenalty
          + tonicBonus
          + tonicGlobalBonus
          + bassBonus
          + presenceBonusFull
          + presenceBonusBass;
      if (score > bestScore) {
        bestScore = score;
        bestIdx = shift;
      }
      minScore = score < minScore ? score : minScore;
      maxScore = score > maxScore ? score : maxScore;
      cand.add((shift, score));
    }
    if (debug) {
      cand.sort((a, b) => b.$2.compareTo(a.$2));
      final top = cand.take(3).toList();
      // Relative 0..1 scores for readability
      final denom = (maxScore - minScore).abs() + 1e-12;
      final summary = top
          .map((e) => '${_notes[e.$1]}=${((e.$2 - minScore) / denom).clamp(0.0, 1.0).toStringAsFixed(2)}')
          .join(', ');
      printINFO('Top ${modeName.isEmpty ? '' : modeName + ' '}candidates: $summary');
    }
    final name = isMinor ? '${_notes[bestIdx]} minor' : _notes[bestIdx];
    // Relative confidence vs other candidates
    // Calibrate confidence to avoid overconfident 1.00; cap at 0.88
    final conf = (((bestScore - minScore) / ((maxScore - minScore).abs() + 1e-12)) * 0.95)
        .clamp(0.0, 0.88);
    return (bestIdx, conf, name);
  }

  static List<double> _normalize(List<double> v) {
    final mean = v.reduce((a, b) => a + b) / v.length;
    double sum2 = 0.0;
    for (final x in v) {
      sum2 += pow(x - mean, 2).toDouble();
    }
    final std = sqrt((sum2 / v.length).clamp(1e-9, double.infinity));
    return v.map((x) => (x - mean) / std).toList();
  }

  static double _median(List<double> xs) {
    if (xs.isEmpty) return 0.0;
    final s = List<double>.from(xs)..sort();
    final n = s.length;
    if (n % 2 == 1) return s[n ~/ 2];
    return 0.5 * (s[n ~/ 2 - 1] + s[n ~/ 2]);
  }

  // Choose windows between 10% and 90% of the track, spaced apart
  static List<double> _pickWindows(double totalSec, {int windows = 3, double winSec = 10.0}) {
    final List<double> res = [];
    if (totalSec <= winSec) return [0.0];
    final double minStart = max(0.0, totalSec * 0.1);
    final double maxStart = max(0.0, totalSec * 0.9 - winSec);
    while (res.length < windows) {
      final s = minStart + _rng.nextDouble() * (maxStart - minStart);
      if (res.every((e) => (e - s).abs() > winSec * 1.5)) {
        res.add(s);
      }
      if (totalSec < 60 && res.length >= 2) break;
    }
    if (res.isEmpty) res.add(0.0);
    return res;
  }

  // Use ffmpeg to extract a mono wav at 22050Hz
  static Future<bool> _extractWav(String input, double startSec, double lenSec, String outPath) async {
    // Quote URLs with special chars
    final inEsc = input.replaceAll('"', '\\"');

    // Prepare optional headers for CDNs that require Referer/Origin (e.g., YouTube/googlevideo)
    String headerOpt = '';
    try {
      final uri = Uri.tryParse(input);
      final host = uri?.host ?? '';
      if (host.contains('googlevideo.com') || host.contains('youtube.com')) {
        const hdr = 'Referer: https://www.youtube.com\r\nOrigin: https://www.youtube.com';
        headerOpt = '-headers "$hdr" ';
      }
    } catch (_) {}

    // Common robust flags for network streams
    const common =
        '-nostdin -hide_banner -loglevel info '
        // Increase read/write timeout to 30s (microseconds)
        '-rw_timeout 30000000 '
        // Allow encrypted HLS
        '-protocol_whitelist file,http,https,tcp,tls,crypto '
        // Better probing for fragmented streams
        '-analyzeduration 100M -probesize 50M '
        // Reconnect hints
        '-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 2 '
        // Generate missing PTS, ignore data streams
        '-fflags +genpts -dn '
        // Set a user agent to avoid some CDNs rejecting default
        '-user_agent "HMKeyDetector/1.0"';

    final List<String> variants;
    if (startSec <= 0.1) {
      variants = <String>[
        // No seek: read from 0 for lenSec. Most robust for streaming/DASH.
        '$common $headerOpt-i "$inEsc" -t $lenSec -vn -sn -ac 1 -ar 22050 -f wav -y "$outPath"',
        // Accurate seek after demux; better compatibility for DASH/HLS
        '$common $headerOpt-i "$inEsc" -ss $startSec -t $lenSec -vn -sn -ac 1 -ar 22050 -f wav -y "$outPath"',
        // Fast seek first (try last); may fail on some servers
        '$common $headerOpt-ss $startSec -t $lenSec -i "$inEsc" -vn -sn -ac 1 -ar 22050 -f wav -y "$outPath"',
      ];
    } else {
      variants = <String>[
        // Accurate seek after demux; better compatibility for DASH/HLS
        '$common $headerOpt-i "$inEsc" -ss $startSec -t $lenSec -vn -sn -ac 1 -ar 22050 -f wav -y "$outPath"',
        // Fast seek first (try last); may fail on some servers
        '$common $headerOpt-ss $startSec -t $lenSec -i "$inEsc" -vn -sn -ac 1 -ar 22050 -f wav -y "$outPath"',
      ];
    }

    for (final cmd in variants) {
      if (_cancelRequested) return false;
      printINFO('ffmpeg cmd: $cmd');
      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();
      final ok = rc?.isValueSuccess() == true && File(outPath).existsSync();
      if (ok) return true;
      printINFO('ffmpeg segment extraction failed: ${rc?.getValue()}');
      try {
        final logs = await session.getAllLogsAsString();
        if (logs != null && logs.isNotEmpty) {
          final excerpt = logs.length > 2000 ? logs.substring(logs.length - 2000) : logs;
          printINFO('ffmpeg logs (tail):\n$excerpt');
        }
      } catch (_) {}
    }
    return false;
  }

  // Resolve to a direct playable HTTPS URL matching the app's selection.
  static Future<String> _resolvePlayableUrl(String input) async {
    try {
      final uri = Uri.tryParse(input);
      String? videoId;
      if (uri != null && (uri.host.contains('youtube.com') || uri.host.contains('youtu.be'))) {
        // Try to extract videoId from URL
        if (uri.host.contains('youtu.be')) {
          videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        } else {
          videoId = uri.queryParameters['v'];
        }
      } else if (input.length == 11 && !input.contains('http')) {
        // Likely a bare YouTube ID
        videoId = input;
      }

      if (videoId != null && videoId.isNotEmpty) {
        final sp = await StreamProvider.fetch(videoId);
        if (sp.playable) {
          // Prefer the same selection logic as app: highestQualityAudio (itag 251 opus or 140 mp4a)
          final audio = sp.highestQualityAudio ?? sp.lowQualityAudio;
          if (audio != null) return audio.url;
        }
      }
    } catch (_) {}
    return input; // fallback to provided URL/path
  }

  // Read wav (PCM16LE) and compute a simple chroma vector using Goertzel across octaves
  static Future<_ChromaBands?> _chromaFromWav(String wavPath) async {
    final bytes = await File(wavPath).readAsBytes();
    if (bytes.length < 44) return null;

    final bd = ByteData.sublistView(bytes);
    // Minimal WAV header parse
    final channels = bd.getUint16(22, Endian.little);
    final sampleRate = bd.getUint32(24, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);

    // Find 'data' chunk
    int pos = 12;
    int dataOffset = -1;
    int dataSize = 0;
    while (pos + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final size = bd.getUint32(pos + 4, Endian.little);
      if (id == 'data') {
        dataOffset = pos + 8;
        dataSize = size;
        break;
      }
      pos += 8 + size;
    }
    if (dataOffset < 0 || dataOffset + dataSize > bytes.length) return null;

    // Read PCM16 mono (if stereo, take L channel)
    final int bytesPerSample = bitsPerSample ~/ 8;
    final int frameSize = bytesPerSample * channels;
    final int frames = dataSize ~/ frameSize;
    final pcm = Float64List(frames);
    int r = dataOffset;
    for (int i = 0; i < frames; i++) {
      // take first channel
      int sample = 0;
      if (bitsPerSample == 16) {
        sample = bd.getInt16(r, Endian.little);
      } else if (bitsPerSample == 8) {
        sample = (bd.getUint8(r) - 128) << 8;
      } else {
        // unsupported depth
        return null;
      }
      pcm[i] = sample.toDouble() / 32768.0;
      r += frameSize;
    }

    // Compute overall RMS to detect silence
    double sumSq = 0.0;
    for (int i = 0; i < pcm.length; i++) {
      final v = pcm[i];
      sumSq += v * v;
    }
    final rms = sqrt(sumSq / max(1, pcm.length));
    // If too quiet, treat as silent and skip
    if (rms < 0.003) {
      return null;
    }

    final chromaBins = List<double>.filled(12, 0.0);
    final bassBins = List<double>.filled(12, 0.0);
    // Accumulate energy via Goertzel for each pitch class across octaves
    // Reference frequency for pitch class k: f = 440 * 2^((n)/12), iterate various n
    final List<int> semitoneOffsets = List<int>.generate(12, (i) => i - 9); // align A=440 as 0 -> map after

    // analyze in windows of ~4096 samples with hop 2048
    final win = min(4096, pcm.length);
    final hop = (win / 2).floor();
    if (win < 512) return null;

    int start = 0;
    while (!_cancelRequested && start + win <= pcm.length) {
      final seg = pcm.sublist(start, start + win);
      // Hann window
      for (int i = 0; i < seg.length; i++) {
        seg[i] *= 0.5 * (1 - cos(2 * pi * i / (seg.length - 1)));
      }
      // Per-window raw bins
      final windowBins = List<double>.filled(12, 0.0);
      final windowBass = List<double>.filled(12, 0.0);
      for (int k = 0; k < 12; k++) {
        double energy = 0.0;
        double bassEnergy = 0.0;
        // sum across octaves around typical musical range
        for (int o = -3; o <= 4; o++) {
          final nFromA = semitoneOffsets[k] + o * 12;
          final f = 440.0 * pow(2.0, nFromA / 12.0);
          if (f < 20 || f > sampleRate / 2) continue;
          // Octave weighting to reduce low-end bias and extreme highs
          // Center weights around o in [-1, 2] and downweight edges
          final double w;
          if (o <= -3 || o >= 4) {
            w = 0.5;
          } else if (o == -2 || o == 3) {
            w = 0.7;
          } else if (o == -1 || o == 2) {
            w = 0.85;
          } else {
            w = 1.0; // o in {0,1}
          }
          final pwr = _goertzel(seg, sampleRate.toDouble(), f);
          energy += w * pwr;
          // Bass emphasis for lower octaves only (o <= -1)
          if (o <= -1) {
            // slightly stronger weight for the lowest two octaves
            final bw = (o <= -2) ? 1.0 : 0.8;
            bassEnergy += bw * pwr;
          }
        }
        windowBins[k] = energy;
        windowBass[k] = bassEnergy;
      }
      // Normalize per-window and accumulate
      final wsum = windowBins.fold(0.0, (a, b) => a + b) + 1e-12;
      final bsum = windowBass.fold(0.0, (a, b) => a + b) + 1e-12;
      for (int k = 0; k < 12; k++) {
        chromaBins[k] += windowBins[k] / wsum;
        bassBins[k] += windowBass[k] / bsum;
      }
      start += hop;
    }

    // Normalize to probability vectors
    final sum = chromaBins.fold(0.0, (a, b) => a + b) + 1e-12;
    final bsum = bassBins.fold(0.0, (a, b) => a + b) + 1e-12;
    final full = List<double>.generate(12, (i) => chromaBins[i] / sum);
    final bass = List<double>.generate(12, (i) => bassBins[i] / bsum);
    return _ChromaBands(full: full, bass: bass);
  }

  // -------------------- Manual Override Persistence (Hive) --------------------
  static const String _overrideBoxName = 'KeyOverrides';

  static Future<Box> _openOverrideBox() async {
    return await Hive.openBox(_overrideBoxName);
  }

  // Returns stored manual key label for mediaId, or null if none
  static Future<String?> getOverride(String mediaId) async {
    try {
      final box = await _openOverrideBox();
      final v = box.get(mediaId);
      return v is String ? v : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setOverride(String mediaId, String label) async {
    try {
      final box = await _openOverrideBox();
      await box.put(mediaId, label);
    } catch (_) {}
  }

  static Future<void> clearOverride(String mediaId) async {
    try {
      final box = await _openOverrideBox();
      await box.delete(mediaId);
    } catch (_) {}
  }

  // Goertzel power at frequency f
  static double _goertzel(List<double> x, double fs, double f) {
    final k = (0.5 + (x.length * f) / fs).floor();
    final w = (2 * pi / x.length) * k;
    final cosine = cos(w);
    final coeff = 2.0 * cosine;
    double q0 = 0.0, q1 = 0.0, q2 = 0.0;
    for (int i = 0; i < x.length; i++) {
      q0 = coeff * q1 - q2 + x[i];
      q2 = q1;
      q1 = q0;
    }
    final power = q1 * q1 + q2 * q2 - coeff * q1 * q2;
    return max(0.0, power);
  }
}
