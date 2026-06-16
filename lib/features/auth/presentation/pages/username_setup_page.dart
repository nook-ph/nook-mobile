import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/toast_helper.dart';

class UsernameSetupScreen extends StatefulWidget {
  final String? fullName;
  final String? avatarUrl;

  const UsernameSetupScreen({super.key, this.fullName, this.avatarUrl});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  Timer? _debounce;

  // null = untouched, true = available, false = taken
  bool? _isAvailable;
  bool _isChecking = false;
  String? _validationError;

  static const _green = Color(0xFF344E41);
  static const _grey = Color(0xFFA8AAAA);
  static const _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    if (widget.fullName != null && widget.fullName!.trim().isNotEmpty) {
      final suggestion = _suggestUsername(widget.fullName!);
      _usernameController.text = suggestion;
    }
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    super.dispose();
  }

  String _suggestUsername(String fullName) {
    final cleaned = fullName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
  }

  void _onUsernameChanged() {
    final value = _usernameController.text;

    setState(() {
      _isAvailable = null;
      _isChecking = false;
      _validationError = null;
    });

    _debounce?.cancel();

    final error = _validate(value);
    if (error != null) {
      setState(() => _validationError = error);
      return;
    }

    if (value.isEmpty) return;

    setState(() => _isChecking = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'is_username_available',
        params: {'p_username': username},
      );

      if (!mounted) return;
      setState(() {
        _isAvailable = result as bool? ?? false;
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

  String? _validate(String value) {
    if (value.isEmpty) return null;
    if (value.length < 3) return 'At least 3 characters';
    if (value.length > 20) return 'Max 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Only letters, numbers, and underscores';
    }
    return null;
  }

  bool get _canSubmit {
    return _isAvailable == true &&
        _validationError == null &&
        !_isChecking &&
        _usernameController.text.isNotEmpty;
  }

  void _onConfirmPressed(BuildContext context) {
    context.read<AuthBloc>().add(
      AuthUsernameSetEvent(_usernameController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = _usernameController.text;
    final hasInput = username.isNotEmpty;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
          return;
        }
        if (state is AuthError) {
          final msg = state.message.toLowerCase();
          if (msg.contains('already taken')) {
            setState(() => _isAvailable = false);
          }
          showPrimaryToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is AuthLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Gap(40),
                  Column(
                    children: [
                      Image.asset('assets/logos/logoT.png', width: 110),
                      const Gap(22),
                      Text(
                        'Pick a username',
                        style: context.textTheme.titleLargeSemi,
                      ),
                      const Gap(8),
                      Text(
                        widget.fullName != null
                            ? 'Welcome, ${widget.fullName!.split(' ').first}! Choose a unique handle.'
                            : 'This is how other people will find you.',
                        style: context.textTheme.bodySmall!.copyWith(color: _grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const Gap(32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_canSubmit && !isSubmitting) {
                            _onConfirmPressed(context);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'username',
                          hintStyle: context.textTheme.bodySmall!.copyWith(
                            color: _grey,
                          ),
                          prefixText: '@',
                          prefixStyle: context.textTheme.bodySmallMed.copyWith(
                            color: Colors.black87,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _fieldBorderColor(hasInput),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _fieldBorderColor(hasInput, focused: true),
                            ),
                          ),
                          suffixIcon: _buildSuffixIcon(isSubmitting),
                        ),
                      ),
                      const Gap(8),
                      _buildStatusText(),
                      const Gap(12),
                      Text(
                        'Letters, numbers, and underscores only. 3\u201320 characters.',
                        style: context.textTheme.bodySmall!.copyWith(color: _grey),
                      ),
                      const Gap(32),
                      SizedBox(
                        width: double.infinity,
                        child: AdaptiveElevatedButton(
                          onPressed: _canSubmit && !isSubmitting
                              ? () => _onConfirmPressed(context)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            disabledBackgroundColor: _green.withOpacity(0.5),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white.withOpacity(
                              0.8,
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Confirm Username',
                                  style: context.textTheme.bodyLargeMed.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _fieldBorderColor(bool hasInput, {bool focused = false}) {
    if (!hasInput) return focused ? Colors.black87 : _border;
    if (_validationError != null) return Colors.red;
    if (_isAvailable == true) return _green;
    if (_isAvailable == false) return Colors.red;
    return focused ? Colors.black87 : _border;
  }

  Widget? _buildSuffixIcon(bool isSubmitting) {
    if (isSubmitting) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_grey),
          ),
        ),
      );
    }

    if (!_usernameController.text.isNotEmpty) return null;

    if (_isChecking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_grey),
          ),
        ),
      );
    }

    if (_validationError != null) {
      return const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle_rounded, color: _green, size: 20);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
    }

    return null;
  }

  Widget _buildStatusText() {
    if (_validationError != null) {
      return Text(
        _validationError!,
        style: context.textTheme.bodySmall!.copyWith(color: Colors.red),
      );
    }
    if (_isChecking) {
      return Text(
        'Checking availability...',
        style: context.textTheme.bodySmall!.copyWith(color: _grey),
      );
    }
    if (_isAvailable == true) {
      return Text(
        '@${_usernameController.text} is available!',
        style: context.textTheme.bodySmall!.copyWith(color: _green),
      );
    }
    if (_isAvailable == false) {
      return Text(
        '@${_usernameController.text} is already taken.',
        style: context.textTheme.bodySmall!.copyWith(color: Colors.red),
      );
    }
    return const SizedBox.shrink();
  }
}
