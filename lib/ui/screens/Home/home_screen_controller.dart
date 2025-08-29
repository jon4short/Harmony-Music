import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;

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

  // Performance optimization: cache for reducing API calls
  final Map<String, dynamic> _contentCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 2);

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
      // Remove Indian music sections if present
      homeContentListMap.removeWhere((element) {
        final title = (element['title'] ?? '').toString().toLowerCase();
        final indianMusicKeywords = [
          'tamil hits',
          'hindi hits',
          'bollywood',
          'punjabi hits',
          'telugu hits',
          'bengali hits',
          'marathi hits',
          'gujarati hits',
          'kannada hits',
          'malayalam hits',
          'indian classical',
          'bhojpuri hits',
          'assamese hits',
          'odia hits',
          'urdu hits',
          'devotional hindi',
          'devotional tamil',
          'indian devotional',
          'regional hits',
          'desi music',
          'indian pop',
          'indian rock',
          'qawwali',
          'ghazal',
          'carnatic',
          'hindustani',
          'sufi',
          'bhangra',
          'folk indian',
          'indian folk',
          'indian indie'
        ];
        return indianMusicKeywords.any((keyword) => title.contains(keyword));
      });
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
          printERROR(
              "Seems Based on last interaction content currently not available!");
        }
      }

      // Build Quick Picks highlighting Christian artists (optimized)
      try {
        // Get randomized Christian artists (reduced to 5 for faster loading)
        final allChristianArtists = _getComprehensiveChristianArtistList();
        final shuffledArtists = List<String>.from(allChristianArtists)
          ..shuffle(math.Random());
        final christianSeedArtists = shuffledArtists.take(5).toList();

        printINFO(
            'Selected ${christianSeedArtists.length} random Christian artists for Quick Picks: ${christianSeedArtists.join(', ')}');

        final List<MediaItem> christianPicks = [];
        final Map<String, List<MediaItem>> songsByArtist = {};

        // Parallel search for better performance
        final searchFutures = christianSeedArtists.map((name) async {
          try {
            final res =
                await _musicServices.search(name, filter: 'songs', limit: 3);
            return {
              'name': name,
              'songs': (res['Songs'] ?? []).whereType<MediaItem>().toList()
            };
          } catch (e) {
            return {'name': name, 'songs': <MediaItem>[]};
          }
        }).toList();

        final searchResults = await Future.wait(searchFutures);

        // Process results
        for (final result in searchResults) {
          final name = result['name'] as String;
          final songs = result['songs'] as List<MediaItem>;

          for (final song in songs) {
            final artistKey = song.artist?.toLowerCase() ?? name.toLowerCase();
            if (!songsByArtist.containsKey(artistKey)) {
              songsByArtist[artistKey] = [];
            }
            songsByArtist[artistKey]!.add(song);
          }
        }

        // Randomly select up to 2 songs per artist, then shuffle all
        final random = math.Random();
        for (final artistSongs in songsByArtist.values) {
          if (artistSongs.isNotEmpty) {
            // Shuffle songs for this artist
            artistSongs.shuffle(random);
            // Take up to 2 songs per artist
            final songsToAdd = artistSongs.take(2).toList();
            christianPicks.addAll(songsToAdd);
          }
        }

        // Shuffle the final list to mix artists
        christianPicks.shuffle(random);

        // Limit to 10 total songs as requested
        final finalPicks = christianPicks.take(10).toList();
        if (finalPicks.isNotEmpty) {
          quickPicks.value = QuickPicks(finalPicks, title: 'Quick Picks');
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

      // Fetch curated Christian artists from comprehensive list (optimized)
      try {
        final allChristianArtists = _getComprehensiveChristianArtistList();

        // Randomize and select maximum 6 artists for faster loading
        final shuffledArtists = List<String>.from(allChristianArtists)
          ..shuffle(math.Random());
        final selectedArtists = shuffledArtists.take(6).toList();

        // Parallel search for better performance
        final artistSearchFutures = selectedArtists.map((name) async {
          try {
            final res =
                await _musicServices.search(name, filter: 'artists', limit: 2);
            final candidates =
                (res['Artists'] ?? []).whereType<Artist>().toList();
            if (candidates.isEmpty) return null;

            // Pick best match by name contains, else first
            Artist pick = candidates.first;
            for (final a in candidates) {
              if (a.name.toLowerCase().contains(name.toLowerCase())) {
                pick = a;
                break;
              }
            }
            return pick;
          } catch (e) {
            return null;
          }
        }).toList();

        final artistResults = await Future.wait(artistSearchFutures);

        final List<Artist> curated = [];
        final seen = <String>{};
        for (final artist in artistResults) {
          if (artist != null && !seen.contains(artist.browseId)) {
            curated.add(artist);
            seen.add(artist.browseId);
          }
        }

        christianArtists.value = curated;
        printINFO(
            'Selected ${selectedArtists.length} random Christian artists: ${selectedArtists.join(', ')}');
      } catch (e) {
        printERROR('Error loading random Christian artists: $e');
        christianArtists.clear();
      }

      // Skip Fresh New Music loading for faster home screen (temporarily disabled)
      // This feature will load asynchronously in the background after initial load
      freshNewMusic.value = null;

      // Schedule Fresh New Music loading in background after initial content is loaded
      Future.delayed(const Duration(seconds: 2), () {
        _loadFreshNewMusicInBackground();
      });

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
      // Only keep America Europe Top 10 category
      final title = content["title"] ?? '';
      final titleLower = title.toLowerCase();

      // Skip Indian music content
      if (_isIndianMusicContent(title)) {
        continue;
      }

      // Only allow America Europe Top 10 category (case insensitive)
      if (!titleLower.contains('america') ||
          !titleLower.contains('europe') ||
          !titleLower.contains('top')) {
        continue;
      }

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
      // Filter out Indian music content
      homeContentListMap.removeWhere((element) {
        final title = (element['title'] ?? '').toString().toLowerCase();
        return _isIndianMusicContent(title);
      });
      if (homeContentListMap.isNotEmpty) {
        quickPicks_ = QuickPicks(
            List<MediaItem>.from(homeContentListMap[0]["contents"]),
            title: homeContentListMap[0]["title"]);
      }
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

  // Performance optimization: cache validation
  bool _isValidCache(String key) {
    if (!_contentCache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }
    final timestamp = _cacheTimestamps[key]!;
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  // Helper method to check if year data matches current year
  bool _isFromThisYear(dynamic yearData, int currentYear) {
    if (yearData == null) return false;
    if (yearData is int) return yearData == currentYear;
    if (yearData is String) {
      final parsed = int.tryParse(yearData);
      return parsed == currentYear;
    }
    return false;
  }

  // Background loading method for Fresh New Music
  Future<void> _loadFreshNewMusicInBackground() async {
    try {
      final cacheKey = 'christian_new_releases_${DateTime.now().year}';
      List<MediaItem> freshTracks = [];

      // Check cache first for performance
      if (_isValidCache(cacheKey)) {
        freshTracks = List<MediaItem>.from(_contentCache[cacheKey] ?? []);
        if (freshTracks.isNotEmpty) {
          freshNewMusic.value = QuickPicks(freshTracks.take(25).toList(),
              title: 'Fresh New Music');
          printINFO('Loaded cached Fresh New Music');
          return;
        }
      }

      final currentYear = DateTime.now().year;

      // Use fewer artists for background loading
      final freshMusicArtists =
          List<String>.from(_getComprehensiveChristianArtistList())
            ..shuffle(math.Random());
      final selectedFreshArtists = freshMusicArtists.take(8).toList();

      printINFO(
          'Background loading Fresh New Music from ${selectedFreshArtists.length} artists');

      // Search for new releases from random Christian artists
      for (final artistName in selectedFreshArtists) {
        try {
          final artistQuery = '$artistName $currentYear';
          final res = await _musicServices.search(artistQuery,
              filter: 'songs', limit: 5);
          final songs = (res['Songs'] ?? []).whereType<MediaItem>().toList();

          final thisYearSongs = songs.where((song) {
            final yearData = song.extras?['year'];
            final isThisYear = _isFromThisYear(yearData, currentYear);
            final isChristianContent =
                _isChristianContent(song.title, song.artist ?? '', artistName);
            return isThisYear && isChristianContent;
          }).toList();

          freshTracks.addAll(thisYearSongs);
          if (freshTracks.length >= 15) break;

          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          continue;
        }
      }

      // Remove duplicates and shuffle
      final seenIds = <String>{};
      freshTracks = freshTracks.where((track) {
        if (seenIds.contains(track.id)) return false;
        seenIds.add(track.id);
        return true;
      }).toList();

      freshTracks.shuffle(math.Random());

      // Cache the results
      _contentCache[cacheKey] = freshTracks.take(15).toList();
      _cacheTimestamps[cacheKey] = DateTime.now();

      if (freshTracks.isNotEmpty) {
        freshNewMusic.value =
            QuickPicks(freshTracks.take(15).toList(), title: 'Fresh New Music');
        printINFO(
            'Background loaded ${freshTracks.length} Fresh New Music tracks');
      }
    } catch (e) {
      printERROR('Error background loading Fresh New Music: $e');
    }
  }

  // Helper method to get comprehensive Christian artist list
  List<String> _getComprehensiveChristianArtistList() {
    return [
      // A
      'All Sons & Daughters', 'Coffey Anderson', 'Meredith Andrews',
      'Ascend the Hill',
      'Cory Asbury', 'Audrey Assad', 'Austin Stone Worship', 'The Afters',

      // B
      'Josh Baldwin', 'Paul Baloche', 'Jon Bauer', 'Marco Barrientos',
      'Francesca Battistelli',
      'Vicky Beeching', 'The Belonging Co', 'Bethel Music', 'Big Daddy Weave',
      'Charles Billingsley',
      'Bluetree', 'Bowater Chris', 'Dante Bowe', 'Lincoln Brewster',
      'Bright City', 'Brenton Brown',
      'Clint Brown', 'Fernanda Brum', 'Bryan & Katie Torwalt', 'Building 429',
      'Bukas Palad Music Ministry',
      'Jon Buller', 'Byron Cage',

      // C
      'Adam Cappa', 'Caedmon\'s Call', 'Adrienne Camp', 'Jeremy Camp', 'Carman',
      'Cody Carnes', 'Steven Curtis Chapman', 'Christ for the Nations Music',
      'The City Harmonic',
      'Citipointe Worship', 'Citizens & Saints', 'Consumed by Fire',
      'Amanda Cook', 'Travis Cottrell',
      'Crowder', 'David Crowder Band', 'Casting Crowns',

      // D
      'Lauren Daigle', 'Hope Darst', 'Diante do Trono', 'Delirious?',
      'Desperation Band',
      'Jeff Deyo', 'Disciple', 'The Digital Age', 'Kristene DiMarco',
      'Christine D\'Clario',
      'Brian Doerksen', 'Colton Dixon',

      // E
      'Samantha Ebert', 'Elevation Worship', 'Misty Edwards', 'Darrell Evans',

      // F
      'Ludmila Ferber', 'Lou Fellingham', 'FFH', 'Finding Favour',
      'Don Francisco',
      'Brooke Fraser', 'Austin French', 'Marine Friesen', 'For King & Country',
      'Jordan Feliz',
      'Forrest Frank',

      // G
      'Rob Galea', 'Gateway Worship', 'Maryanne J. George', 'Keith Getty',
      'Aaron Gillespie',
      'Matt Gilman', 'The Glorious Unseen', 'Danny Gokey',
      'Steffany Gretzinger', 'Keith Green',
      'Michael Gungor', 'Amy Grant',

      // H
      'Deitrick Haddon', 'Charlie Hall', 'Fred Hammond', 'Mark Harris',
      'Harvest',
      'Benjamin William Hastings', 'Brandon Heath', 'JJ Heller',
      'Hillsong United',
      'Hillsong Young & Free', 'Hillsong Worship', 'Israel Houghton',
      'Housefires',
      'Joel Houston', 'Tim Hughes',

      // J
      'Josiah Queen', 'Jesus Culture', 'Kari Jobe', 'Brian Johnson',
      'Jenn Johnson',
      'Jonathan David & Melissa Helser', 'Julissa',

      // K
      'Glenn Kaiser', 'The Katinas', 'Graham Kendrick', 'Dustin Kensrue',
      'Kings Kaleidoscope',
      'Kutless', 'Ron Kenoly',

      // L
      'Brandon Lake', 'Lenny LeBlanc', 'Leeland', 'Crystal Lewis',
      'Brian Littrell',
      'Loud Harp', 'The LUKAS Band', 'LIFE Worship',

      // M
      'Matthew West', 'Matt Maher', 'Mandisa', 'Maranatha! Singers',
      'Robin Mark',
      'William Matthews', 'Maverick City Music', 'The McClures',
      'Heath McNease',
      'MercyMe', 'Don Moen', 'Danilo Montero', 'Chandler Moore', 'Mosaic MSC',

      // N
      'Ana Nóbrega', 'Newsboys', 'NewSong', 'NewSpring Worship',
      'New Life Worship',
      'Katy Nichole', 'Christy Nockels',

      // O
      'One Sonic Society', 'Fernando Ortega', 'The O.C. Supertones',

      // P
      'Parachute Band', 'Twila Paris', 'Andy Park', 'Laura Hackett Park',
      'Alexis Peña',
      'Andrew Peterson', 'Petra', 'Phatfish', 'David Phelps',
      'Phillips, Craig and Dean',
      'Planetboom', 'Matt Price', 'Kevin Prosch', 'Planetshakers',

      // Q
      'Chris Quilala',

      // R
      'Naomi Raine', 'Matt Redman', 'Rend Collective', 'Jeremy Riddle',
      'Gabriela Rocha',
      'Rock n Roll Worship Circus', 'Jesus Adrian Romero',

      // S
      'Israel Salazar', 'Nívea Soares', 'Torrey Salter', 'Sanctus Real',
      'Juliano Son',
      'Rebecca St. James', 'Kathryn Scott', 'Seventh Day Slumber',
      'Beckah Shae',
      'Shane & Shane', 'Aaron Shust', 'Sidewalk Prophets', 'Manfred Siebald',
      'Sinach',
      'Sixteen Cities', 'Skillet', 'Chris Sligh', 'Martin Smith',
      'Michael W. Smith',
      'Sonicflood', 'Starfield', 'Laura Story', 'Stryper',

      // T
      'Tenth Avenue North', 'Third Day', 'Chris Tomlin', 'Stuart Townend',
      'Hunter G. K. Thompson', 'Jon Thurlow', 'Randy Travis', 'Tribl',
      'TobyMac', 'Tauren Wells',

      // U
      'United Pursuit', 'Jason Upton',

      // V
      'Ana Paula Valadão', 'André Valadão', 'Mariana Valadão', 'Jaci Velasquez',
      'Vertical Church Band', 'Victory Worship',

      // W
      'Kim Walker-Smith', 'Tommy Walker', 'John Waller', 'Watermark',
      'Wayne Watson',
      'Waterdeep', 'We Are Messengers', 'Steven Welch', 'Evan Wickham',
      'Phil Wickham',
      'Paul Wilbur', 'Kelly Willard', 'Zach Williams', 'Josh Wilson',
      'Marcos Witt',
      'Worth Dying For', 'CeCe Winans', 'Anne Wilson',

      // Y
      'Young Oceans',

      // Z
      'Darlene Zschech',
    ];
  }

  // Helper method to detect Christian content
  bool _isChristianContent(String title, String artist, String searchedArtist) {
    final titleLower = title.toLowerCase();
    final artistLower = artist.toLowerCase();
    final searchedLower = searchedArtist.toLowerCase();

    // If we searched for a specific artist, prioritize that match
    if (searchedArtist.isNotEmpty && artistLower.contains(searchedLower)) {
      return true;
    }

    // Christian keywords in title or artist
    final christianKeywords = [
      'jesus',
      'christ',
      'god',
      'lord',
      'holy',
      'spirit',
      'prayer',
      'worship',
      'praise',
      'hallelujah',
      'alleluia',
      'amen',
      'gospel',
      'christian',
      'faith',
      'grace',
      'salvation',
      'blessed',
      'heaven',
      'savior',
      'saviour',
      'redeemer',
      'almighty',
      'divine',
      'eternal',
      'resurrection',
      'cross',
      'bible',
      'scripture',
      'psalm',
      'hymn',
      'sanctuary',
      'glory',
      'ministry'
    ];

    return christianKeywords.any((keyword) =>
        titleLower.contains(keyword) || artistLower.contains(keyword));
  }

  // Helper method to detect Indian music content
  bool _isIndianMusicContent(String title) {
    final titleLower = title.toLowerCase();
    final indianMusicKeywords = [
      'tamil',
      'hindi',
      'bollywood',
      'punjabi',
      'telugu',
      'bengali',
      'marathi',
      'gujarati',
      'kannada',
      'malayalam',
      'indian',
      'bhojpuri',
      'assamese',
      'odia',
      'urdu',
      'devotional hindi',
      'devotional tamil',
      'regional',
      'desi',
      'qawwali',
      'ghazal',
      'carnatic',
      'hindustani',
      'sufi',
      'bhangra',
      'folk indian',
      'indie indian'
    ];

    return indianMusicKeywords.any((keyword) => titleLower.contains(keyword));
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

    // Clear cache for memory optimization
    _contentCache.clear();
    _cacheTimestamps.clear();

    super.dispose();
  }
}
