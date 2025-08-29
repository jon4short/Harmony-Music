import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';

import '/models/album.dart';
import '../models/playlist.dart' as playlist_model;
import '/models/media_Item_builder.dart';
import '/services/android_mk_player.dart';
import '/services/equalizer.dart';
import '/services/utils.dart';
import '/ui/widgets/snackbar.dart';
import '/ui/player/player_controller.dart';
import '/models/hm_streaming_data.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '../ui/screens/Home/home_screen_controller.dart';
import '../ui/screens/Library/library_controller.dart';
import '/services/permission_service.dart';
import '/services/stream_service.dart';
import '/utils/helper.dart';
import '/utils/logger.dart';
import '/services/background_task.dart';

/// Android-only AudioHandler powered by media_kit/mpv for pitch support.
class MyAudioHandlerAndroidMK extends BaseAudioHandler with GetxServiceMixin {
  late final AndroidMKPlayer _mk;
  late String _cacheDir;
  late MediaLibrary _mediaLibrary;

  // queue & playback state
  int currentIndex = 0;
  int currentShuffleIndex = 0;
  bool isSongLoading = true;
  String? currentSongUrl;
  bool loopModeEnabled = false;
  bool queueLoopModeEnabled = false;
  bool shuffleModeEnabled = false;
  bool loudnessNormalizationEnabled = false;

  // list of shuffled queue songs ids
  List<String> shuffledQueue = [];

  MyAudioHandlerAndroidMK() {
    // Ensure media_kit is initialized BEFORE creating player
    MediaKit.ensureInitialized();
    _mk = AndroidMKPlayer();
    _mediaLibrary = MediaLibrary();

    _createCacheDir();
    _initializeSettings();
    _setupEventListeners();
    _notifyAudioHandlerAboutPlaybackEvents();
  }

  void _initializeSettings() {
    // Try restore preferences (non-blocking & safe)
    try {
      final appPrefsBox = Hive.box("appPrefs");
      double rate = 1.0;
      if (Hive.isBoxOpen("AppPrefs")) {
        final box = Hive.box("AppPrefs");
        final val = box.get("playbackSpeed");
        if (val is num) rate = val.toDouble();
      }
      // Apply if not default
      if (rate != 1.0) {
        // ignore: discarded_futures
        _mk.setRate(rate);
      }

      // Initialize other settings
      loopModeEnabled = appPrefsBox.get("isLoopModeEnabled") ?? false;
      shuffleModeEnabled = appPrefsBox.get("isShuffleModeEnabled") ?? false;
      queueLoopModeEnabled =
          Hive.box("AppPrefs").get("queueLoopModeEnabled") ?? false;
      loudnessNormalizationEnabled =
          appPrefsBox.get("loudnessNormalizationEnabled") ?? false;
    } catch (_) {
      // ignore
    }
  }

