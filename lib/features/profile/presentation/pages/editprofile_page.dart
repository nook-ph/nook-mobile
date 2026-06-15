import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/bloc/avatar_upload_event.dart';
import 'package:nook/features/profile/bloc/avatar_upload_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;

  // Username validation state
  Timer? _debounce;
  bool? _isAvailable;
  bool _isChecking = false;
  String? _validationError;
  String _initialUsername = '';

  // Cooldown state
  bool _canEditUsername = true;
  int _daysUntilUsernameUnlock = 0;

  // Bio char count
  int _bioCharCount = 0;
  static const int _bioMaxLength = 150;

  File? _avatarFile;
  final ImagePicker _imagePicker = ImagePicker();

  static const _green = Color(0xFF344E41);
  static const _greenLight = Color(0xFF4A6741);
  static const _grey = Color(0xFFA8AAAA);
  static const _labelColor = Color(0xFF888888);
  static const _borderColor = Color(0xFFD0D0D0);
  static const _sectionTitleColor = Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();

    final profileState = context.read<ProfileCubit>().state;
    String initialName = '';
    String initialEmail = '';
    String initialBio = '';
    DateTime? lastChange;

    if (profileState is ProfileLoaded) {
      initialName = profileState.name;
      _initialUsername = profileState.username;
      initialEmail = profileState.email;
      initialBio = profileState.bio;
      lastChange = profileState.lastUsernameChange;
    }

    _nameController = TextEditingController(text: initialName);
    _usernameController = TextEditingController(text: _initialUsername);
    _bioController = TextEditingController(text: initialBio);
    _emailController = TextEditingController(text: initialEmail);

    _bioCharCount = initialBio.length;
    _bioController.addListener(() {
      setState(() => _bioCharCount = _bioController.text.length);
    });

    // Calculate 14-day cooldown
    if (lastChange != null) {
      final daysSinceChange = DateTime.now().difference(lastChange).inDays;
      if (daysSinceChange < 14) {
        _canEditUsername = false;
        _daysUntilUsernameUnlock = 14 - daysSinceChange;
      }
    }

    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- Username Logic ---
  void _onUsernameChanged() {
    final value = _usernameController.text.trim();

    if (value == _initialUsername) {
      setState(() {
        _isAvailable = true;
        _isChecking = false;
        _validationError = null;
      });
      _debounce?.cancel();
      return;
    }

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
    if (value.isEmpty) return 'Username cannot be empty';
    if (value.length < 3) return 'At least 3 characters';
    if (value.length > 20) return 'Max 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Only letters, numbers, and underscores';
    }
    return null;
  }

  bool get _canSubmit {
    return _isAvailable != false && _validationError == null && !_isChecking;
  }

  // --- Avatar Logic ---
  Future<File> _compressImage(File file) async {
    final filePath = file.path;
    final ext = filePath.split('.').last.toLowerCase();
    final targetPath = filePath.replaceAll('.$ext', '_compressed.$ext');

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      targetPath,
      quality: 80,
      minWidth: 512,
      minHeight: 512,
      format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  Future<void> _pickAvatar() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) return;

    final compressed = await _compressImage(File(picked.path));
    setState(() => _avatarFile = compressed);
  }

  // --- Save Action ---
  void _onSaveChanges() async {
    if (!_canSubmit) return;

    final profileCubit = context.read<ProfileCubit>();
    final avatarBloc = context.read<AvatarUploadBloc>();

    final typedUsername = _usernameController.text.trim();
    final usernameToSave = typedUsername == _initialUsername
        ? null
        : typedUsername;

    profileCubit.editProfile(
      name: _nameController.text.trim(),
      username: usernameToSave,
      bio: _bioController.text.trim(),
    );

    if (_avatarFile != null) {
      String? accessToken =
          Supabase.instance.client.auth.currentSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        try {
          final refreshed = await Supabase.instance.client.auth
              .refreshSession();
          accessToken = refreshed.session?.accessToken;
        } catch (_) {}
      }
      avatarBloc.add(
        SubmitAvatarRequested(file: _avatarFile!, accessToken: accessToken),
      );
    } else {
      showPrimaryToast(context, 'Changes saved!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AvatarUploadBloc, AvatarUploadState>(
      listener: (context, state) {
        if (state is AvatarUploadSuccess) {
          showPrimaryToast(context, 'Profile updated successfully!');
          context.read<ProfileCubit>().loadProfile();
          Navigator.pop(context);
        } else if (state is AvatarUploadError) {
          showPrimaryToast(context, state.message);
        }
      },
      builder: (context, avatarState) {
        final isSaving = avatarState is AvatarUploading;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.white,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 22,
                ),
                onPressed: isSaving ? null : () => Navigator.pop(context),
              ),
              title: Text(
                'Edit Profile',
                style: context.textTheme.titleMediumSemi.copyWith(
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
              centerTitle: false,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 28),

                          // ── Avatar ──────────────────────────────────────
                          Center(
                            child: Column(
                              children: [
                                AdaptiveTap(
                                  onTap: isSaving ? null : _pickAvatar,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        child: ClipOval(
                                          child: _buildAvatarImage(),
                                        ),
                                      ),
                                      // Subtle dim overlay on tap area
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: isSaving
                                                ? null
                                                : _pickAvatar,
                                            splashColor: Colors.black12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: isSaving ? null : _pickAvatar,
                                  child: Text(
                                    'Change Photo',
                                    style: context.textTheme.bodySmallMed.copyWith(
                                      color: isSaving ? _grey : _green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Section Header ───────────────────────────────
                          Text(
                            'Personal Information',
                            style: context.textTheme.bodySmallMed.copyWith(
                              color: _sectionTitleColor,
                              letterSpacing: -0.2,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Name ─────────────────────────────────────────
                          _buildOutlinedField(
                            controller: _nameController,
                            label: 'Name',
                            enabled: !isSaving,
                          ),

                          const SizedBox(height: 12),

                          // ── Username ──────────────────────────────────────
                          _buildUsernameOutlinedField(
                            enabled: !isSaving && _canEditUsername,
                          ),
                          if (!_canEditUsername) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                'You can change your username in $_daysUntilUsernameUnlock days.',
                              style: context.textTheme.bodySmall!.copyWith(
                                color: Colors.orange,
                              ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _buildUsernameStatusText(),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // ── Bio ───────────────────────────────────────────
                          _buildBioOutlinedField(enabled: !isSaving),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // ── Save Button (pinned bottom) ──────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (isSaving || !_canSubmit)
                            ? null
                            : _onSaveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          disabledBackgroundColor: _green.withOpacity(0.45),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.7,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: context.textTheme.bodyLargeSemi.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 0.1,
                                ),
                              ),
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

  // ── Avatar Helpers ──────────────────────────────────────────────────────────

  Widget _buildAvatarImage() {
    if (_avatarFile != null) {
      return Image.file(
        _avatarFile!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    }

    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded && profileState.avatarUrl != null) {
      return Image.network(
        profileState.avatarUrl!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
      );
    }

    return _buildPlaceholderAvatar();
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: const Icon(
        Icons.person_rounded,
        size: 48,
        color: Color(0xFFBDBDBD),
      ),
    );
  }

  // ── Field Widgets ───────────────────────────────────────────────────────────
  //
  // Pattern: a decorated Container holds a Column with:
  //   Row( label Text  +  optional suffix )
  //   TextField with no decoration at all (border: InputBorder.none)
  // This is the exact layout in the reference screenshot.
 
  Widget _buildOutlinedField({
    required TextEditingController controller,
    required String label,
    required bool enabled,
    int maxLines = 1,
    Widget? suffixIcon,
    Color borderColor = _borderColor,
  }) {
    return Focus(
      onFocusChange: (_) => setState(() {}), // repaint border on focus
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          final activeBorder = focused ? _green : borderColor;
 
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? activeBorder : const Color(0xFFE8E8E8),
                width: focused ? 1.5 : 1.2,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: context.textTheme.bodySmall!.copyWith(
                        color: _labelColor,
                      ),
                    ),
                    if (suffixIcon != null) suffixIcon,
                  ],
                ),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  maxLines: maxLines,
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: enabled ? Colors.black87 : const Color(0xFF888888),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  /// Username field — same container pattern, with @-prefix and validation icon
  Widget _buildUsernameOutlinedField({required bool enabled}) {
    Color borderColor = _borderColor;
    if (_usernameController.text.isNotEmpty &&
        _usernameController.text != _initialUsername) {
      if (_validationError != null || _isAvailable == false) {
        borderColor = Colors.red;
      } else if (_isAvailable == true) {
        borderColor = _green;
      }
    }
 
    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          final activeBorder = focused
              ? (borderColor == _borderColor ? _green : borderColor)
              : borderColor;
 
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? activeBorder : const Color(0xFFE8E8E8),
                width: focused ? 1.5 : 1.2,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Username',
                      style: context.textTheme.bodySmall!.copyWith(
                        color: _labelColor,
                      ),
                    ),
                    if (_buildUsernameSuffixIcon() != null)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: _buildUsernameSuffixIcon(),
                      ),
                  ],
                ),
                TextField(
                  controller: _usernameController,
                  enabled: enabled,
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: enabled ? Colors.black87 : const Color(0xFF888888),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 8),
                    border: InputBorder.none,
                    prefixText: '@',
                    prefixStyle: context.textTheme.bodyMedium!.copyWith(
                      color: enabled ? Colors.black87 : _grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
 
  /// Bio field — label + char counter on top row, TextField below
  Widget _buildBioOutlinedField({required bool enabled}) {
    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
 
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled
                    ? (focused ? _green : _borderColor)
                    : const Color(0xFFE8E8E8),
                width: focused ? 1.5 : 1.2,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bio',
                      style: context.textTheme.bodySmall!.copyWith(
                        color: _labelColor,
                      ),
                    ),
                    Text(
                      '$_bioCharCount/$_bioMaxLength',
                      style: context.textTheme.bodySmall!.copyWith(
                        color: _grey,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _bioController,
                  enabled: enabled,
                  maxLines: 5,
                  maxLength: _bioMaxLength,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      const SizedBox.shrink(),
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: enabled ? Colors.black87 : const Color(0xFF888888),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.only(bottom: 8),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
 
  // ── Username Status Widgets ─────────────────────────────────────────────────
 
  Widget? _buildUsernameSuffixIcon() {
    if (_usernameController.text.isEmpty ||
        _usernameController.text == _initialUsername) return null;
 
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
 
    if (_validationError != null || _isAvailable == false) {
      return const Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
    }
    if (_isAvailable == true) {
      return const Icon(Icons.check_circle_rounded, color: _green, size: 20);
    }
    return null;
  }
 
  Widget _buildUsernameStatusText() {
    if (_usernameController.text == _initialUsername ||
        _usernameController.text.isEmpty) {
      return const SizedBox.shrink();
    }
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

