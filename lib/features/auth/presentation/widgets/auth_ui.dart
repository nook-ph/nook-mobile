import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:toastification/toastification.dart';

/// Shared pieces of the auth and onboarding screens, built from the
/// "Auth & onboarding — redesign" section in Figma (node 1605:9332): one input
/// style, one primary button, the page shell every step uses, the status pill,
/// the checkbox and the toast.

class AuthColors {
  const AuthColors._();

  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF868584);
  static const brand = Color(0xFF344E41);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);
  static const danger = Color(0xFFB3261E);
  static const dangerTint = Color(0xFFFBEAE9);
  static const success = Color(0xFF0F893E);
  static const successTint = Color(0xFFE7F4EC);
  static const tint = Color(0xFFEEEEEE);

  /// Stroke of the unticked terms checkbox.
  static const checkbox = Color(0xFFC4C4C4);
}

/// Poppins at the sizes the auth frames use. Figma's "auto" line height for
/// Poppins is 1.5 (24 → 36, 14 → 21, 12 → 18); Flutter's default for the
/// font is shorter, so it is set explicitly.
class AuthText {
  const AuthText._();

  static const _family = 'Poppins';
  static const _height = 1.5;

  /// Onboarding headline.
  static const display = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AuthColors.ink,
  );

  /// Page title on every auth step.
  static const title = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AuthColors.ink,
  );

  /// Title of the centred state pages (signed out, offline).
  static const stateTitle = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AuthColors.ink,
  );

  static const body = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AuthColors.muted,
  );

  static const bodyStrong = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AuthColors.ink,
  );

  static const input = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AuthColors.ink,
  );

  static const label = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AuthColors.ink,
  );

  static const small = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AuthColors.muted,
  );

  static const button = TextStyle(
    fontFamily: _family,
    height: _height,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AuthColors.surface,
  );
}

/// Horizontal page padding on every auth screen.
const double authGutter = 24;

/// Space between the blocks of an auth page body.
const double authBodyGap = 16;

/// Gap kept above the bottom safe area by pinned actions and the toast.
const double authBottomGap = 16;

/// The lucide loader, turning. Stands in for the "lucide/spin" icon the
/// loading states use.
class AuthSpinner extends StatefulWidget {
  const AuthSpinner({super.key, this.size = 18, this.color = AuthColors.muted});

  final double size;
  final Color color;

  @override
  State<AuthSpinner> createState() => _AuthSpinnerState();
}

class _AuthSpinnerState extends State<AuthSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          LucideIcons.loaderCircle,
          size: widget.size,
          color: widget.color,
        ),
      ),
    );
  }
}

/// The one text field every auth form uses.
///
/// 52 high, 12 radius, a Medium 12 label 6 above, and a line 6 underneath:
/// the error when [errorText] is set, otherwise [helperText]. [accentColor]
/// overrides the stroke for states the field itself reports (username
/// available).
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.helperText,
    this.helperColor,
    this.accentColor,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.prefixText,
    this.trailing,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final Color? helperColor;
  final Color? accentColor;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;

  /// Sits at the trailing edge inside the field (clear, eye, status icon).
  final Widget? trailing;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const double height = 52;
  static const double radius = 12;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final heading = label;
    final error = errorText;
    final helper = helperText;
    final accent = accentColor;

    final OutlineInputBorder resting;
    final OutlineInputBorder focused;
    if (error != null) {
      resting = focused = _border(AuthColors.danger, 1.5);
    } else if (accent != null) {
      resting = focused = _border(accent, 1.5);
    } else {
      resting = _border(AuthColors.border, 1);
      focused = _border(AuthColors.ink, 1.5);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null) ...[
          Text(heading, style: AuthText.label),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          cursorColor: AuthColors.brand,
          cursorWidth: 2,
          cursorHeight: 20,
          style: AuthText.input,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AuthText.input.copyWith(color: AuthColors.muted),
            prefixIcon: prefixText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 4),
                    child: Text(
                      prefixText!,
                      style: AuthText.input.copyWith(color: AuthColors.muted),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            suffixIcon: trailing == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 8, right: 16),
                    child: trailing,
                  ),
            suffixIconConstraints: const BoxConstraints(),
            isDense: true,
            filled: true,
            fillColor: AuthColors.surface,
            constraints: const BoxConstraints(minHeight: height),
            // 16 from each edge; a prefix or trailing icon brings its own
            // 16 at the edge and the 4 / 8 gap to the text instead.
            contentPadding: EdgeInsets.fromLTRB(
              prefixText == null ? 16 : 0,
              15.5,
              trailing == null ? 16 : 0,
              15.5,
            ),
            enabledBorder: resting,
            disabledBorder: resting,
            focusedBorder: focused,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          AuthErrorLine(message: error),
        ] else if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: AuthText.small.copyWith(
              color: helperColor ?? AuthColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// The message under a field in error: 14 alert icon, 6 gap, Regular 12.
class AuthErrorLine extends StatelessWidget {
  const AuthErrorLine({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(LucideIcons.circleAlert, size: 14, color: AuthColors.danger),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: AuthText.small.copyWith(color: AuthColors.danger),
          ),
        ),
      ],
    );
  }
}

