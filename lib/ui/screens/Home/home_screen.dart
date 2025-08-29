import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Search/components/desktop_search_bar.dart';
import '/ui/screens/Search/search_screen_controller.dart';
import '/ui/widgets/animated_screen_transition.dart';
import '../Library/library_combined.dart';
import '../../widgets/side_nav_bar.dart';
import '../Library/library.dart';
import '../Search/search_screen.dart';
import '../Settings/settings_screen_controller.dart';
import '/ui/player/player_controller.dart';
import '/ui/widgets/create_playlist_dialog.dart';
import '../../navigator.dart';
import '../../widgets/content_list_widget.dart';
import '../../widgets/artist_carousel_widget.dart';
import '../../widgets/quickpickswidget.dart';
import '../../widgets/shimmer_widgets/home_shimmer.dart';
import 'home_screen_controller.dart';
import '../Settings/settings_screen.dart';
import '/models/quick_picks.dart';
import '/models/artist.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    final HomeScreenController homeScreenController =
        Get.find<HomeScreenController>();
    final SettingsScreenController settingsScreenController =
        Get.find<SettingsScreenController>();

    return Scaffold(
        floatingActionButton: Obx(
          () => ((homeScreenController.tabIndex.value == 0 &&
                          !GetPlatform.isDesktop) ||
                      homeScreenController.tabIndex.value == 2) &&
                  settingsScreenController.isBottomNavBarEnabled.isFalse
              ? Obx(
                  () => Padding(
                    padding: EdgeInsets.only(
                        bottom: playerController.playerPanelMinHeight.value >
                                Get.mediaQuery.padding.bottom
                            ? playerController.playerPanelMinHeight.value -
                                Get.mediaQuery.padding.bottom
                            : playerController.playerPanelMinHeight.value),
                    child: SizedBox(
                      height: 60,
                      width: 60,
                      child: FittedBox(
                        child: FloatingActionButton(
                            focusElevation: 0,
                            shape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(14))),
                            elevation: 0,
                            onPressed: () async {
                              if (homeScreenController.tabIndex.value == 2) {
                                showDialog(
                                    context: context,
                                    builder: (context) =>
                                        const CreateNRenamePlaylistPopup());
                              } else {
                                Get.toNamed(ScreenNavigationSetup.searchScreen,
                                    id: ScreenNavigationSetup.id);
                              }
                              // file:///data/user/0/com.example.harmonymusic/cache/libCachedImageData/
                              //file:///data/user/0/com.example.harmonymusic/cache/just_audio_cache/
                            },
                            child: Icon(homeScreenController.tabIndex.value == 2
                                ? Icons.add
                                : Icons.search)),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        body: Obx(
          () => Row(
            children: <Widget>[
              // create a navigation rail
              settingsScreenController.isBottomNavBarEnabled.isFalse
                  ? const SideNavBar()
                  : const SizedBox(
                      width: 0,
                    ),
              //const VerticalDivider(thickness: 1, width: 2),
              Expanded(
                child: Obx(() => AnimatedScreenTransition(
                    enabled: settingsScreenController
                        .isTransitionAnimationDisabled.isFalse,
                    resverse: homeScreenController.reverseAnimationtransiton,
                    horizontalTransition:
                        settingsScreenController.isBottomNavBarEnabled.isTrue,
                    child: Center(
                      key: ValueKey<int>(homeScreenController.tabIndex.value),
                      child: const Body(),
                    ))),
              ),
            ],
          ),
        ));
  }
}

class Body extends StatelessWidget {
  const Body({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final homeScreenController = Get.find<HomeScreenController>();
    final settingsScreenController = Get.find<SettingsScreenController>();
    final size = MediaQuery.of(context).size;
    final topPadding = GetPlatform.isDesktop
        ? 85.0
        : context.isLandscape
            ? 50.0
            : size.height < 750
                ? 80.0
                : 85.0;
    final leftPadding =
        settingsScreenController.isBottomNavBarEnabled.isTrue ? 20.0 : 5.0;
    
    return Obx(() {
      final tabIndex = homeScreenController.tabIndex.value;
      
      if (tabIndex == 0) {
        return _buildHomeContent(context, homeScreenController, settingsScreenController, topPadding, leftPadding);
      } else if (tabIndex == 1) {
        return settingsScreenController.isBottomNavBarEnabled.isTrue
            ? const SearchScreen()
            : const SongsLibraryWidget();
      } else if (tabIndex == 2) {
        return settingsScreenController.isBottomNavBarEnabled.isTrue
            ? const CombinedLibrary()
            : const PlaylistNAlbumLibraryWidget(isAlbumContent: false);
      } else if (tabIndex == 3) {
        return settingsScreenController.isBottomNavBarEnabled.isTrue
            ? const SettingsScreen(isBottomNavActive: true)
            : const PlaylistNAlbumLibraryWidget();
      } else if (tabIndex == 4) {
        return const LibraryArtistWidget();
      } else if (tabIndex == 5) {
        return const SettingsScreen();
      } else {
        return Center(
          child: Text("$tabIndex"),
        );
      }
    });
  }

  Widget _buildHomeContent(
    BuildContext context,
    HomeScreenController homeScreenController,
    SettingsScreenController settingsScreenController,
    double topPadding,
    double leftPadding,
  ) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // for Desktop search bar
              if (GetPlatform.isDesktop) {
                final sscontroller = Get.find<SearchScreenController>();
                if (sscontroller.focusNode.hasFocus) {
                  sscontroller.focusNode.unfocus();
                }
              }
            },
            child: Obx(
              () => homeScreenController.networkError.isTrue
                  ? _buildErrorWidget(context, homeScreenController)
                  : _buildContentWidget(context, homeScreenController, topPadding),
            ),
          ),
          if (GetPlatform.isDesktop) _buildDesktopSearchBar(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, HomeScreenController homeScreenController) {
    return SizedBox(
      height: MediaQuery.of(context).size.height - 180,
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              "home".tr,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "networkError1".tr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                          color: Theme.of(context).textTheme.titleLarge!.color,
                          borderRadius: BorderRadius.circular(10)),
                      child: InkWell(
                        onTap: () {
                          homeScreenController.loadContentFromNetwork();
                        },
                        child: Text(
                          "retry".tr,
                          style: TextStyle(
                              color: Theme.of(context).canvasColor),
                        ),
                      ),
                    ),
                  ]),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildContentWidget(BuildContext context, HomeScreenController homeScreenController, double topPadding) {
    return Obx(() {
      // dispose all detached scroll controllers
      homeScreenController.disposeDetachedScrollControllers();
      
      return homeScreenController.isContentFetched.value
          ? _PerformantHomeList(
              homeScreenController: homeScreenController,
              topPadding: topPadding,
            )
          : Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: const HomeShimmer(),
            );
    });
  }

  Widget _buildDesktopSearchBar() {
    return Align(
      alignment: Alignment.topCenter,
      child: LayoutBuilder(builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth > 800 ? 800 : constraints.maxWidth - 40,
          child: const Padding(
              padding: EdgeInsets.only(top: 15.0), child: DesktopSearchBar()),
        );
      }),
    );
  }

}

