import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:musicplayer/core/widgets/app_error_view.dart';
import 'package:musicplayer/features/youtube/presentation/widgets/youtube_vid.dart';
import 'package:musicplayer/features/youtube/controller/youtube_controller.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class VideoList extends GetView<YoutubeController> {
  const VideoList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagingListener(
        builder: (context, state, fetchNextPage) {
          return PagedListView<int, Video>.separated(
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate(
                animateTransitions: true,
                firstPageProgressIndicatorBuilder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
                itemBuilder: (context, video, index) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: YouTubeVid(
                    videoAuthor: video.author,
                    videoDuration: video.duration,
                    videoThumbnail: video.thumbnails.mediumResUrl,
                    videoTitle: video.title,
                    downloadVideoFunction: () {
                      controller.addVideoToQuee(video);
                    },
                    index: index,
                  ),
                ),
                firstPageErrorIndicatorBuilder: (context) => AppErrorView(
                  title: 'Couldn’t load videos',
                  message:
                      'Check your connection and try loading the videos again.',
                  onRetry: controller.pagingController.refresh,
                ),
                newPageErrorIndicatorBuilder: (context) => AppErrorView(
                  title: 'Couldn’t load more videos',
                  message: 'Check your connection and try again.',
                  onRetry: fetchNextPage,
                  compact: true,
                ),
              ),
              separatorBuilder: (context, index) => const Divider());
        },
        controller: controller.pagingController);
  }
}
