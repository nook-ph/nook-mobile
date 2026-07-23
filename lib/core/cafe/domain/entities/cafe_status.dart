/// A user's universal status for a cafe, backed by the Been / Want to Try
/// system lists (`lists.list_type`). Been and Want to Try are mutually
/// exclusive per cafe — the server enforces this in `set_cafe_status`.
enum CafeStatus {
  been('been'),
  wantToTry('want_to_try'),
  none('none');

  const CafeStatus(this.wire);

  /// Value used by the `set_cafe_status` / `get_cafe_statuses` RPCs.
  final String wire;

  static CafeStatus fromWire(String? value) {
    return switch (value) {
      'been' => CafeStatus.been,
      'want_to_try' => CafeStatus.wantToTry,
      _ => CafeStatus.none,
    };
  }
}
