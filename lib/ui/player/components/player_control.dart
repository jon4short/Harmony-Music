import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:widget_marquee/widget_marquee.dart';

import '/ui/player/components/animated_play_button.dart';
import '../player_controller.dart';
import '/ui/widgets/image_widget.dart';

class PlayerControlWidget extends StatelessWidget {
  const PlayerControlWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerController playerController = Get.find<PlayerController>();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.white,
                        Colors.transparent
                      ],
                    ).createShader(
                        Rect.fromLTWH(0, 0, rect.width, rect.height));
                  },
                  blendMode: BlendMode.dstIn,
                  child: Obx(() {
                    final cs = Theme.of(context).colorScheme;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Marquee(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(seconds: 10),
                          id: "${playerController.currentSong.value}_title",
                          child: Text(
                            playerController.currentSong.value != null
                                ? playerController.currentSong.value!.title
                                : "NA",
                            textAlign: TextAlign.start,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Marquee(
                          delay: const Duration(milliseconds: 300),
                          duration: const Duration(seconds: 10),
                          id: "${playerController.currentSong.value}_subtitle",
                          child: Text(
                            playerController.currentSong.value != null
                                ? playerController.currentSong.value!.artist!
                                : "NA",
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.85)),
                          ),
                        )
                      ],
                    );
                  }),
                ),
              ),
              SizedBox(
                width: 45,
                child: IconButton(
                    onPressed: playerController.toggleFavourite,
                    icon: Obx(() => Icon(
                          playerController.isCurrentSongFav.isFalse
                              ? Icons.favorite_border
                              : Icons.favorite,
                          color: Theme.of(context).textTheme.titleMedium!.color,
                        ))),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          GetX<PlayerController>(builder: (controller) {
            return ProgressBar(
              thumbRadius: 7,
              barHeight: 4.5,
              baseBarColor: Theme.of(context).sliderTheme.inactiveTrackColor,
              bufferedBarColor:
                  Theme.of(context).sliderTheme.valueIndicatorColor,
              progressBarColor: Theme.of(context).sliderTheme.activeTrackColor,
              thumbColor: Theme.of(context).sliderTheme.thumbColor,
              timeLabelTextStyle: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontSize: 14),
              progress: controller.progressBarStatus.value.current,
              total: controller.progressBarStatus.value.total,
              buffered: controller.progressBarStatus.value.buffered,
              onSeek: controller.seek,
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: playerController.toggleShuffleMode,
                  icon: Obx(() => Icon(
                        Ionicons.shuffle,
                        color: playerController.isShuffleModeEnabled.value
                            ? Theme.of(context).textTheme.titleLarge!.color
                            : Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .color!
                                .withValues(alpha: 0.2),
                      ))),
              _previousButton(playerController, context),
              const CircleAvatar(radius: 35, child: AnimatedPlayButton(key: Key("playButton"),)),
              _nextButton(playerController, context),
              Obx(() {
                return IconButton(
                    onPressed: playerController.toggleLoopMode,
                    icon: Icon(
                      Icons.all_inclusive,
                      color: playerController.isLoopModeEnabled.value
                          ? Theme.of(context).textTheme.titleLarge!.color
                          : Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .color!
                              .withValues(alpha: 0.2),
                    ));
              }),
              // Tempo button (timer icon)
              IconButton(
                icon: Icon(
                  Icons.timer,
                  color: Theme.of(context).textTheme.titleLarge!.color,
                ),
                onPressed: () => _showMaterialTempoSheet(context, playerController),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pitch control section
          _PitchControlSection(playerController: playerController),
          // Ensure content is not obscured by system navigation bars (phones with buttons)
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 8),
        ]);
  }


  Widget _previousButton(
      PlayerController playerController, BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.skip_previous,
        color: Theme.of(context).textTheme.titleMedium!.color,
      ),
      iconSize: 30,
      onPressed: playerController.prev,
    );
  }
}

Widget _nextButton(PlayerController playerController, BuildContext context) {
  return Obx(() {
    final isLastSong = playerController.currentQueue.isEmpty ||
        (!(playerController.isShuffleModeEnabled.isTrue ||
                playerController.isQueueLoopModeEnabled.isTrue) &&
            (playerController.currentQueue.last.id ==
                playerController.currentSong.value?.id));
    return IconButton(
        icon: Icon(
          Icons.skip_next,
          color: isLastSong
              ? Theme.of(context).textTheme.titleLarge!.color!.withValues(alpha: 0.2)
              : Theme.of(context).textTheme.titleMedium!.color,
        ),
        iconSize: 30,
        onPressed: isLastSong ? null : playerController.next);
  });
}

