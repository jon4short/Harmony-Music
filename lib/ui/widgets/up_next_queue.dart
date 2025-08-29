import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:harmonic/ui/player/player_controller.dart';
import 'package:widget_marquee/widget_marquee.dart';

import 'image_widget.dart';
import 'snackbar.dart';
import 'songinfo_bottom_sheet.dart';

class UpNextQueue extends StatelessWidget {
  const UpNextQueue(
      {super.key,
      this.onReorderEnd,
      this.onReorderStart,
      this.isQueueInSlidePanel = true});
  final void Function(int)? onReorderStart;
  final void Function(int)? onReorderEnd;
  final bool isQueueInSlidePanel;

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    return Stack(
      children: [
        // OneUI 7 style uniform blurred backdrop matching player background
        Positioned.fill(
          child: ClipRRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.85),
                      Theme.of(context).primaryColor.withValues(alpha: 0.80),
                      Theme.of(context).primaryColor.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Obx(() {
          return ReorderableListView.builder(
            footer: SizedBox(height: Get.mediaQuery.padding.bottom),
            scrollController:
                isQueueInSlidePanel ? playerController.scrollController : null,
            onReorder: (int oldIndex, int newIndex) {
              if (playerController.isShuffleModeEnabled.isTrue) {
                ScaffoldMessenger.of(Get.context!).showSnackBar(snackbar(
                    Get.context!, "queuerearrangingDeniedMsg".tr,
                    size: SanckBarSize.BIG));
                return;
              }
              playerController.onReorder(oldIndex, newIndex);
            },
            onReorderStart: onReorderStart,
            onReorderEnd: onReorderEnd,
            itemCount: playerController.currentQueue.length,
            padding: EdgeInsets.only(
                top: isQueueInSlidePanel ? 55 : 0,
                bottom: isQueueInSlidePanel ? 80 : 0),
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final homeScaffoldContext =
                  playerController.homeScaffoldkey.currentContext!;
              //print("${playerController.currentSongIndex.value == index} $index");
              return Material(
                key: Key('$index'),
                child: Obx(
                  () => Dismissible(
                    key: Key(playerController.currentQueue[index].id),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async =>
                        playerController.currentSongIndex.value != index,
                    onDismissed: (direction) {
                      playerController
                          .removeFromQueue(playerController.currentQueue[index]);
                    },
                    child: ListTile(
                      onTap: () {
                        playerController.seekByIndex(index);
                      },
                      onLongPress: () {
                        showModalBottomSheet(
                          constraints: const BoxConstraints(maxWidth: 500),
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(10.0)),
                          ),
                          isScrollControlled: true,
                          context: playerController
                              .homeScaffoldkey.currentState!.context,
                          builder: (context) => SongInfoBottomSheet(
                            playerController.currentQueue[index],
                            calledFromQueue: true,
                          ),
                        ).whenComplete(() => Get.delete<SongInfoController>());
                      },
                      contentPadding: EdgeInsets.only(
                          top: 0,
                          left: GetPlatform.isAndroid ? 30 : 0,
                          right: 25),
                      tileColor: playerController.currentSongIndex.value == index
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (GetPlatform.isDesktop)
                            IconButton(
                                onPressed: () {
                                  if (playerController.currentSongIndex.value ==
                                      index) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        snackbar(context,
                                            "songRemovedfromQueueCurrSong".tr,
                                            size: SanckBarSize.BIG));
                                  } else {
                                    playerController.removeFromQueue(
                                        playerController.currentQueue[index]);
                                  }
                                },
                                icon: const Icon(Icons.close)),
                          ImageWidget(
                            size: 50,
                            song: playerController.currentQueue[index],
                          ),
                        ],
                      ),
                      title: Marquee(
                        delay: const Duration(milliseconds: 300),
                        duration: const Duration(seconds: 5),
                        id: "queue${playerController.currentQueue[index].title.hashCode}",
                        child: Text(
                          playerController.currentQueue[index].title,
                          maxLines: 1,
                          style: Theme.of(homeScaffoldContext)
                              .textTheme
                              .titleMedium,
                        ),
                      ),
                      subtitle: Text(
                        "${playerController.currentQueue[index].artist}",
                        maxLines: 1,
                        style: Theme.of(homeScaffoldContext)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Colors.white.withValues(
                                alpha: playerController.currentSongIndex.value == index ? 0.75 : 0.85,
                              ),
                            ),
                      ),
                    trailing: ReorderableDragStartListener(
                      enabled: !GetPlatform.isDesktop,
                      index: index,
                      child: Container(
                        padding: EdgeInsets.only(
                            right: (GetPlatform.isDesktop) ? 20 : 5, left: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (!GetPlatform.isDesktop)
                              const Icon(
                                Icons.drag_handle,
                              ),
                            playerController.currentSongIndex.value == index
                                ? const Icon(Icons.equalizer, color: Colors.white)
                                : Text(
                                    playerController.currentQueue[index]
                                            .extras!['length'] ??
                                        "",
                                    style: Theme.of(homeScaffoldContext)
                                        .textTheme
                                        .titleSmall,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
        }),
      ],
    );
  }
}