// Performance-optimized list widget with memoization
class _PerformantHomeList extends StatefulWidget {
  const _PerformantHomeList({
    required this.homeScreenController,
    required this.topPadding,
  });

  final HomeScreenController homeScreenController;
  final double topPadding;

  @override
  State<_PerformantHomeList> createState() => _PerformantHomeListState();
}

class _PerformantHomeListState extends State<_PerformantHomeList>
    with AutomaticKeepAliveClientMixin {
  late List<Widget> _cachedItems;
  late List<dynamic> _lastDataSignature;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _buildCachedItems();
  }

  void _buildCachedItems() {
    final items = <Widget>[];
    
    // Quick Picks Widget - memoized
    items.add(_MemoizedQuickPicks(
      quickPicks: widget.homeScreenController.quickPicks.value,
      homeScreenController: widget.homeScreenController,
    ));
    
    // Fresh New Music Widget - memoized
    final freshMusic = widget.homeScreenController.freshNewMusic.value;
    if (freshMusic != null) {
      items.add(_MemoizedQuickPicks(
        quickPicks: freshMusic,
        homeScreenController: widget.homeScreenController,
      ));
    }
    
    // Christian Artists Carousel - memoized
    final artists = widget.homeScreenController.christianArtists;
    if (artists.isNotEmpty) {
      items.add(_MemoizedArtistCarousel(
        artists: artists,
        title: 'Christian Artists',
      ));
    }
    
    // Middle and Fixed Content - memoized
    items.addAll(_buildMemoizedContentWidgets(
        widget.homeScreenController.middleContent));
    items.addAll(_buildMemoizedContentWidgets(
        widget.homeScreenController.fixedContent));
    
    _cachedItems = items;
    _lastDataSignature = [
      widget.homeScreenController.quickPicks.value.songList.length,
      widget.homeScreenController.freshNewMusic.value?.songList.length ?? 0,
      widget.homeScreenController.christianArtists.length,
      widget.homeScreenController.middleContent.length,
      widget.homeScreenController.fixedContent.length,
    ];
  }

  List<Widget> _buildMemoizedContentWidgets(dynamic contentList) {
    return contentList
        .map<Widget>((content) => _MemoizedContentListWidget(
              content: content,
              homeScreenController: widget.homeScreenController,
            ))
        .toList();
  }

  bool _shouldRebuildCache() {
    final currentSignature = [
      widget.homeScreenController.quickPicks.value.songList.length,
      widget.homeScreenController.freshNewMusic.value?.songList.length ?? 0,
      widget.homeScreenController.christianArtists.length,
      widget.homeScreenController.middleContent.length,
      widget.homeScreenController.fixedContent.length,
    ];
    
    if (_lastDataSignature.length != currentSignature.length) {
      return true;
    }
    
    for (int i = 0; i < currentSignature.length; i++) {
      if (_lastDataSignature[i] != currentSignature[i]) {
        return true;
      }
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Obx(() {
      // Only rebuild if data actually changed
      if (_shouldRebuildCache()) {
        _buildCachedItems();
      }
      
      return ListView.builder(
        padding: EdgeInsets.only(bottom: 200, top: widget.topPadding),
        itemCount: _cachedItems.length,
        itemBuilder: (context, index) => _cachedItems[index],
        cacheExtent: 1000, // Optimize viewport caching
      );
    });
  }
}

// Memoized QuickPicks Widget
class _MemoizedQuickPicks extends StatelessWidget {
  const _MemoizedQuickPicks({
    required this.quickPicks,
    required this.homeScreenController,
  });

  final QuickPicks quickPicks;
  final HomeScreenController homeScreenController;

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    homeScreenController.contentScrollControllers.add(scrollController);
    
    return QuickPicksWidget(
      content: quickPicks,
      scrollController: scrollController,
    );
  }
}

// Memoized Artist Carousel Widget
class _MemoizedArtistCarousel extends StatelessWidget {
  const _MemoizedArtistCarousel({
    required this.artists,
    required this.title,
  });

  final List<Artist> artists;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ArtistCarouselWidget(
      title: title,
      artists: artists,
    );
  }
}

// Memoized Content List Widget
class _MemoizedContentListWidget extends StatelessWidget {
  const _MemoizedContentListWidget({
    required this.content,
    required this.homeScreenController,
  });

  final dynamic content;
  final HomeScreenController homeScreenController;

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    homeScreenController.contentScrollControllers.add(scrollController);
    
    return ContentListWidget(
      content: content,
      scrollController: scrollController,
    );
  }
}
