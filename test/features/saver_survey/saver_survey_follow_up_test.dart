import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_follow_up.dart';

void main() {
  const named = CafeSnapshot(
    id: 'b',
    name: 'Brew Szn',
    lat: 10.32,
    lng: 123.90,
  );
  const near = CafeSnapshot(id: 'n', name: 'Near', lat: 10.3001, lng: 123.9001);
  const noCoords = CafeSnapshot(id: 'x', name: 'Nowhere');
  const here = (lat: 10.3, lng: 123.9);

  SaverSurveyFollowUp? pick(
    List<String> reasons, {
    CafeSnapshot? cafe = named,
    ({double lat, double lng})? position,
    bool canAsk = false,
  }) => SaverSurveyFollowUps.pick(
    reasons: reasons,
    cafe: cafe,
    saves: const [named, near, noCoords],
    position: position,
    canAskLocation: canAsk,
  );

  test('one card per pick', () {
    expect(pick(['unsure_open'])!.kind, SaverSurveyFollowUpKind.openState);
    expect(pick(['unsure_open'])!.cafe, named);
    expect(pick(['waiting_for_friend'])!.kind, SaverSurveyFollowUpKind.share);
    expect(pick(['saving_for_later'])!.kind, SaverSurveyFollowUpKind.later);
  });

  test('no card for no time, found elsewhere, something else', () {
    expect(pick(['no_time']), isNull);
    expect(pick(['found_elsewhere', 'other']), isNull);
  });

  test('priority with two picks: open state, far, friend, later', () {
    expect(
      pick(['saving_for_later', 'unsure_open'])!.kind,
      SaverSurveyFollowUpKind.openState,
    );
    expect(
      pick(['too_far', 'unsure_open'], position: here)!.kind,
      SaverSurveyFollowUpKind.openState,
    );
    expect(
      pick(['waiting_for_friend', 'too_far'], position: here)!.kind,
      SaverSurveyFollowUpKind.nearest,
    );
    expect(
      pick(['saving_for_later', 'waiting_for_friend'])!.kind,
      SaverSurveyFollowUpKind.share,
    );
    expect(
      pick(['no_time', 'saving_for_later'])!.kind,
      SaverSurveyFollowUpKind.later,
    );
  });

  test('a pick that cannot be answered falls through to the next', () {
    // No cafe known: open state and share have nothing to show.
    expect(
      pick(['unsure_open', 'saving_for_later'], cafe: null)!.kind,
      SaverSurveyFollowUpKind.later,
    );
    // Too far with no position and no way to ask.
    expect(
      pick(['too_far', 'waiting_for_friend'])!.kind,
      SaverSurveyFollowUpKind.share,
    );
    expect(pick(['too_far']), isNull);
  });

  test('too far: the nearest save with coordinates', () {
    final card = pick(['too_far'], position: here)!;
    expect(card.kind, SaverSurveyFollowUpKind.nearest);
    expect(card.cafe, near);
    expect(card.distanceMeters, closeTo(15.6, 1));
  });

  test('too far without a position: ask when the ask is allowed', () {
    expect(
      pick(['too_far'], canAsk: true)!.kind,
      SaverSurveyFollowUpKind.locationAsk,
    );
  });

  test('too far: no ask when no save has coordinates to measure to', () {
    expect(
      SaverSurveyFollowUps.pick(
        reasons: const ['too_far', 'saving_for_later'],
        cafe: noCoords,
        saves: const [noCoords],
        position: null,
        canAskLocation: true,
      )!.kind,
      SaverSurveyFollowUpKind.later,
    );
  });

  test('nearest is null when no save has coordinates', () {
    expect(SaverSurveyFollowUps.nearest(const [noCoords], here), isNull);
  });

  test('kind wire names', () {
    expect(SaverSurveyFollowUpKind.values.map((k) => k.wire), [
      'open_state',
      'nearest',
      'location_ask',
      'share',
      'later',
    ]);
  });
}
