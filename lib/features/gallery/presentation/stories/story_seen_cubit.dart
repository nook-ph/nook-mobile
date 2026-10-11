import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which community photos this device has watched as a story. Kept on the
/// device only: it decides a ring's colour, nothing anyone else sees.
abstract interface class StorySeenStore {
  Future<Set<String>> load();
  Future<void> save(Set<String> seen);
}

/// [StorySeenStore] in SharedPreferences, newest last, capped at [cap] ids
/// so it cannot grow without end; the oldest fall off first.
class PrefsStorySeenStore implements StorySeenStore {
  const PrefsStorySeenStore({this.cap = 500});

  static const key = 'cafe_story_seen_v1';
  final int cap;

  @override
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(key)};
  }

  @override
  Future<void> save(Set<String> seen) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = seen.toList();
    await prefs.setStringList(
      key,
      ids.length <= cap ? ids : ids.sublist(ids.length - cap),
    );
  }
}

/// The seen photo ids, shared by the tray and the viewer it opens, so a
/// ring turns grey the moment its last photo has been shown.
class StorySeenCubit extends Cubit<Set<String>> {
  StorySeenCubit({StorySeenStore store = const PrefsStorySeenStore()})
    : _store = store,
      super(const {});

  final StorySeenStore _store;

  Future<void> load() async {
    try {
      final seen = await _store.load();
      if (isClosed) return;
      // Anything marked while the read was on its way stays marked.
      emit(Set.unmodifiable({...seen, ...state}));
    } catch (e) {
      debugPrint('[StorySeen] load failed: $e');
    }
  }

  /// Marks [photoId] seen and saves. A repeat does nothing.
  Future<void> markSeen(String photoId) async {
    if (state.contains(photoId) || isClosed) return;
    // Insertion order is age order, which is what the cap trims by.
    final next = Set<String>.unmodifiable({...state, photoId});
    emit(next);
    try {
      await _store.save(next);
    } catch (e) {
      debugPrint('[StorySeen] save failed: $e');
    }
  }
}