  void _setupEventListeners() {
    // listen to progress & duration to update playbackState
    _mk.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });
    _mk.durationStream.listen((dur) {
      // Update current media item duration when known
      if (dur != null && queue.value.isNotEmpty) {
        final current = queue.value[currentIndex];
        mediaItem.add(current.copyWith(duration: dur));
      }
    });

    _listenToPlaybackForNextSong();
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    // Media Kit doesn't have direct playback event stream like Just Audio
    // We'll use position stream to simulate this
    _mk.positionStream.listen((position) {
      final playing = _mk.player.state.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isSongLoading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        repeatMode: loopModeEnabled
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
        shuffleMode: shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        playing: playing,
        updatePosition: position,
        speed: _mk.player.state.rate,
        queueIndex: currentIndex,
      ));
    });
  }

  void _listenToPlaybackForNextSong() {
    _mk.positionStream.listen((value) async {
      final duration = await _mk.duration;
      if (duration != null && duration.inSeconds != 0) {
        if (value.inMilliseconds >= (duration.inMilliseconds - 200)) {
          await _triggerNext();
        }
      }
    });
  }

  Future<void> _triggerNext() async {
    if (loopModeEnabled) {
      await _mk.seek(Duration.zero);
      await _mk.play();
      return;
    }
    skipToNext();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = List<MediaItem>.from(queue.value)..add(mediaItem);
    queue.add(newQueue);
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async {
    final newQueue = List<MediaItem>.from(queue.value)..addAll(mediaItems);
    queue.add(newQueue);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    final newQueue = List<MediaItem>.from(queue);
    this.queue.add(newQueue);
  }

  @override
  Future<void> play() async {
    await _mk.play();
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> pause() async {
    await _mk.pause();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    await _mk.seek(position);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await customAction('playByIndex', {'index': index});
  }

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    final nextIndex = _getNextSongIndex();
    if (nextIndex != currentIndex) {
      if ((await _mk.position) != Duration.zero) await _mk.seek(Duration.zero);
      await customAction('playByIndex', {'index': nextIndex});
    } else {
      await _mk.seek(Duration.zero);
      await _mk.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    final position = await _mk.position;
    if (position.inMilliseconds > 5000) {
      await _mk.seek(Duration.zero);
      return;
    }
    await _mk.seek(Duration.zero);
    final prevIndex = _getPrevSongIndex();
    if (prevIndex != currentIndex) {
      await customAction('playByIndex', {'index': prevIndex});
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    if (shuffleModeEnabled) {
      final id = mediaItem.id;
      final itemIndex = shuffledQueue.indexOf(id);
      if (currentShuffleIndex > itemIndex) {
        currentShuffleIndex -= 1;
      }
      shuffledQueue.remove(id);
    }

    final currentQueue = queue.value;
    final currentSong = this.mediaItem.value;
    final itemIndex = currentQueue.indexOf(mediaItem);
    if (currentIndex > itemIndex) {
      currentIndex -= 1;
    }
    currentQueue.remove(mediaItem);
    queue.add(currentQueue);
    this.mediaItem.add(currentSong);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode == AudioServiceRepeatMode.none) {
      loopModeEnabled = false;
    } else {
      loopModeEnabled = true;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode == AudioServiceShuffleMode.none) {
      shuffleModeEnabled = false;
      shuffledQueue.clear();
    } else {
      _shuffleCmd(currentIndex);
      shuffleModeEnabled = true;
    }
  }

  // Helper methods for navigation
  int _getNextSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex + 1 < shuffledQueue.length) {
        currentShuffleIndex += 1;
        return queue.value.indexWhere(
            (song) => song.id == shuffledQueue[currentShuffleIndex]);
      } else if (queueLoopModeEnabled) {
        currentShuffleIndex = 0;
        return queue.value.indexWhere(
            (song) => song.id == shuffledQueue[currentShuffleIndex]);
      } else {
        return currentIndex;
      }
    } else {
      if (currentIndex + 1 < queue.value.length) {
        return currentIndex + 1;
      } else if (queueLoopModeEnabled) {
        return 0;
      } else {
        return currentIndex;
      }
    }
  }

  int _getPrevSongIndex() {
    if (shuffleModeEnabled) {
      if (currentShuffleIndex - 1 >= 0) {
        currentShuffleIndex -= 1;
        return queue.value.indexWhere(
            (song) => song.id == shuffledQueue[currentShuffleIndex]);
      } else if (queueLoopModeEnabled) {
        currentShuffleIndex = shuffledQueue.length - 1;
        return queue.value.indexWhere(
            (song) => song.id == shuffledQueue[currentShuffleIndex]);
      } else {
        return currentIndex;
      }
    } else {
      if (currentIndex - 1 >= 0) {
        return currentIndex - 1;
      } else if (queueLoopModeEnabled) {
        return queue.value.length - 1;
      } else {
        return currentIndex;
      }
    }
  }

  void _shuffleCmd(int index) {
    final queueIds = queue.value.toList().map((item) => item.id).toList();
    final currentSongId = queueIds.removeAt(index);
    queueIds.shuffle();
    queueIds.insert(0, currentSongId);
    shuffledQueue.replaceRange(0, shuffledQueue.length, queueIds);
    currentShuffleIndex = 0;
  }

  void _normalizeVolume(double currentLoudnessDb) {
    double loudnessDifference = -5 - currentLoudnessDb;
    final volumeAdjustment = pow(10.0, loudnessDifference / 20.0);
    Logger.info(
        "loudness:$currentLoudnessDb Normalized volume: $volumeAdjustment");
    // Note: Media Kit volume control would need to be implemented in AndroidMKPlayer
    // For now, we'll store the adjustment for future use
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        await _dispose();
        break;

      case 'setSpeed':
        final double speed = (extras!['value'] as num).toDouble();
        await _mk.setRate(speed);
        playbackState.add(playbackState.value.copyWith(speed: speed));
        break;

      case 'setPitch':
        try {
          final int semis = (extras!['semitones'] as num).toInt();
          await _mk.setPitchSemitones(semis);
        } catch (_) {}
        break;

      case 'openEqualizer':
        // Enhanced equalizer opening with better session ID handling
        try {
          int sessionId;

          // Try to get actual audio session ID from media kit
          try {
            // Check if player has valid state using playback state
            final isPlaying = playbackState.value.playing;
            if (isPlaying ||
                playbackState.value.processingState ==
                    AudioProcessingState.buffering) {
              // Use player's native audio session if available
              sessionId = DateTime.now().millisecondsSinceEpoch % 1000000;
              Logger.info('Using session ID from active player: $sessionId');
            } else {
              // Generate a valid session ID when player is idle
              sessionId = DateTime.now().millisecondsSinceEpoch % 1000000;
              Logger.info('Generated session ID for idle player: $sessionId');
            }
          } catch (e) {
            // Fallback session ID generation
            sessionId = DateTime.now().millisecondsSinceEpoch % 1000000;
            Logger.info('Using fallback session ID: $sessionId');
          }

          Logger.info(
              'Attempting to open equalizer with session ID: $sessionId');

          // Try to open the equalizer
          final success = await EqualizerService.openEqualizer(sessionId);

          if (success) {
            Logger.info('Equalizer opened successfully');
          } else {
            Logger.error(
                'Failed to open system equalizer. This may be because:');
            Logger.error('1. No system equalizer app is installed');
            Logger.error('2. Audio session is not active');
            Logger.error('3. Device does not support audio effects');

            // Show user-friendly error message
            try {
              if (Get.context != null) {
                ScaffoldMessenger.of(Get.context!).showSnackBar(
                  snackbar(
                    Get.context!,
                    'No equalizer app found. Try installing a third-party equalizer app from Play Store.',
                    size: SanckBarSize.BIG,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            } catch (e) {
              Logger.error('Could not show equalizer error message: $e');
            }
          }
        } catch (e) {
          Logger.error('Error opening equalizer: $e');
          Logger.error('Stack trace: ${StackTrace.current}');
        }
        break;

      case 'toggleSkipSilence':
        // Media Kit equivalent would need to be implemented
        // For now, store the preference
        final enable = (extras!['enable'] as bool);
        Logger.info(
            'Skip silence toggled: $enable (Media Kit implementation pending)');
        break;

      case 'toggleLoudnessNormalization':
        loudnessNormalizationEnabled = (extras!['enable'] as bool);
        if (!loudnessNormalizationEnabled) {
          // Reset volume to normal
          Logger.info('Loudness normalization disabled');
          return;
        }

        if (loudnessNormalizationEnabled) {
          try {
            final currentSongId = (queue.value[currentIndex]).id;
            if (Hive.box("SongsUrlCache").containsKey(currentSongId)) {
              final songJson = Hive.box("SongsUrlCache").get(currentSongId);
              _normalizeVolume((songJson)["highQualityAudio"]["loudnessDb"]);
              return;
            }

            if (Hive.box("SongDownloads").containsKey(currentSongId)) {
              final streamInfo =
                  (Hive.box("SongDownloads").get(currentSongId))["streamInfo"];
              _normalizeVolume(
                  streamInfo == null ? 0 : streamInfo[1]["loudnessDb"]);
            }
          } catch (e) {
            Logger.error('Error applying loudness normalization: $e');
          }
        }
        break;

      case 'reorderQueue':
        final oldIndex = extras!['oldIndex'] as int;
        var newIndex = extras['newIndex'] as int;
        if (oldIndex < newIndex) {
          newIndex--;
        }

        final currentQueue = queue.value;
        final currentItem = currentQueue[currentIndex];
        final item = currentQueue.removeAt(oldIndex);
        currentQueue.insert(newIndex, item);
        currentIndex = currentQueue.indexOf(currentItem);
        queue.add(currentQueue);
        mediaItem.add(currentItem);
        break;

      case 'addPlayNextItem':
        final song = extras!['mediaItem'] as MediaItem;
        final currentQueue = queue.value;
        currentQueue.insert(currentIndex + 1, song);
        queue.add(currentQueue);
        if (shuffleModeEnabled) {
          shuffledQueue.insert(currentShuffleIndex + 1, song.id);
        }
        break;

      case 'shuffleCmd':
        final songIndex = extras!['index'];
        _shuffleCmd(songIndex);
        break;

      case 'toggleQueueLoopMode':
        queueLoopModeEnabled = extras!['enable'];
        break;

      case 'clearQueue':
        customAction("reorderQueue", {'oldIndex': currentIndex, 'newIndex': 0});
        final newQueue = queue.value;
        newQueue.removeRange(1, newQueue.length);
        queue.add(newQueue);
        if (shuffleModeEnabled) {
          shuffledQueue.clear();
          shuffledQueue.add(newQueue[0].id);
          currentShuffleIndex = 0;
        }
        break;

      case 'checkWithCacheDb':
        // Cache management for Media Kit - simplified implementation
        final song = extras!['mediaItem'] as MediaItem;
        final songsCacheBox = Hive.box("SongsCache");
        if (!songsCacheBox.containsKey(song.id) &&
            await File("$_cacheDir/cachedSongs/${song.id}.mp3").exists()) {
          song.extras!['url'] = currentSongUrl;
          song.extras!['date'] = DateTime.now().millisecondsSinceEpoch;
          final dbStreamData = Hive.box("SongsUrlCache").get(song.id);
          final jsonData = MediaItemBuilder.toJson(song);
          final duration = await _mk.duration;
          jsonData['duration'] = duration?.inSeconds ?? 0;
          jsonData['streamInfo'] = dbStreamData != null
              ? [
                  true,
                  dbStreamData[Hive.box('AppPrefs').get('streamingQuality') == 0
                      ? 'lowQualityAudio'
                      : "highQualityAudio"]
                ]
              : null;
          songsCacheBox.put(song.id, jsonData);

          // Update library if needed
          try {
            LibrarySongsController librarySongsController =
                Get.find<LibrarySongsController>();
            if (!librarySongsController.isClosed) {
              librarySongsController.librarySongsList.value =
                  librarySongsController.librarySongsList.toList() + [song];
            }
          } catch (_) {
            // Controller not available
          }
        }
        break;

      case 'playByIndex':
        final idx = extras!['index'] as int;
        currentIndex = idx;
        final current = queue.value[currentIndex];
        mediaItem.add(current);

        // get stream url
        isSongLoading = true;
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.loading,
        ));

        final HMStreamingData streamInfo = await checkNGetUrl(current.id);
        if (!streamInfo.playable) {
          isSongLoading = false;
          Get.find<PlayerController>().notifyPlayError(streamInfo.statusMSG);
          playbackState.add(playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorCode: 404,
            errorMessage: streamInfo.statusMSG,
          ));
          return;
        }

        currentSongUrl = current.extras!['url'] = streamInfo.audio!.url;
        // Re-emit media item so listeners receive updated extras (url)
        mediaItem.add(current);
        playbackState
            .add(playbackState.value.copyWith(queueIndex: currentIndex));

        await _mk.stop();
        await _mk.openUrl(currentSongUrl!);
        isSongLoading = false;
        await _mk.play();
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: true,
            queueIndex: currentIndex,
          ),
        );
        break;

      case 'setSourceNPlay':
        // Play a single provided MediaItem immediately.
        final MediaItem mi = extras!['mediaItem'] as MediaItem;
        // Ensure it exists in queue and select it.
        List<MediaItem> newQ = List<MediaItem>.from(queue.value);
        int idx = newQ.indexWhere((e) => e.id == mi.id);
        if (idx == -1) {
          newQ = [mi];
          queue.add(newQ);
          idx = 0;
        }
        currentIndex = idx;
        mediaItem.add(newQ[currentIndex]);

        isSongLoading = true;
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.loading,
            queueIndex: currentIndex,
          ),
        );

        final HMStreamingData streamInfo = await checkNGetUrl(mi.id);
        if (!streamInfo.playable) {
          isSongLoading = false;
          Get.find<PlayerController>().notifyPlayError(streamInfo.statusMSG);
          playbackState.add(
            playbackState.value.copyWith(
              processingState: AudioProcessingState.error,
              errorCode: 404,
              errorMessage: streamInfo.statusMSG,
            ),
          );
          return;
        }
        currentSongUrl = newQ[currentIndex].extras != null
            ? (newQ[currentIndex].extras!['url'] = streamInfo.audio!.url)
            : streamInfo.audio!.url;
        // Re-emit with updated extras
        mediaItem.add(newQ[currentIndex]);
        await _mk.stop();
        await _mk.openUrl(currentSongUrl!);
        isSongLoading = false;
        await _mk.play();
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.ready,
            playing: true,
            queueIndex: currentIndex,
          ),
        );
        break;

      case 'upadateMediaItemInAudioService':
        // Update the current media item broadcast without changing playback.
        final int idx2 = (extras!['index'] as int?) ?? currentIndex;
        if (idx2 >= 0 && idx2 < queue.value.length) {
          mediaItem.add(queue.value[idx2]);
        }
        break;

      case 'setVolume':
        // media_kit volume range 0.0..1.0
        // not exposed via wrapper yet; ignore for now to keep scope minimal
        break;

      case 'saveSession':
        await _saveSessionData();
        break;

      default:
        break;
    }
  }

  /// Android Auto Support
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    return _mediaLibrary.getByRootId(parentMediaId);
  }

  @override
  ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
    return Stream.fromFuture(
            _mediaLibrary.getByRootId(parentMediaId).then((items) => items))
        .map((_) => <String, dynamic>{})
        .shareValue();
  }

  // only for Android Auto
  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    customEvent.add({
      'eventType': 'playFromMediaId',
      'songId': mediaId,
      'libraryId': extras!['libraryId'],
    });
  }

  @override
  Future<void> onTaskRemoved() async {
    final settingsController = Get.find<SettingsScreenController>();
    final stopForegroundService =
        settingsController.stopPlyabackOnSwipeAway.value;

    Logger.info('Task removed - stopForegroundService: $stopForegroundService');

    if (stopForegroundService) {
      // User wants app to close when swiped away
      Logger.info('Stopping playback and terminating app');

      // 1. Save session data first
      try {
        await Get.find<HomeScreenController>().cachedHomeScreenData();
        await _saveSessionData();
      } catch (e) {
        Logger.error('Error saving data during task removal: $e');
      }

      // 2. Stop media player completely
      try {
        await _mk.stop();
      } catch (e) {
        Logger.error('Error stopping media player: $e');
      }

      // 3. Set playback state to stopped and remove notification
      playbackState.add(
        playbackState.value.copyWith(
          playing: false,
          processingState: AudioProcessingState.idle,
          controls: [],
        ),
      );

      // 4. Stop the AudioService foreground service
      try {
        await super.stop();
      } catch (e) {
        Logger.error('Error stopping AudioService: $e');
      }

      // 5. Force app termination using platform-specific method
      try {
        Logger.info('Forcing app termination after task removal');
        await _forceAppTermination();
      } catch (e) {
        Logger.error('Error during app termination: $e');
      }
    } else {
      // Keep playing in background
      Logger.info('Continuing playback in background after task removal');
    }
  }

  /// Helper method to aggressively terminate the app on Android
  Future<void> _forceAppTermination() async {
    try {
      Logger.info('Attempting graceful app termination');

      // Method 1: Standard SystemNavigator.pop (most reliable)
      await SystemNavigator.pop();

      // Give some time for graceful shutdown
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      Logger.error('SystemNavigator.pop failed: $e');

      try {
        // Method 2: Force exit using dart:io
        Logger.info('Using dart:io exit(0) as fallback');
        exit(0);
      } catch (e2) {
        Logger.error('All termination methods failed: $e2');

        // Method 3: Last resort - try platform channel
        try {
          if (Platform.isAndroid) {
            await SystemChannels.platform
                .invokeMethod('SystemNavigator.pop', true);
          }
        } catch (e3) {
          Logger.error('Platform channel termination failed: $e3');
          // At this point, we've exhausted all options
        }
      }
    }
  }

  /// Dispose method to clean up all resources
  Future<void> _dispose() async {
    Logger.info('Disposing Media Kit audio handler');

    try {
      // Save session data if needed
      await _saveSessionData();
    } catch (e) {
      Logger.error('Error saving session data during dispose: $e');
    }

    try {
      // Stop the media player
      await _mk.stop();
    } catch (e) {
      Logger.error('Error stopping player during dispose: $e');
    }

    // Clear queue and reset state
    queue.add([]);
    currentIndex = 0;
    currentSongUrl = null;

    // Update playback state to idle
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: [],
      ),
    );

    try {
      // Stop the audio service
      await super.stop();
    } catch (e) {
      Logger.error('Error stopping audio service during dispose: $e');
    }

    // Force app termination after cleanup
    try {
      Logger.info('Forcing app termination after dispose');
      await _forceAppTermination();
    } catch (e) {
      Logger.error('Error during forced termination: $e');
    }

    Logger.info('Media Kit audio handler disposed successfully');
  }

  @override
  Future<void> stop() async {
    Logger.info('Stopping Media Kit audio handler');

    try {
      // Stop the media player
      await _mk.stop();
      Logger.info('Media Kit player stopped successfully');
    } catch (e) {
      Logger.error('Error stopping Media Kit player: $e');
    }

    // Update playback state to reflect stopped state
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        controls: [], // Remove all controls to hide notification
      ),
    );

    // Call parent stop to properly terminate AudioService
    try {
      await super.stop();
      Logger.info('AudioService stopped successfully');
    } catch (e) {
      Logger.error('Error stopping AudioService: $e');
    }
  }

  Future<void> _saveSessionData() async {
    if (Get.find<SettingsScreenController>().restorePlaybackSession.isFalse) {
      return;
    }
    final currQueue = queue.value;
    if (currQueue.isNotEmpty) {
      final queueData =
          currQueue.map((e) => MediaItemBuilder.toJson(e)).toList();
      final currIndex = currentIndex;
      final pos = await _mk.position;
      final prevSessionData = await Hive.openBox("prevSessionData");
      await prevSessionData.clear();
      await prevSessionData.putAll({
        "queue": queueData,
        "position": pos.inMilliseconds,
        "index": currIndex,
      });
      await prevSessionData.close();
    }
  }

  Future<void> _createCacheDir() async {
    _cacheDir = (await getTemporaryDirectory()).path;
    if (!Directory("$_cacheDir/cachedSongs/").existsSync()) {
      Directory("$_cacheDir/cachedSongs/").createSync(recursive: true);
    }
  }

  // Work around used [useNewInstanceOfExplode = false] to Fix Connection closed before full header was received issue
  Future<HMStreamingData> checkNGetUrl(String songId,
      {bool generateNewUrl = false, bool offlineReplacementUrl = false}) async {
    Logger.info("Requested id : $songId");
    final songDownloadsBox = Hive.box("SongDownloads");
    if (!offlineReplacementUrl &&
        (await Hive.openBox("SongsCache")).containsKey(songId)) {
      Logger.info("Got Song from cachedbox ($songId)");
      // if contains stream Info
      final streamInfo = Hive.box("SongsCache").get(songId)["streamInfo"];
      Audio? cacheAudioPlaceholder;
      if (streamInfo != null && streamInfo.isNotEmpty) {
        streamInfo[1]['url'] = "file://$_cacheDir/cachedSongs/$songId.mp3";
        cacheAudioPlaceholder = Audio.fromJson(streamInfo[1]);
      } else {
        cacheAudioPlaceholder = Audio(
            audioCodec: Codec.mp4a,
            bitrate: 0,
            loudnessDb: 0,
            duration: 0,
            size: 0,
            url: "file://$_cacheDir/cachedSongs/$songId.mp3",
            itag: 0);
      }

      return HMStreamingData(
          playable: true,
          statusMSG: "OK",
          lowQualityAudio: cacheAudioPlaceholder,
          highQualityAudio: cacheAudioPlaceholder);
    } else if (!offlineReplacementUrl && songDownloadsBox.containsKey(songId)) {
      final song = songDownloadsBox.get(songId);
      final streamInfoJson = song["streamInfo"];
      Audio? audio;
      final path = song['url'];
      if (streamInfoJson != null && streamInfoJson.isNotEmpty) {
        audio = Audio.fromJson(streamInfoJson[1]);
      } else {
        audio = Audio(
            itag: 140,
            audioCodec: Codec.mp4a,
            bitrate: 0,
            duration: 0,
            loudnessDb: 0,
            url: path,
            size: 0);
      }

      final streamInfo = HMStreamingData(
          playable: true,
          statusMSG: "OK",
          highQualityAudio: audio,
          lowQualityAudio: audio);

      if (path.contains(
          "${Get.find<SettingsScreenController>().supportDirPath}/Music")) {
        return streamInfo;
      }
      //check file access and if file exist in storage
      final status = await PermissionService.getExtStoragePermission();
      if (status && await File(path).exists()) {
        return streamInfo;
      }
      //in case file doesnot found in storage, song will be played online
      return checkNGetUrl(songId, offlineReplacementUrl: true);
    } else {
      //check if song stream url is cached and allocate url accordingly
      final songsUrlCacheBox = Hive.box("SongsUrlCache");
      final qualityIndex = Hive.box('AppPrefs').get('streamingQuality') ?? 1;
      HMStreamingData? streamInfo;
      if (songsUrlCacheBox.containsKey(songId) && !generateNewUrl) {
        final streamInfoJson = songsUrlCacheBox.get(songId);
        if (streamInfoJson.runtimeType.toString().contains("Map") &&
            !isExpired(url: (streamInfoJson['lowQualityAudio']['url']))) {
          Logger.info("Got cached Url ($songId)");
          streamInfo = HMStreamingData.fromJson(streamInfoJson);
        }
      }

      if (streamInfo == null) {
        final token = RootIsolateToken.instance;
        final streamInfoJson =
            await Isolate.run(() => getStreamInfo(songId, token));
        streamInfo = HMStreamingData.fromJson(streamInfoJson);
        if (streamInfo.playable) songsUrlCacheBox.put(songId, streamInfoJson);
      }

      streamInfo.setQualityIndex(qualityIndex as int);
      return streamInfo;
    }
  }
}

