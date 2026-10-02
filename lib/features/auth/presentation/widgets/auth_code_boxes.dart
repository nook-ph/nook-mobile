import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

/// How many digits the signup verification code has.
///
/// This is the project's Supabase Auth "Email OTP length" setting. The value
/// here follows the note in `nook-supabase/supabase/config.toml` ("6-digit OTP
/// code") and Supabase's default. If that dashboard setting is ever changed,
/// change this one constant with it: the boxes, the paste handling and the
/// Verify button all read it.
const int kSignupOtpLength = 6;

/// Keeps only the digits of [raw] and cuts them to [length], so a pasted
/// "Your code is 482913" or an autofilled code with spaces lands cleanly.
String sanitizeAuthCode(String raw, {int length = kSignupOtpLength}) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length <= length ? digits : digits.substring(0, length);
}

/// Applies [sanitizeAuthCode] to everything typed, pasted or autofilled.
class AuthCodeFormatter extends TextInputFormatter {
  const AuthCodeFormatter({this.length = kSignupOtpLength});

  final int length;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = sanitizeAuthCode(newValue.text, length: length);
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

/// The verification code as a row of boxes, one digit each.
///
/// One real text field sits invisibly over the row and owns the input, so
/// typing, backspace, paste and one-time-code autofill all behave as they do
/// in any field; the boxes only draw what it holds. Tapping anywhere on the
/// row focuses it.
class AuthCodeBoxes extends StatefulWidget {
  const AuthCodeBoxes({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = kSignupOtpLength,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.onChanged,
    this.onCompleted,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final bool hasError;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Called once each time the last box is filled.
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onSubmitted;

  static const double boxHeight = 56;
  static const double gap = 8;

  @override
  State<AuthCodeBoxes> createState() => _AuthCodeBoxesState();
}

class _AuthCodeBoxesState extends State<AuthCodeBoxes> {
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(AuthCodeBoxes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_rebuild);
      _focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final focused = _focusNode.hasFocus && widget.enabled;
    // The box the next digit goes into. None once the code is complete.
    final activeIndex = focused && code.length < widget.length
        ? code.length
        : -1;

    return Semantics(
      label: 'Verification code, ${widget.length} digits',
      textField: true,
      value: code,
      child: SizedBox(
        height: AuthCodeBoxes.boxHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: AuthCodeBoxes.gap),
                    Expanded(
                      child: _CodeBox(
                        key: ValueKey('auth-code-box-$i'),
                        digit: i < code.length ? code[i] : null,
                        active: i == activeIndex,
                        hasError: widget.hasError,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // The real input. Its text, caret and decoration are invisible;
            // it is on top so a tap focuses it and a long press offers Paste.
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              // Lets Android and iOS offer the code straight from the
              // notification instead of making the user switch to mail.
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [AuthCodeFormatter(length: widget.length)],
              onChanged: _handleChanged,
              onSubmitted: widget.onSubmitted,
              showCursor: false,
              enableSuggestions: false,
              autocorrect: false,
              expands: true,
              maxLines: null,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    super.key,
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String? digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final Color stroke;
    final double width;
    if (hasError) {
      stroke = AuthColors.danger;
      width = 1.5;
    } else if (active) {
      stroke = AuthColors.ink;
      width = 1.5;
    } else {
      stroke = AuthColors.border;
      width = 1;
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AuthTextField.radius),
        border: Border.all(color: stroke, width: width),
      ),
      child: digit != null
          ? Text(digit!, style: AuthText.title.copyWith(fontSize: 20))
          : active
          // Stands in for the caret the hidden field does not draw.
          ? Container(width: 2, height: 22, color: AuthColors.brand)
          : null,
    );
  }
}
