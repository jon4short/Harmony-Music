import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../navigator.dart';
import '../widgets/image_widget.dart';
import '../../models/artist.dart';

class ArtistCarouselWidget extends StatelessWidget {
  const ArtistCarouselWidget({super.key, required this.title, required this.artists});

  final String title;
  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            // Optional View All in future
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(width: 15),
            itemCount: artists.length,
            itemBuilder: (context, index) {
              final artist = artists[index];
              return _ArtistTile(artist: artist);
            },
          ),
        ),
      ],
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({required this.artist});
  final Artist artist;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.toNamed(
          ScreenNavigationSetup.artistScreen,
          id: ScreenNavigationSetup.id,
          arguments: [false, artist],
        );
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: SizedBox(
                height: 120,
                width: 120,
                child: ImageWidget(
                  size: 120,
                  artist: artist,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              artist.subscribers ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}