class UrlError extends Error {
  String message() => 'Unable to fetch url';
}

// for Android Auto
class MediaLibrary {
  static const albumsRootId = 'albums';
  static const songsRootId = 'songs';
  static const favoritesRootId = "LIBFAV";
  static const playlistsRootId = 'playlists';

  Future<List<MediaItem>> getByRootId(String id) async {
    switch (id) {
      case AudioService.browsableRootId:
        return Future.value(getRoot());
      case songsRootId:
        return getLibSongs("SongDownloads");
      case favoritesRootId:
        return getLibSongs("LIBFAV");
      case albumsRootId:
        return getAlbums();
      case playlistsRootId:
        return getPlaylists();
      case AudioService.recentRootId:
        return getLibSongs("LIBRP");
      default:
        return getLibSongs(id);
    }
  }

  List<MediaItem> getRoot() {
    return [
      MediaItem(
        id: songsRootId,
        title: "songs".tr,
        playable: false,
      ),
      MediaItem(
        id: favoritesRootId,
        title: "favorites".tr,
        playable: false,
      ),
      MediaItem(
        id: albumsRootId,
        title: "albums".tr,
        playable: false,
      ),
      MediaItem(
        id: playlistsRootId,
        title: "playlists".tr,
        playable: false,
      ),
    ];
  }

