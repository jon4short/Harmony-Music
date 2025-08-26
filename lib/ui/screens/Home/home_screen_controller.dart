import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '/models/media_Item_builder.dart';
import '/ui/player/player_controller.dart';
import '../../../utils/update_check_flag_file.dart';
import '../../../utils/helper.dart';
import '/models/album.dart';
import '/models/playlist.dart';
import '/models/artist.dart';
import '/models/quick_picks.dart';
import '/services/music_service.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/widgets/new_version_dialog.dart';

class HomeScreenController extends GetxController {
  final MusicServices _musicServices = Get.find<MusicServices>();
  final isContentFetched = false.obs;
  final tabIndex = 0.obs;
  final networkError = false.obs;
  final quickPicks = QuickPicks([]).obs;
  final middleContent = [].obs;
  final fixedContent = [].obs;
  final christianArtists = <Artist>[].obs;
  final Rxn<QuickPicks> freshNewMusic = Rxn<QuickPicks>();
  final showVersionDialog = true.obs;
  //isHomeScreenOnTop var only useful if bottom nav enabled
  final isHomeSreenOnTop = true.obs;
  final List<ScrollController> contentScrollControllers = [];
  bool reverseAnimationtransiton = false;

  @override
  onInit() {
    super.onInit();
    loadContent();
    if (updateCheckFlag) _checkNewVersion();
  }

  Future<void> loadContent() async {
    final box = Hive.box("AppPrefs");
    final isCachedHomeScreenDataEnabled =
        box.get("cacheHomeScreenData") ?? true;
    if (isCachedHomeScreenDataEnabled) {
      final loaded = await loadContentFromDb();

      if (loaded) {
        final currTimeSecsDiff = DateTime.now().millisecondsSinceEpoch -
            (box.get("homeScreenDataTime") ??
                DateTime.now().millisecondsSinceEpoch);
        if (currTimeSecsDiff / 1000 > 3600 * 8) {
          loadContentFromNetwork(silent: true);
        }
      } else {
        loadContentFromNetwork();
      }
    } else {
      loadContentFromNetwork();
    }
  }

  Future<bool> loadContentFromDb() async {
    final homeScreenData = await Hive.openBox("homeScreenData");
    if (homeScreenData.keys.isNotEmpty) {
      final String quickPicksType = homeScreenData.get("quickPicksType");
      final List quickPicksData = homeScreenData.get("quickPicks");
      final List middleContentData = homeScreenData.get("middleContent") ?? [];
      final List fixedContentData = homeScreenData.get("fixedContent") ?? [];
      quickPicks.value = QuickPicks(
          quickPicksData.map((e) => MediaItemBuilder.fromJson(e)).toList(),
          title: quickPicksType);
      middleContent.value = middleContentData
          .map((e) => e["type"] == "Album Content"
              ? AlbumContent.fromJson(e)
              : PlaylistContent.fromJson(e))
          .toList();
      fixedContent.value = fixedContentData
          .map((e) => e["type"] == "Album Content"
              ? AlbumContent.fromJson(e)
              : PlaylistContent.fromJson(e))
          .toList();
      isContentFetched.value = true;
      printINFO("Loaded from offline db");
      return true;
    } else {
      return false;
    }
  }