/// A small tappable icon inside a field (clear, show or hide password).
class AuthFieldIconButton extends StatelessWidget {
  const AuthFieldIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(icon, size: size, color: AuthColors.muted),
          ),
        ),
      ),
    );
  }
}

/// The eye that shows or hides a password (20, muted).
class AuthPasswordToggle extends StatelessWidget {
  const AuthPasswordToggle({
    super.key,
    required this.obscured,
    required this.onTap,
  });

  final bool obscured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuthFieldIconButton(
      icon: obscured ? LucideIcons.eyeOff : LucideIcons.eye,
      semanticLabel: obscured ? 'Show password' : 'Hide password',
      onTap: onTap,
    );
  }
}

/// The "x" that empties a field (16, muted).
class AuthClearButton extends StatelessWidget {
  const AuthClearButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuthFieldIconButton(
      icon: LucideIcons.x,
      size: 16,
      semanticLabel: 'Clear',
      onTap: onTap,
    );
  }
}

/// Full-width primary action: 52 high pill in brand green, Medium 14. The
/// same pill at 40% when it cannot be used yet, and an 18 spinner 8 before
/// [loadingLabel] while the request is running.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.4,
        child: AdaptiveTap(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: height,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuthColors.brand,
              borderRadius: BorderRadius.circular(100),
            ),
            child: loading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AuthSpinner(color: AuthColors.surface),
                      const SizedBox(width: 8),
                      Text(loadingLabel ?? label, style: AuthText.button),
                    ],
                  )
                : Text(label, style: AuthText.button),
          ),
        ),
      ),
    );
  }
}

/// Full-width outlined pill (Google, Apple, Try again): 52 high, 1px border,
/// 18 icon 8 before the label. The spinner takes the icon's place while that
/// provider is signing in.
class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.4,
        child: AdaptiveTap(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: 52,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuthColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AuthColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading) const AuthSpinner() else ?icon,
                if (loading || icon != null) const SizedBox(width: 8),
                Text(
                  label,
                  style: AuthText.button.copyWith(color: AuthColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A text action, Medium 14 ("Forgot password?", "Didn't get a code? Resend").
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AuthColors.brand,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Text(
        label,
        style: AuthText.button.copyWith(
          color: onTap == null ? AuthColors.muted : color,
        ),
      ),
    );
  }
}

/// The back arrow in the 48 nav row: lucide arrow-left, 22, ink.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Icon(LucideIcons.arrowLeft, size: 22, color: AuthColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Title (SemiBold 24), then one line of context 6 below (Regular 14 muted),
/// left-aligned, with 8 below the block. [emphasis] is set in Medium ink after
/// [subtitle] ("Welcome back, maria@…").
class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.emphasis,
    this.emphasisOnNewLine = false,
  });

  final String title;
  final String? subtitle;
  final String? emphasis;
  final bool emphasisOnNewLine;

  @override
  Widget build(BuildContext context) {
    final line = subtitle;
    final strong = emphasis;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuthText.title),
          if (line != null) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                style: AuthText.body,
                children: [
                  TextSpan(text: line),
                  if (strong != null && strong.isNotEmpty)
                    TextSpan(
                      text: emphasisOnNewLine ? '\n$strong' : ' $strong',
                      style: AuthText.bodyStrong,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The scaffold for an auth step: white page, a 48 nav row with an optional
/// back arrow, and a left-aligned column 24 from the sides with
/// [authBodyGap] between its blocks.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.children,
    this.onBack,
    this.footer,
    this.topPadding = 12,
    this.gap = authBodyGap,
  });

  final List<Widget> children;

  /// Null hides the back arrow (username setup, password recovery).
  final VoidCallback? onBack;

  /// Pinned to the bottom of the page, [authBottomGap] above the safe area.
  final Widget? footer;

  /// Space between the nav row and the first block (12; 28 on the entry
  /// screen, 40 on the "Check your email" screen).
  final double topPadding;

  final double gap;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return Scaffold(
      backgroundColor: AuthColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: back == null ? null : AuthBackButton(onTap: back),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  authGutter,
                  topPadding,
                  authGutter,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: children,
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  authGutter,
                  0,
                  authGutter,
                  authBottomGap,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// A status under the username field: checking, available, taken. 30 high
/// pill, 6/12 padding, 14 icon 6 before a Medium 12 label.
class AuthStatusPill extends StatelessWidget {
  const AuthStatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
    this.busy = false,
  });

  const AuthStatusPill.checking({Key? key})
    : this(
        key: key,
        label: 'Checking availability…',
        color: AuthColors.muted,
        background: AuthColors.tint,
        busy: true,
      );

  const AuthStatusPill.available({Key? key, required String label})
    : this(
        key: key,
        label: label,
        color: AuthColors.success,
        background: AuthColors.successTint,
        icon: LucideIcons.circleCheck,
      );

  const AuthStatusPill.unavailable({Key? key, required String label})
    : this(
        key: key,
        label: label,
        color: AuthColors.danger,
        background: AuthColors.dangerTint,
        icon: LucideIcons.circleAlert,
      );

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              AuthSpinner(size: 14, color: color)
            else if (icon != null)
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, style: AuthText.label.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The terms checkbox: 20 square, 6 radius. Unticked is a 1.5 grey stroke;
/// ticked is filled brand green with a 14 white check.
class AuthCheckbox extends StatelessWidget {
  const AuthCheckbox({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? AuthColors.brand : null,
            borderRadius: BorderRadius.circular(6),
            border: value
                ? null
                : Border.all(color: AuthColors.checkbox, width: 1.5),
          ),
          child: value
              ? const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: AuthColors.surface,
                )
              : null,
        ),
      ),
    );
  }
}