void _showMaterialTempoSheet(BuildContext context, PlayerController controller) {
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      double temp = controller.speed.value;
      return StatefulBuilder(builder: (context, setState) {
        final cs = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (controller.currentSong.value != null) ...[
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ImageWidget(
                                  size: 56,
                                  song: controller.currentSong.value!,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  controller.currentSong.value!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text('Playback speed', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('${temp.toStringAsFixed(2)}x',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 28)),
                        Slider(
                          value: temp,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${temp.toStringAsFixed(2)}x',
                          onChanged: (v) => setState(() => temp = v),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await controller.setSpeed(1.0);
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).maybePop();
                              },
                              child: const Text('Reset'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                await controller.setSpeed(temp);
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).maybePop();
                              },
                              child: const Text('Apply'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });
    },
  );
}

class _PitchControlSection extends StatelessWidget {
  final PlayerController playerController;
  const _PitchControlSection({required this.playerController});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final semis = playerController.pitchSemitones.value;
      final keyLabel = playerController.transposedKeyLabel();
      final status = playerController.keyDetectionStatus.value;
      final cs = Theme.of(context).colorScheme;
      String displayLabel;
      if (status == 'detecting') {
        displayLabel = 'Detecting…';
      } else if (status == 'failed') {
        displayLabel = 'Key: N/A';
      } else {
        displayLabel = keyLabel;
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pitch and Key detection side-by-side for better accessibility
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Pitch: ${semis > 0 ? '+' : ''}$semis st',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: GestureDetector(
                  onTap: () => _showMaterialKeySheet(context, playerController),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayLabel,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurface),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Reload key detection',
                        child: IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () async {
                            await playerController.clearManualKeyOverride(reDetect: true);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Pitch -1 semitone',
                icon: const Icon(Icons.remove),
                onPressed: () {
                  if (semis > -6) {
                    playerController.setPitchSemitones(semis - 1);
                  }
                },
              ),
              Expanded(
                child: Slider(
                  value: semis.toDouble(),
                  min: -6,
                  max: 6,
                  divisions: 12,
                  label: '${semis > 0 ? '+' : ''}$semis',
                  onChanged: (v) => playerController.setPitchSemitones(v.round()),
                ),
              ),
              IconButton(
                tooltip: 'Pitch +1 semitone',
                icon: const Icon(Icons.add),
                onPressed: () {
                  if (semis < 6) {
                    playerController.setPitchSemitones(semis + 1);
                  }
                },
              ),
            ],
          ),

        ],
      );
    });
  }
}

void _showMaterialKeySheet(BuildContext context, PlayerController controller) {
  const List<String> notes = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  const List<String> modes = ['Major','Minor','Mixolydian'];
  String selNote = controller.originalKey.value != 'N/A'
      ? controller.originalKey.value
      : 'C';
  String selMode = () {
    final label = controller.originalKeyLabel.value.toLowerCase();
    if (label.contains('mixolydian')) return 'Mixolydian';
    if (label.contains('minor')) return 'Minor';
    return 'Major';
  }();
  showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final cs = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (controller.currentSong.value != null) ...[
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ImageWidget(
                                  size: 56,
                                  song: controller.currentSong.value!,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  controller.currentSong.value!.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Text('Set song key', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            Tooltip(
                              message: 'Reload key detection',
                              child: IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: () async {
                                  await controller.clearManualKeyOverride(reDetect: true);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Tonic', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final n in notes)
                              ChoiceChip(
                                label: Text(n),
                                selected: selNote == n,
                                onSelected: (_) => setState(() => selNote = n),
                              )
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Mode', style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final m in modes)
                              ChoiceChip(
                                label: Text(m),
                                selected: selMode == m,
                                onSelected: (_) => setState(() => selMode = m),
                              )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await controller.clearManualKeyOverride(reDetect: true);
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).maybePop();
                              },
                              child: const Text('Clear Override'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () async {
                                final label = selMode == 'Minor'
                                    ? '$selNote minor'
                                    : (selMode == 'Mixolydian'
                                        ? '$selNote Mixolydian'
                                        : selNote);
                                await controller.setManualKeyOverride(label);
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).maybePop();
                              },
                              child: const Text('Save'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      });
    },
  );
}
