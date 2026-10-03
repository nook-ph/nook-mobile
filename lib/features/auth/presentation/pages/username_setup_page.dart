import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Asks the server whether a username is free. Swappable in tests.
typedef UsernameAvailabilityCheck = Future<bool> Function(String username);

Future<bool> _rpcUsernameAvailable(String username) async {
  final result = await Supabase.instance.client.rpc(
    'is_username_available',
    params: {'p_username': username},
  );
  return result as bool? ?? false;
}

/// Turns a full name into a starting handle ("Maria Cruz" → "maria_cruz").
String suggestUsername(String fullName) {
  final cleaned = fullName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
}

/// The format rules, in the order the user meets them. Null when [value] is
/// empty or passes.
String? validateUsername(String value) {
  if (value.isEmpty) return null;
  if (value.length < 3) return 'At least 3 characters';
  if (value.length > 20) return 'Max 20 characters';
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    return 'Only letters, numbers, and underscores';
  }
  if (ContentFilter.containsObjectionable(value)) {
    return 'This username is not allowed';
  }
  return null;
}

/// "Pick a username" (Figma C11–C16, F6). Also the first screen after Google
/// or Apple.
class UsernameSetupScreen extends StatefulWidget {
  final String? fullName;
  final String? avatarUrl;
  final UsernameAvailabilityCheck checkAvailability;

  const UsernameSetupScreen({
    super.key,
    this.fullName,
    this.avatarUrl,
    this.checkAvailability = _rpcUsernameAvailable,
  });

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  Timer? _debounce;
  String _lastValue = '';

  // null = untouched, true = available, false = taken
  bool? _isAvailable;
  bool _isChecking = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final name = widget.fullName?.trim();
    if (name != null && name.isNotEmpty) {
      _usernameController.text = suggestUsername(name);
    }
    _usernameController.addListener(_onUsernameChanged);
    // The suggestion is checked like anything typed, so a free one can be
    // confirmed straight away (C11 → C12 → C13).
    if (_usernameController.text.isNotEmpty) {
      _evaluate(_usernameController.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final value = _usernameController.text;
    if (value == _lastValue) return;
    setState(() => _evaluate(value));
  }

  void _evaluate(String value) {
    _lastValue = value;
    _isAvailable = null;
    _isChecking = false;
    _debounce?.cancel();

    _validationError = validateUsername(value);
    if (_validationError != null || value.isEmpty) return;

    _isChecking = true;
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    try {
      final available = await widget.checkAvailability(username);
      if (!mounted || username != _usernameController.text) return;
      setState(() {
        _isAvailable = available;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAvailable = null;
        _isChecking = false;
      });
    }
  }

  bool get _canSubmit {
    return _isAvailable == true &&
        _validationError == null &&
        !_isChecking &&
        _usernameController.text.isNotEmpty;
  }

  void _onConfirmPressed() {
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthBloc>().add(
      AuthUsernameSetEvent(_usernameController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.fullName?.trim().split(' ').first ?? '';

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          finishSignIn(context);
          return;
        }
        if (state is AuthError) {
          final msg = state.message.toLowerCase();
          if (msg.contains('already taken')) {
            setState(() => _isAvailable = false);
          }
          showAuthToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is AuthLoading;
        final username = _usernameController.text;

        return AuthPage(
          children: [
            AuthHeader(
              title: 'Pick a username',
              subtitle: firstName.isNotEmpty
                  ? 'Welcome, $firstName! Choose a unique handle.'
                  : 'This is how other people will find you.',
            ),
            AuthTextField(
              controller: _usernameController,
              hintText: 'username',
              prefixText: '@',
              errorText: _validationError,
              helperText: _hasStatus
                  ? null
                  : 'Letters, numbers, and underscores only. 3–20 characters.',
              accentColor: isSubmitting ? null : _accentColor(username),
              autofocus: true,
              enabled: !isSubmitting,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newUsername],
              onSubmitted: (_) {
                if (_canSubmit && !isSubmitting) _onConfirmPressed();
              },
              trailing: _statusIcon(),
            ),
            ?_statusPill(username),
            AuthPrimaryButton(
              label: 'Confirm username',
              loading: isSubmitting,
              loadingLabel: 'Saving…',
              onPressed: _canSubmit ? _onConfirmPressed : null,
            ),
          ],
        );
      },
    );
  }

  /// True once the field reports checking, available or taken; the pill then
  /// takes the helper's place.
  bool get _hasStatus =>
      _validationError == null && (_isChecking || _isAvailable != null);

  Color? _accentColor(String username) {
    if (username.isEmpty || _validationError != null) return null;
    if (_isAvailable == true) return AuthColors.success;
    if (_isAvailable == false) return AuthColors.danger;
    return null;
  }

  Widget? _statusIcon() {
    if (_validationError != null) return null;
    if (_isChecking) return const AuthSpinner();
    if (_isAvailable == true) {
      return const Icon(
        LucideIcons.circleCheck,
        size: 18,
        color: AuthColors.success,
      );
    }
    if (_isAvailable == false) {
      return const Icon(
        LucideIcons.circleAlert,
        size: 18,
        color: AuthColors.danger,
      );
    }
    return null;
  }

  Widget? _statusPill(String username) {
    if (!_hasStatus) return null;
    if (_isChecking) return const AuthStatusPill.checking();
    if (_isAvailable == true) {
      return AuthStatusPill.available(label: '@$username is available!');
    }
    return AuthStatusPill.unavailable(label: '@$username is already taken.');
  }
}