  Future<void> loadContentFromNetwork({bool silent = false}) async {
    final box = Hive.box("AppPrefs");
    String contentType = box.get("discoverContentType") ?? "QP";

    networkError.value = false;
    try {
      List middleContentTemp = [];
      final homeContentListMap = await _musicServices.getHome(
          limit:
              Get.find<SettingsScreenController>().noOfHomeScreenContent.value);
      // Remove Tamil Hits section if present
      homeContentListMap.removeWhere(
          (element) => (element['title'] ?? '').toString().toLowerCase() == 'tamil hits');
      if (contentType == "TR") {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Trending");
        if (index != -1 && index != 0) {
          quickPicks.value = QuickPicks(
              List<MediaItem>.from(homeContentListMap[index]["contents"]),
              title: "Trending");
        } else if (index == -1) {
          List charts = await _musicServices.getCharts();
          final con =
              charts.length == 4 ? charts.removeAt(3) : charts.removeAt(2);
          quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
              title: con['title']);
          middleContentTemp.addAll(charts);
        }
      } else if (contentType == "TMV") {
        final index = homeContentListMap
            .indexWhere((element) => element['title'] == "Top music videos");
        if (index != -1 && index != 0) {
          final con = homeContentListMap.removeAt(index);
          quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
              title: con["title"]);
        } else if (index == -1) {
          List charts = await _musicServices.getCharts();
          quickPicks.value = QuickPicks(
              List<MediaItem>.from(charts[0]["contents"]),
              title: charts[0]["title"]);
          middleContentTemp.addAll(charts.sublist(1));
        }
      } else if (contentType == "BOLI") {
        try {
          final songId = box.get("recentSongId");
          if (songId != null) {
            final rel = (await _musicServices.getContentRelatedToSong(
                songId, getContentHlCode()));
            final con = rel.removeAt(0);
            quickPicks.value =
                QuickPicks(List<MediaItem>.from(con["contents"]));
            middleContentTemp.addAll(rel);
          }
        } catch (e) {
          printERROR("Seems Based on last interaction content currently not available!");
        }
      }

