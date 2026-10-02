import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/compressed_image_target.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/bloc/avatar_upload_event.dart';
import 'package:nook/features/profile/bloc/avatar_upload_state.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_text_field.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Edit profile: photo, name, username and bio on one page, with Save
/// pinned to the bottom and dimmed until there is something valid to save.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.checkUsername, this.pickPhoto});

  /// Whether a username is free: true, false, or null when the check could
  /// not be made. Defaults to the `is_username_available` RPC.
  final Future<bool?> Function(String username)? checkUsername;

  /// Picks the new photo from the library; null when the user backs out.
  /// Defaults to the system picker, compressed for upload.
  final Future<File?> Function()? pickPhoto;

  static const bioMaxLength = 150;
  static const usernameRules =
      '3–20 characters. Letters, numbers and underscores.';
  static const savedMessage = 'Changes saved!';

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  // What is saved, to tell whether anything has changed.
  String _savedName = '';
  String _savedUsername = '';
  String _savedBio = '';

  // Username validation state
  Timer? _debounce;
  bool? _isAvailable;
  bool _isChecking = false;
  String? _validationError;

  /// Days until the username can change again; 0 when it can change now.
  int _daysUntilUsernameUnlock = 0;

  File? _avatarFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded) {
      // "No name" is the page's label for an empty name, not text to edit.
      _savedName = editableName(profileState.name);
      _savedUsername = profileState.username;
      _savedBio = profileState.bio;
      _daysUntilUsernameUnlock = usernameCooldownDaysLeft(
        profileState.lastUsernameChange,
      );
    }

    _nameController = TextEditingController(text: _savedName);
    _usernameController = TextEditingController(text: _savedUsername);
    _bioController = TextEditingController(text: _savedBio);

    _nameController.addListener(_onTextChanged);
    _bioController.addListener(_onTextChanged);
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  // --- Username Logic ---
  void _onUsernameChanged() {
    final value = _usernameController.text.trim();
    _debounce?.cancel();

    if (value == _savedUsername) {
      setState(() {
        _isAvailable = true;
        _isChecking = false;
        _validationError = null;
      });
      return;
    }

    // Changing only the case of your own username: the availability check
    // would find your own row and call it taken.
    if (isCaseOnlyUsernameChange(value, _savedUsername)) {
      setState(() {
        _isAvailable = true;
        _isChecking = false;
        _validationError = validateUsername(value);
      });
      return;
    }

    final error = validateUsername(value);
    setState(() {
      _isAvailable = null;
      _validationError = error;
      _isChecking = error == null;
    });
    if (error != null) return;

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      await _checkAvailability(value);
    });
  }

  Future<void> _checkAvailability(String username) async {
    final check = widget.checkUsername ?? _rpcCheckUsername;
    bool? available;
    try {
      available = await check(username);
    } catch (_) {
      available = null;
    }
    // A slower answer for a name that has since been typed over is stale.
    if (!mounted || _usernameController.text.trim() != username) return;
    setState(() {
      _isAvailable = available;
      _isChecking = false;
    });
  }

  static Future<bool?> _rpcCheckUsername(String username) async {
    final result = await Supabase.instance.client.rpc(
      'is_username_available',
      params: {'p_username': username},
    );
    return result as bool? ?? false;
  }

  UsernameStatus get _usernameStatus {
    if (_daysUntilUsernameUnlock > 0) return UsernameStatus.locked;
    if (_usernameController.text.trim() == _savedUsername) {
      return UsernameStatus.unchanged;
    }
    if (_validationError != null) return UsernameStatus.invalid;
    if (_isChecking) return UsernameStatus.checking;
    return switch (_isAvailable) {
      true => UsernameStatus.available,
      false => UsernameStatus.taken,
      null => UsernameStatus.unknown,
    };
  }

  bool get _isDirty {
    return _avatarFile != null ||
        _nameController.text.trim() != _savedName.trim() ||
        _bioController.text.trim() != _savedBio.trim() ||
        _usernameController.text.trim() != _savedUsername;
  }

  /// A name that was there has been emptied. It cannot be saved as empty.
  bool get _nameCleared =>
      _nameController.text.trim().isEmpty && _savedName.trim().isNotEmpty;

  bool get _canSubmit {
    if (_saving || !_isDirty || _nameCleared) return false;
    return switch (_usernameStatus) {
      UsernameStatus.checking ||
      UsernameStatus.taken ||
      UsernameStatus.invalid => false,
      _ => true,
    };
  }

  // --- Avatar Logic ---
  static Future<File> _compressImage(File file) async {
    final filePath = file.path;
    // Named for the format it is written in, and never the source path
    // (which ".JPG" used to produce, and the compressor refuses).
    final target = compressedImageTarget(filePath);

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      target.path,
      quality: 80,
      minWidth: 512,
      minHeight: 512,
      format: target.isPng ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  static Future<File?> _pickFromLibrary() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) return null;
    return _compressImage(File(picked.path));
  }

  Future<void> _changePhoto() async {
    final fromLibrary = await ProfileSheet.show<bool>(
      context,
      builder: (_) => const ProfilePhotoSourceSheet(),
    );
    if (fromLibrary != true || !mounted) return;

    final File? file;
    try {
      file = await (widget.pickPhoto ?? _pickFromLibrary)();
    } catch (e) {
      // Denied photo access, an unreadable file or a failed compress.
      debugPrint('[EditProfile] pick photo failed: $e');
      if (!mounted) return;
      _toastAboveBar('Could not use that photo. Please try another.');
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _avatarFile = file);
  }

  /// A toast for something that keeps the user on this page, lifted clear
  /// of the pinned Save bar (12 + the 48 button + 8, plus the safe area).
  void _toastAboveBar(String message) {
    showPrimaryToast(
      context,
      message,
      bottomOffset: 68 + MediaQuery.viewPaddingOf(context).bottom,
    );
  }

  // --- Save Action ---
  Future<void> _onSaveChanges() async {
    if (!_canSubmit) return;

    if (ContentFilter.containsObjectionable(_bioController.text)) {
      _toastAboveBar(ContentFilter.rejectionMessage);
      return;
    }

    if (_bioController.text.trim().runes.length > bioMaxCodePoints) {
      _toastAboveBar('Your bio is too long. Please shorten it.');
      return;
    }

    final profileCubit = context.read<ProfileCubit>();
    final avatarBloc = context.read<AvatarUploadBloc>();

    final bio = _bioController.text.trim();
    final typedUsername = _usernameController.text.trim();
    final usernameToSave = typedUsername == _savedUsername
        ? null
        : typedUsername;
    // Only what changed is written: an untouched (or absent) name stays as
    // it is on the server.
    final nameToSave = profileNameToSave(
      _nameController.text,
      saved: _savedName,
    );
    final bioToSave = bio == _savedBio.trim() ? null : bio;

    setState(() => _saving = true);
    try {
      if (nameToSave != null || bioToSave != null) {
        await profileCubit.editProfile(name: nameToSave, bio: bioToSave);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toastAboveBar('Could not save your changes. Please try again.');
      return;
    }
    if (!mounted) return;

    // The name and bio are saved now. The username goes separately, so a
    // name someone else took in the meantime does not throw them away too.
    setState(() {
      if (nameToSave != null) _savedName = nameToSave;
      _savedBio = bio;
    });

    if (usernameToSave != null) {
      try {
        await profileCubit.editProfile(username: usernameToSave);
      } catch (e) {
        if (!mounted) return;
        // set_username raises "Username already taken"; 23505 is the unique
        // index on profiles.username underneath it.
        final taken =
            e is PostgrestException &&
            (e.code == '23505' ||
                e.message.toLowerCase().contains('already taken'));
        setState(() {
          _saving = false;
          if (taken) _isAvailable = false;
        });
        _toastAboveBar(
          taken
              ? '@$usernameToSave is already taken.'
              : 'Could not change your username. Please try again.',
        );
        return;
      }
      if (!mounted) return;
    }

    // If the photo fails, only the photo is left to retry.
    setState(() {
      _saving = false;
      if (usernameToSave != null) {
        _savedUsername = usernameToSave;
        _daysUntilUsernameUnlock = usernameCooldownDays;
      }
    });

    final avatar = _avatarFile;
    if (avatar == null) {
      showPrimaryToast(context, EditProfilePage.savedMessage);
      Navigator.pop(context);
      return;
    }

    String? accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      try {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      } catch (_) {}
    }
    avatarBloc.add(
      SubmitAvatarRequested(file: avatar, accessToken: accessToken),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AvatarUploadBloc, AvatarUploadState>(
      listener: (context, state) {
        if (state is AvatarUploadSuccess) {
          showPrimaryToast(context, EditProfilePage.savedMessage);
          context.read<ProfileCubit>().loadProfile();
          Navigator.pop(context);
        } else if (state is AvatarUploadError) {
          _toastAboveBar(state.message);
        }
      },
      builder: (context, avatarState) {
        final uploading = avatarState is AvatarUploading;
        final busy = uploading || _saving;
        final status = _usernameStatus;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: ProfileTokens.surface,
            appBar: ProfileNavBar(title: 'Edit profile', backEnabled: !busy),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PhotoBlock(
                            name: _nameController.text,
                            imageUrl: _savedAvatarUrl,
                            file: _avatarFile,
                            uploading: uploading,
                            onTap: busy ? null : _changePhoto,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: ProfileTokens.gutter,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ProfileTextField(
                                  label: 'Name',
                                  controller: _nameController,
                                  enabled: !busy,
                                  tone: _nameCleared
                                      ? ProfileFieldTone.error
                                      : ProfileFieldTone.normal,
                                  helper: _nameCleared
                                      ? const ProfileFieldHelper(
                                          'Name cannot be empty',
                                          kind: ProfileHelperKind.error,
                                        )
                                      : null,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),
                                ProfileTextField(
                                  label: 'Username',
                                  controller: _usernameController,
                                  prefix: '@',
                                  enabled: !busy,
                                  locked: status == UsernameStatus.locked,
                                  tone: _usernameTone(status),
                                  helper: _usernameHelper(status),
                                  textInputAction: TextInputAction.next,
                                ),
                                const SizedBox(height: 16),
                                ProfileTextField(
                                  label: 'Bio',
                                  controller: _bioController,
                                  enabled: !busy,
                                  multiline: true,
                                  maxLength: EditProfilePage.bioMaxLength,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  counter:
                                      '${_bioController.text.characters.length}'
                                      '/${EditProfilePage.bioMaxLength}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Save Button (pinned bottom) ──────────────────────────
                  Container(
                    decoration: const BoxDecoration(
                      color: ProfileTokens.surface,
                      border: Border(
                        top: BorderSide(color: ProfileTokens.border),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      ProfileTokens.gutter,
                      12,
                      ProfileTokens.gutter,
                      8,
                    ),
                    // Held while saving or uploading, like the bar's arrow:
                    // leaving then would drop the result.
                    child: PopScope(
                      canPop: !busy,
                      child: ProfilePillButton(
                        label: 'Save changes',
                        busy: _saving,
                        onTap: _canSubmit && !uploading ? _onSaveChanges : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String? get _savedAvatarUrl {
    final profileState = context.read<ProfileCubit>().state;
    return profileState is ProfileLoaded ? profileState.avatarUrl : null;
  }

  static ProfileFieldTone _usernameTone(UsernameStatus status) {
    return switch (status) {
      UsernameStatus.checking ||
      UsernameStatus.available => ProfileFieldTone.active,
      UsernameStatus.taken || UsernameStatus.invalid => ProfileFieldTone.error,
      _ => ProfileFieldTone.normal,
    };
  }

  /// The one line under the username field, saying where the name stands.
  Widget _usernameHelper(UsernameStatus status) {
    final typed = _usernameController.text.trim();
    return switch (status) {
      UsernameStatus.locked => ProfileFieldHelper(
        'You can change your username in $_daysUntilUsernameUnlock '
        '${_daysUntilUsernameUnlock == 1 ? 'day' : 'days'}.',
      ),
      UsernameStatus.checking => const ProfileFieldHelper(
        'Checking availability...',
        kind: ProfileHelperKind.busy,
      ),
      UsernameStatus.available => ProfileFieldHelper(
        '@$typed is available!',
        kind: ProfileHelperKind.success,
      ),
      UsernameStatus.taken => ProfileFieldHelper(
        '@$typed is already taken.',
        kind: ProfileHelperKind.error,
      ),
      UsernameStatus.invalid => ProfileFieldHelper(
        _validationError ?? '',
        kind: ProfileHelperKind.error,
      ),
      UsernameStatus.unchanged || UsernameStatus.unknown =>
        const ProfileFieldHelper(EditProfilePage.usernameRules),
    };
  }
}

/// The photo at the top of the form: the avatar with a camera badge and
/// "Change photo" under it. While [uploading] the avatar is dimmed behind a
/// spinner and the label says so.
class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.name,
    required this.imageUrl,
    required this.file,
    required this.uploading,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final File? file;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final local = file;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Center(
        child: Semantics(
          button: true,
          label: uploading ? 'Uploading photo' : 'Change photo',
          excludeSemantics: true,
          child: AdaptiveTap(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 98,
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: uploading ? 0.5 : 1,
                        child: ProfileAvatar(
                          name: name,
                          size: 96,
                          imageUrl: imageUrl,
                          image: local == null ? null : FileImage(local),
                        ),
                      ),
                      if (uploading)
                        const Positioned(
                          left: 34,
                          top: 34,
                          child: ProfileSpinner(
                            size: 28,
                            color: ProfileTokens.brand,
                          ),
                        ),
                      Positioned(
                        left: 66,
                        top: 66,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ProfileTokens.brand,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: ProfileTokens.surface,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.camera,
                            size: 16,
                            color: ProfileTokens.surface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  uploading ? 'Uploading photo…' : 'Change photo',
                  style: ProfileTokens.text(
                    14,
                    weight: FontWeight.w500,
                    color: uploading
                        ? ProfileTokens.muted
                        : ProfileTokens.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the new photo comes from. Pops true for the library, the only
/// source so far.
class ProfilePhotoSourceSheet extends StatelessWidget {
  const ProfilePhotoSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSheet(
      title: 'Change photo',
      children: [
        ProfileSheetOption(
          title: 'Choose from library',
          detail: 'Pick a photo you already have',
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