/// The agreement under the email field: checkbox, 10 gap, Regular 12 muted
/// with the two documents as Medium brand underlined links.
class AuthTermsAgreement extends StatelessWidget {
  const AuthTermsAgreement({
    super.key,
    required this.value,
    required this.onChanged,
    required this.eulaRecognizer,
    required this.privacyRecognizer,
    this.showNudge = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final GestureRecognizer eulaRecognizer;
  final GestureRecognizer privacyRecognizer;

  /// Set after someone taps a button that the unticked box keeps disabled,
  /// so the reason is said instead of the button just not responding.
  final bool showNudge;

  @override
  Widget build(BuildContext context) {
    final link = AuthText.small.copyWith(
      color: AuthColors.brand,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: AuthColors.brand,
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthCheckbox(value: value, onChanged: onChanged),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(
                style: AuthText.small,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Use (EULA)',
                    style: link,
                    recognizer: eulaRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: link,
                    recognizer: privacyRecognizer,
                  ),
                  const TextSpan(
                    text:
                        '. Nook has zero tolerance for objectionable content '
                        'and abusive behavior.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    if (!showNudge || value) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            'Tick the box to agree before you continue.',
            style: AuthText.small.copyWith(color: AuthColors.danger),
          ),
        ),
      ],
    );
  }
}

/// "—— or ——": 1px #E0E0E0 rules either side of Regular 12 muted, 12 gaps.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1, color: AuthColors.border)),
        const SizedBox(width: 12),
        Text('or', style: AuthText.small),
        const SizedBox(width: 12),
        const Expanded(child: Divider(height: 1, color: AuthColors.border)),
      ],
    );
  }
}

/// A 64 circle with a centred icon, for the state screens ("Check your
/// email", signed out, offline).
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({
    super.key,
    required this.icon,
    this.background = AuthColors.tint,
    this.color = AuthColors.brand,
    this.iconSize = 28,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: color),
    );
  }
}

/// The auth toast: a dark pill sized to its message, centred
/// [authBottomGap] above the safe area. 12/16 padding, 12 radius, a 16 icon
/// 8 before Medium 12 white. Errors carry the alert icon; [success] swaps in
/// the check. Replaces any toast already showing.
void showAuthToast(
  BuildContext context,
  String message, {
  bool success = false,
  Duration duration = const Duration(seconds: 3),
}) {
  dismissToasts();
  toastification.showCustom(
    context: context,
    alignment: Alignment.bottomCenter,
    autoCloseDuration: duration,
    animationDuration: const Duration(milliseconds: 200),
    animationBuilder: (context, animation, alignment, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    // toastification already keeps 12 below a bottom toast; 4 more makes 16.
    builder: (context, holder) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Center(
        child: AuthToast(message: message, success: success),
      ),
    ),
  );
}

/// The toast body on its own, so it can be laid out and tested without an
/// overlay.
class AuthToast extends StatelessWidget {
  const AuthToast({super.key, required this.message, this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AuthColors.ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            success ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 16,
            color: AuthColors.surface,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AuthText.label.copyWith(color: AuthColors.surface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimum password length on sign-up.
const int kSignupPasswordMinLength = 8;

/// Minimum password length on change password: the same rule as sign-up
/// (Figma F11).
const int kChangePasswordMinLength = kSignupPasswordMinLength;

/// Shared by every auth form that takes an email.
bool isValidAuthEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

/// The helper under a new-password field: shown while the field is empty or
/// focused, green once [minLength] is met (sign-up C3), hidden otherwise
/// (C4, D8). Returns null when it should not show.
({String text, Color color})? passwordHelper({
  required String value,
  required bool focused,
  required int minLength,
}) {
  if (value.isNotEmpty && !focused) return null;
  return (
    text: 'At least $minLength characters',
    color: value.length >= minLength ? AuthColors.success : AuthColors.muted,
  );
}
