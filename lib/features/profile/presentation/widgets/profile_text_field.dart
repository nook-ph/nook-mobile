import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// Which border a [ProfileTextField] draws at rest.
enum ProfileFieldTone {
  /// A 1pt hairline that turns brand green while focused.
  normal,

  /// The 1.5pt brand border, focused or not.
  active,

  /// The 1.5pt red border.
  error,
}

/// A labelled field of the profile forms: a Medium 12 label (with an
/// optional count on the right), a 52 high radius 12 input, and one line
/// under it for [helper].
class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.counter,
    this.prefix,
    this.helper,
    this.tone = ProfileFieldTone.normal,
    this.enabled = true,
    this.locked = false,
    this.multiline = false,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLength,
    this.inputFormatters,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;

  /// "82/150", drawn on the label's row.
  final String? counter;

  /// Muted text before the value ("@").
  final String? prefix;

  /// The line under the field: a rule, a status or an error.
  final Widget? helper;
  final ProfileFieldTone tone;
  final bool enabled;

  /// Cannot be edited for now: tinted fill, muted text and a lock.
  final bool locked;

  /// A 112 high box that grows with its text instead of a single line.
  final bool multiline;
  final bool obscureText;
  final bool autofocus;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final count = counter;
    final lead = prefix;
    final below = helper;
    final rest = switch (tone) {
      ProfileFieldTone.normal => _border(ProfileTokens.border, 1),
      ProfileFieldTone.active => _border(ProfileTokens.brand, 1.5),
      ProfileFieldTone.error => _border(ProfileTokens.danger, 1.5),
    };
    final focused = tone == ProfileFieldTone.error
        ? rest
        : _border(ProfileTokens.brand, 1.5);
    final valueColor = locked ? ProfileTokens.muted : ProfileTokens.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ProfileTokens.text(12, weight: FontWeight.w500),
              ),
            ),
            if (count != null)
              Text(
                count,
                style: ProfileTokens.text(12, color: ProfileTokens.muted),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled && !locked,
          obscureText: obscureText,
          autofocus: autofocus,
          autocorrect: !obscureText,
          enableSuggestions: !obscureText,
          minLines: multiline ? 4 : 1,
          maxLines: multiline ? 6 : 1,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          cursorColor: ProfileTokens.brand,
          style: ProfileTokens.text(14, color: valueColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ProfileTokens.text(14, color: ProfileTokens.muted),
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: locked ? ProfileTokens.tint : ProfileTokens.surface,
            constraints: BoxConstraints(minHeight: multiline ? 112 : 52),
            // 15.5 above and below one 21 high line makes the 52 box.
            // Material 3 adds 4 between the box's edge (or an icon) and the
            // text, so 12 here is the design's 16.
            contentPadding: EdgeInsets.fromLTRB(
              lead == null ? 12 : 0,
              multiline ? 13 : 15.5,
              locked ? 0 : 12,
              multiline ? 13 : 15.5,
            ),
            prefixIcon: lead == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Text(
                      lead,
                      style: ProfileTokens.text(14, color: ProfileTokens.muted),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: locked
                ? const Padding(
                    padding: EdgeInsets.only(left: 4, right: 16),
                    child: Icon(
                      LucideIcons.lock,
                      size: 16,
                      color: ProfileTokens.muted,
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(),
            enabledBorder: rest,
            disabledBorder: _border(ProfileTokens.border, 1),
            focusedBorder: focused,
          ),
        ),
        if (below != null) ...[const SizedBox(height: 6), below],
      ],
    );
  }
}

/// How a [ProfileFieldHelper] line reads.
enum ProfileHelperKind { hint, busy, success, error }

/// The single line under a field: muted for a rule, with a spinner while
/// checking, green with a tick when good, red with an alert when not.
class ProfileFieldHelper extends StatelessWidget {
  const ProfileFieldHelper(
    this.text, {
    super.key,
    this.kind = ProfileHelperKind.hint,
  });

  final String text;
  final ProfileHelperKind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      ProfileHelperKind.hint || ProfileHelperKind.busy => ProfileTokens.muted,
      ProfileHelperKind.success => ProfileTokens.success,
      ProfileHelperKind.error => ProfileTokens.danger,
    };
    final Widget? icon = switch (kind) {
      ProfileHelperKind.hint => null,
      ProfileHelperKind.busy => ProfileSpinner(size: 14, color: color),
      ProfileHelperKind.success => Icon(
        LucideIcons.check,
        size: 14,
        color: color,
      ),
      ProfileHelperKind.error => Icon(
        LucideIcons.circleAlert,
        size: 14,
        color: color,
      ),
    };

    return Row(
      children: [
        if (icon != null) ...[icon, const SizedBox(width: 6)],
        Expanded(
          child: Text(text, style: ProfileTokens.text(12, color: color)),
        ),
      ],
    );
  }
}
