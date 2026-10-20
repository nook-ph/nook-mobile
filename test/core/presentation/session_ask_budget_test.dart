import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';

void main() {
  late SessionAskBudget budget;
  setUp(() => budget = SessionAskBudget());

  test('a pushed sheet spends it: no other sheet, no score ask, no survey', () {
    budget.spend(SessionAskKind.notificationPrePrompt);
    expect(budget.canShowSheet, isFalse);
    expect(budget.canShowScoreAsk, isFalse);
    expect(budget.claim(SessionAskKind.saverSurvey), isFalse);
    expect(budget.spentBy, SessionAskKind.notificationPrePrompt);
  });

  test('the survey claiming it spends it for every other sheet', () {
    expect(budget.claim(SessionAskKind.saverSurvey), isTrue);
    expect(budget.canShowSheet, isFalse);
    expect(budget.canShowScoreAsk, isFalse);
    expect(budget.spentBy, SessionAskKind.saverSurvey);
  });

  test('a sheet the person opened stops score asks and the survey only', () {
    budget.blockScoreAsks(SessionAskKind.pullSignIn);
    expect(budget.canShowScoreAsk, isFalse);
    expect(budget.canShowSheet, isTrue);
    expect(budget.claim(SessionAskKind.saverSurvey), isFalse);
    expect(budget.canShowSheet, isTrue);
  });

  test('an inline offer spends nothing but keeps the survey away', () {
    budget.noteShown(SessionAskKind.keepSavesCard);
    expect(budget.canShowSheet, isTrue);
    expect(budget.canShowScoreAsk, isTrue);
    expect(budget.anyShown, isTrue);
    expect(budget.claim(SessionAskKind.saverSurvey), isFalse);
  });

  test('a failed claim spends nothing', () {
    budget.noteShown(SessionAskKind.homeLocationRow);
    budget.claim(SessionAskKind.saverSurvey);
    expect(budget.spentBy, isNull);
  });

  test('a new session (after the gap) makes it whole again', () {
    budget
      ..spend(SessionAskKind.signUpAsk)
      ..blockScoreAsks(SessionAskKind.directionsNudge)
      ..noteShown(SessionAskKind.keepSavesCard);
    budget.newSession();
    expect(budget.canShowSheet, isTrue);
    expect(budget.canShowScoreAsk, isTrue);
    expect(budget.anyShown, isFalse);
    expect(budget.claim(SessionAskKind.saverSurvey), isTrue);
  });
}
