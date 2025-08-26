import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import '/models/media_Item_builder.dart';
import '/services/android_mk_player.dart';
import '/services/utils.dart';
import '/ui/player/player_controller.dart';
import '/models/hm_streaming_data.dart';
import '../ui/screens/Settings/settings_screen_controller.dart';
import '/services/permission_service.dart';
import '/services/stream_service.dart';
import '/utils/helper.dart';
import '/services/background_task.dart';

/// Android-only AudioHandler powered by media_kit/mpv for pitch support.
class MyAudioHandlerAndroidMK extends BaseAudioHandler with GetxServiceMixin {
  late final AndroidMKPlayer _mk;
  late String _cacheDir;

  // queue & playback state
  int currentIndex = 0;
  bool isSongLoading = true;
  String? currentSongUrl;

  MyAudioHandlerAndroidMK() {
    // Ensure media_kit is initialized BEFORE creating player
    MediaKit.ensureInitialized();
    _mk = AndroidMKPlayer();

    _createCacheDir();

    // Try restore preferences (non-blocking & safe)
    try {
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
    } catch (_) {
      // ignore
    }

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
  Future<void> stop() async {
    await _mk.stop();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
      ),
    );
    return super.stop();
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
    final nextIndex = currentIndex + 1;
    if (nextIndex < queue.value.length) {
      await customAction('playByIndex', {'index': nextIndex});
    } else {
      // end of queue: do nothing (queue looping handled at higher level if any)
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (queue.value.isEmpty) return;
    final prevIndex = currentIndex - 1;
    if (prevIndex >= 0) {
      await customAction('playByIndex', {'index': prevIndex});
    } else {
      // at start: do nothing
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'dispose':
        await stop();
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
        playbackState.add(playbackState.value.copyWith(queueIndex: currentIndex));

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

  Future<void> _saveSessionData() async {
    if (Get.find<SettingsScreenController>().restorePlaybackSession.isFalse) {
      return;
    }
    final currQueue = queue.value;
    if (currQueue.isNotEmpty) {
      final queueData = currQueue.map((e) => MediaItemBuilder.toJson(e)).toList();
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
    printINFO("Requested id : $songId");
    final songDownloadsBox = Hive.box("SongDownloads");
    if (!offlineReplacementUrl && (await Hive.openBox("SongsCache")).containsKey(songId)) {
      printINFO("Got Song from cachedbox ($songId)");
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
          printINFO("Got cached Url ($songId)");
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