      // Build Quick Picks highlighting Christian artists
      try {
        final christianSeedArtists = [
          'Hillsong',
          'Upper Room',
          'Bethel Music',
          'Kari Jobe',
          'Chris Tomlin',
        ];
        final List<MediaItem> christianPicks = [];
        for (final name in christianSeedArtists) {
          final res = await _musicServices.search(name, filter: 'songs', limit: 5);
          final songs = (res['Songs'] ?? []).whereType<MediaItem>().toList();
          christianPicks.addAll(songs);
          if (christianPicks.length >= 25) break;
        }
        if (christianPicks.isNotEmpty) {
          quickPicks.value = QuickPicks(christianPicks.take(25).toList(), title: 'Quick Picks');
        } else if (quickPicks.value.songList.isEmpty) {
          final index = homeContentListMap
              .indexWhere((element) => element['title'] == "Quick picks");
          if (index != -1) {
            final con = homeContentListMap.removeAt(index);
            quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
                title: "Quick picks");
          }
        }
      } catch (_) {
        if (quickPicks.value.songList.isEmpty) {
          final index = homeContentListMap
              .indexWhere((element) => element['title'] == "Quick picks");
          if (index != -1) {
            final con = homeContentListMap.removeAt(index);
            quickPicks.value = QuickPicks(List<MediaItem>.from(con["contents"]),
                title: "Quick picks");
          }
        }
      }

      // Fetch curated Christian artists from provided list
      try {
        final seeds = <String>[
          // Contemporary Christian & Worship
          'Lauren Daigle', 'Chris Tomlin', 'Elevation Worship', 'MercyMe',
          'TobyMac', 'Casting Crowns', 'Hillsong Worship', 'Kari Jobe',
          'Tauren Wells',
          // Traditional Gospel
          'CeCe Winans', 'Kirk Franklin', 'Mahalia Jackson', 'Shirley Caesar',
          'Andraé Crouch', 'Donnie McClurkin',
          // Rock & Alternative
          'Stryper', 'Skillet', 'Switchfoot', 'Audio Adrenaline',
          // Folk & Indie
          'John Mark Pantana', 'Elias Dummer', 'Jess Ray',
        ];
        final List<Artist> curated = [];
        final seen = <String>{};
        for (final name in seeds) {
          final res = await _musicServices.search(name, filter: 'artists', limit: 3);
          final candidates = (res['Artists'] ?? []).whereType<Artist>().toList();
          if (candidates.isEmpty) continue;
          // Pick best match by name contains, else first
          Artist pick = candidates.first;
          for (final a in candidates) {
            if (a.name.toLowerCase().contains(name.toLowerCase())) {
              pick = a;
              break;
            }
          }
          if (!seen.contains(pick.browseId)) {
            curated.add(pick);
            seen.add(pick.browseId);
          }
          if (curated.length >= 30) break;
        }
        christianArtists.value = curated;
      } catch (_) {
        christianArtists.clear();
      }

      // Build Fresh New Music: Christian songs released this year
      try {
        final currentYear = DateTime.now().year;
        final res = await _musicServices.search('christian', filter: 'songs', limit: 60);
        final List<MediaItem> songs = (res['Songs'] ?? []).whereType<MediaItem>().toList();
        final fresh = songs.where((m) {
          final y = m.extras?['year'];
          if (y == null) return false;
          if (y is int) return y == currentYear;
          if (y is String) {
            final parsed = int.tryParse(y);
            return parsed == currentYear;
          }
          return false;
        }).toList();
        if (fresh.isNotEmpty) {
          freshNewMusic.value = QuickPicks(fresh.take(25).toList(), title: 'Fresh New Music');
        } else {
          freshNewMusic.value = null;
        }
      } catch (_) {
        freshNewMusic.value = null;
      }

      middleContent.value = _setContentList(middleContentTemp);
      fixedContent.value = _setContentList(homeContentListMap);

      isContentFetched.value = true;

      // set home content last update time
      cachedHomeScreenData(updateAll: true);
      await Hive.box("AppPrefs")
          .put("homeScreenDataTime", DateTime.now().millisecondsSinceEpoch);
      // ignore: unused_catch_stack
    } on NetworkError catch (r, e) {
      printERROR("Home Content not loaded due to ${r.message}");
      await Future.delayed(const Duration(seconds: 1));
      networkError.value = !silent;
    }
  }

  List _setContentList(
    List<dynamic> contents,
  ) {
    List contentTemp = [];
    for (var content in contents) {
      if ((content["contents"][0]).runtimeType == Playlist) {
        final tmp = PlaylistContent(
            playlistList: (content["contents"]).whereType<Playlist>().toList(),
            title: content["title"]);
        if (tmp.playlistList.length >= 2) {
          contentTemp.add(tmp);
        }
      } else if ((content["contents"][0]).runtimeType == Album) {
        final tmp = AlbumContent(
            albumList: (content["contents"]).whereType<Album>().toList(),
            title: content["title"]);
        if (tmp.albumList.length >= 2) {
          contentTemp.add(tmp);
        }
      }
    }
    return contentTemp;
  }

  Future<void> changeDiscoverContent(dynamic val, {String? songId}) async {
    QuickPicks? quickPicks_;
    if (val == 'QP') {
      final homeContentListMap = await _musicServices.getHome(limit: 3);
      quickPicks_ = QuickPicks(
          List<MediaItem>.from(homeContentListMap[0]["contents"]),
          title: homeContentListMap[0]["title"]);
    } else if (val == "TMV" || val == 'TR') {
      try {
        final charts = await _musicServices.getCharts();
        final index = val == "TMV"
            ? 0
            : charts.length == 4
                ? 3
                : 2;
        quickPicks_ = QuickPicks(
            List<MediaItem>.from(charts[index]["contents"]),
            title: charts[index]["title"]);
      } catch (e) {
        printERROR(
            "Seems ${val == "TMV" ? "Top music videos" : "Trending songs"} currently not available!");
      }
    } else {
      songId ??= Hive.box("AppPrefs").get("recentSongId");
      if (songId != null) {
        try {
          final value = await _musicServices.getContentRelatedToSong(
              songId, getContentHlCode());
          middleContent.value = _setContentList(value);
          if (value.isNotEmpty && (value[0]['title']).contains("like")) {
            quickPicks_ =
                QuickPicks(List<MediaItem>.from(value[0]["contents"]));
            Hive.box("AppPrefs").put("recentSongId", songId);
          }
          // ignore: empty_catches
        } catch (e) {}
      }
    }
    if (quickPicks_ == null) return;

    quickPicks.value = quickPicks_;

    // set home content last update time
    cachedHomeScreenData(updateQuickPicksNMiddleContent: true);
    await Hive.box("AppPrefs")
        .put("homeScreenDataTime", DateTime.now().millisecondsSinceEpoch);
  }

  String getContentHlCode() {
    const List<String> unsupportedLangIds = ["ia", "ga", "fj", "eo"];
    final userLangId =
        Get.find<SettingsScreenController>().currentAppLanguageCode.value;
    return unsupportedLangIds.contains(userLangId) ? "en" : userLangId;
  }

  void onSideBarTabSelected(int index) {
    reverseAnimationtransiton = index > tabIndex.value;
    tabIndex.value = index;
  }

  void onBottonBarTabSelected(int index) {
    reverseAnimationtransiton = index > tabIndex.value;
    tabIndex.value = index;
  }

  void _checkNewVersion() {
    showVersionDialog.value =
        Hive.box("AppPrefs").get("newVersionVisibility") ?? true;
    if (showVersionDialog.isTrue) {
      newVersionCheck(Get.find<SettingsScreenController>().currentVersion)
          .then((value) {
        if (value) {
          showDialog(
              context: Get.context!,
              builder: (context) => const NewVersionDialog());
        }
      });
    }
  }

  void onChangeVersionVisibility(bool val) {
    Hive.box("AppPrefs").put("newVersionVisibility", !val);
    showVersionDialog.value = !val;
  }

  ///This is used to minimized bottom navigation bar by setting [isHomeSreenOnTop.value] to `true` and set mini player height.
  ///
  ///and applicable/useful if bottom nav enabled
  void whenHomeScreenOnTop() {
    if (Get.find<SettingsScreenController>().isBottomNavBarEnabled.isTrue) {
      final currentRoute = getCurrentRouteName();
      final isHomeOnTop = currentRoute == '/homeScreen';
      final isResultScreenOnTop = currentRoute == '/searchResultScreen';
      final playerCon = Get.find<PlayerController>();

      isHomeSreenOnTop.value = isHomeOnTop;

      // Set miniplayer height accordingly
      if (!playerCon.initFlagForPlayer) {
        if (isHomeOnTop) {
          playerCon.playerPanelMinHeight.value = 75.0;
        } else {
          Future.delayed(
              isResultScreenOnTop
                  ? const Duration(milliseconds: 300)
                  : Duration.zero, () {
            playerCon.playerPanelMinHeight.value =
                75.0 + Get.mediaQuery.viewPadding.bottom;
          });
        }
      }
    }
  }

  Future<void> cachedHomeScreenData({
    bool updateAll = false,
    bool updateQuickPicksNMiddleContent = false,
  }) async {
    if (Get.find<SettingsScreenController>().cacheHomeScreenData.isFalse ||
        quickPicks.value.songList.isEmpty) {
      return;
    }

    final homeScreenData = Hive.box("homeScreenData");

    if (updateQuickPicksNMiddleContent) {
      await homeScreenData.putAll({
        "quickPicksType": quickPicks.value.title,
        "quickPicks": _getContentDataInJson(quickPicks.value.songList,
            isQuickPicks: true),
        "middleContent": _getContentDataInJson(middleContent.toList()),
      });
    } else if (updateAll) {
      await homeScreenData.putAll({
        "quickPicksType": quickPicks.value.title,
        "quickPicks": _getContentDataInJson(quickPicks.value.songList,
            isQuickPicks: true),
        "middleContent": _getContentDataInJson(middleContent.toList()),
        "fixedContent": _getContentDataInJson(fixedContent.toList())
      });
    }

    printINFO("Saved Homescreen data data");
  }

  List<Map<String, dynamic>> _getContentDataInJson(List content,
      {bool isQuickPicks = false}) {
    if (isQuickPicks) {
      return content.toList().map((e) => MediaItemBuilder.toJson(e)).toList();
    } else {
      return content.map((e) {
        if (e.runtimeType == AlbumContent) {
          return (e as AlbumContent).toJson();
        } else {
          return (e as PlaylistContent).toJson();
        }
      }).toList();
    }
  }

  void disposeDetachedScrollControllers({bool disposeAll = false}) {
    final scrollControllersCopy = contentScrollControllers.toList();
    for (final contoller in scrollControllersCopy) {
      if (!contoller.hasClients || disposeAll) {
        contentScrollControllers.remove(contoller);
        contoller.dispose();
      }
    }
  }

  @override
  void dispose() {
    disposeDetachedScrollControllers(disposeAll: true);
    super.dispose();
  }
}
