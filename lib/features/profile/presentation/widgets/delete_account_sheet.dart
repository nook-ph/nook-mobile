import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_text_field.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';

/// Confirms deleting the account. Email accounts confirm with their
/// password ([isEmailUser]); Google and Apple accounts type DELETE.
///
/// Sends [AuthDeleteAccountEvent] itself and stays open while it runs. A
/// failure is shown under the field; success closes the sheet.
class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key, required this.isEmailUser});

  final bool isEmailUser;

  static const confirmWord = 'DELETE';
  static const warning =
      'This will permanently delete your account and all associated data, '
      'including your reviews, lists, and saved cafes. This cannot be undone.';

  static Future<void> show(BuildContext context, {required bool isEmailUser}) {
    return ProfileSheet.show<void>(
      context,
      builder: (_) => DeleteAccountSheet(isEmailUser: isEmailUser),
    );
  }

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  final TextEditingController _inputController = TextEditingController();
  bool _isSubmitting = false;
  bool _closed = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    final value = _inputController.text.trim();
    if (widget.isEmailUser) {
      return value.isNotEmpty;
    }
    return value == DeleteAccountSheet.confirmWord;
  }

  void _onSubmit() {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final password = widget.isEmailUser ? _inputController.text : null;
    context.read<AuthBloc>().add(AuthDeleteAccountEvent(password: password));
  }

  void _onAuthState(BuildContext context, AuthState state) {
    if (!_isSubmitting || _closed || state is AuthLoading) return;
    if (state is AuthError) {
      setState(() {
        _isSubmitting = false;
        _error = state.message;
      });
      return;
    }
    if (state is AuthAccountDeleted || state is AuthUnauthenticated) {
      _closed = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.isEmailUser;
    final error = _error;

    return BlocListener<AuthBloc, AuthState>(
      listener: _onAuthState,
      child: PopScope(
        // The request cannot be taken back, so the sheet stays until it
        // answers.
        canPop: !_isSubmitting,
        child: ProfileSheet(
          title: 'Delete account?',
          gap: 12,
          onClose: _isSubmitting ? () {} : null,
          children: [
            Text(
              DeleteAccountSheet.warning,
              style: ProfileTokens.text(14, color: ProfileTokens.muted),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ProfileTextField(
                label: isEmail
                    ? 'Enter your password to confirm:'
                    : 'Type DELETE in capitals to confirm:',
                hint: isEmail ? 'Password' : DeleteAccountSheet.confirmWord,
                controller: _inputController,
                obscureText: isEmail,
                autofocus: true,
                enabled: !_isSubmitting,
                tone: error == null
                    ? ProfileFieldTone.normal
                    : ProfileFieldTone.error,
                helper: error == null
                    ? null
                    : ProfileFieldHelper(error, kind: ProfileHelperKind.error),
                textInputAction: TextInputAction.done,
                textCapitalization: isEmail
                    ? TextCapitalization.none
                    : TextCapitalization.characters,
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _onSubmit(),
                inputFormatters: isEmail
                    ? const []
                    : [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                        _UpperCaseFormatter(),
                      ],
              ),
            ),
            // The 4 spacer the design keeps between two 12 gaps.
            const SizedBox(height: 4),
            ProfileSheetButtons(
              onCancel: _isSubmitting ? null : () => Navigator.pop(context),
              confirmLabel: 'Delete account',
              onConfirm: _canSubmit ? _onSubmit : null,
              destructive: true,
              busy: _isSubmitting,
              busyLabel: 'Deleting…',
            ),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
