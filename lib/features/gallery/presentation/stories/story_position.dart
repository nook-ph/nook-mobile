import 'package:equatable/equatable.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';

/// Where the story viewer is: which person ([story]) and which of their
/// photos ([photo]). Moving past either end of everything is [done].
class StoryPosition extends Equatable {
  const StoryPosition(this.story, this.photo, {this.done = false});

  final int story;
  final int photo;

  /// Moved past the last photo of the last person: the viewer closes.
  final bool done;

  /// The next photo: the person's next one, else the next person's first
  /// unseen one, else [done].
  StoryPosition next(List<CafeStory> stories, Set<String> seen) {
    if (photo + 1 < stories[story].photos.length) {
      return StoryPosition(story, photo + 1);
    }
    return nextStory(stories, seen);
  }

  /// The previous photo: the person's previous one, else the previous
  /// person's last one. At the very first photo it stays (Instagram
  /// restarts it).
  StoryPosition previous(List<CafeStory> stories) {
    if (photo > 0) return StoryPosition(story, photo - 1);
    if (story > 0) {
      return StoryPosition(story - 1, stories[story - 1].photos.length - 1);
    }
    return StoryPosition(story, 0);
  }

  /// The next person, from their first unseen photo; [done] after the last.
  StoryPosition nextStory(List<CafeStory> stories, Set<String> seen) {
    if (story + 1 >= stories.length) {
      return StoryPosition(story, photo, done: true);
    }
    return StoryPosition(story + 1, stories[story + 1].startIndexFor(seen));
  }

  /// [index]'s person, swiped to: from their first unseen photo.
  static StoryPosition startOf(
    List<CafeStory> stories,
    int index,
    Set<String> seen,
  ) => StoryPosition(index, stories[index].startIndexFor(seen));

  @override
  List<Object?> get props => [story, photo, done];
}