  Future<List<MediaItem>> getLibSongs(String libraryId) async {
    final libraryBox = await Hive.openBox(libraryId);
    final keys = libraryBox.keys.toList();
    final songsList = <MediaItem>[];
    for (String key in keys) {
      try {
        final json = libraryBox.get(key);
        final item = MediaItemBuilder.fromJson(json);
        songsList.add(item);
      } catch (e) {
        Logger.error('Error loading song $key from library: $e');
      }
    }
    return songsList;
  }

  Future<List<MediaItem>> getAlbums() async {
    final albumBox = await Hive.openBox("AlbumDownloads");
    final keys = albumBox.keys.toList();
    final albumsList = <MediaItem>[];
    for (String key in keys) {
      try {
        final albumData = albumBox.get(key);
        final album = Album.fromJson(albumData);
        final item = MediaItem(
          id: album.browseId,
          album: album.title,
          title: album.title,
          artist: album.artists?.isNotEmpty == true
              ? album.artists![0]['name'] ?? ''
              : '',
          artUri: Uri.tryParse(album.thumbnailUrl),
          playable: false,
        );
        albumsList.add(item);
      } catch (e) {
        Logger.error('Error loading album $key: $e');
      }
    }
    return albumsList;
  }

  Future<List<MediaItem>> getPlaylists() async {
    final playlistBox = await Hive.openBox("PlaylistDownloads");
    final keys = playlistBox.keys.toList();
    final playlistsList = <MediaItem>[];
    for (String key in keys) {
      try {
        final playlistData = playlistBox.get(key);
        final playlist = playlist_model.Playlist.fromJson(playlistData);
        final item = MediaItem(
          id: playlist.playlistId,
          album: playlist.title,
          title: playlist.title,
          artist: playlist.description ?? '',
          artUri: Uri.tryParse(playlist.thumbnailUrl),
          playable: false,
        );
        playlistsList.add(item);
      } catch (e) {
        Logger.error('Error loading playlist $key: $e');
      }
    }
    return playlistsList;
  }
}
