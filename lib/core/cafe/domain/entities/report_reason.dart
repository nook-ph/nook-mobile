/// User-selectable reasons for reporting a review.
///
/// [code] maps 1:1 to the `review_reports.reason_code` CHECK constraint in the
/// database; [label] is the friendly text shown in the report sheet. Keep these
/// codes in sync with the backend enum and the nook-admin moderation queue.
enum ReportReason {
  inappropriateContent('inappropriate_content', 'Inappropriate or offensive'),
  harassment('harassment', 'Harassment or bullying'),
  hateSpeech('hate_speech', 'Hate speech'),
  spam('spam', 'Spam or advertising'),
  fakeReview('fake_review', 'Fake or misleading'),
  impersonation('impersonation', 'Impersonation'),
  privacyViolation('privacy_violation', 'Privacy violation'),
  offTopic('off_topic', 'Off-topic / not about the cafe'),
  other('other', 'Something else');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;
}
