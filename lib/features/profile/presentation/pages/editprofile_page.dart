import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
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

  File? _avatarFile;
  final ImagePicker _imagePicker = ImagePicker();

  static const _green = Color(0xFF344E41);
  static const _grey = Color(0xFFA8AAAA);
  static const _border = Color(0xFFE0E0E0);

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

    // If it's their current username, it's automatically valid!
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
    // Only pass username to Cubit if it actually changed
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

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Transform.scale(
              scaleX: -1,
              child: IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: Colors.black,
                  size: 28,
                ),
                onPressed: isSaving ? null : () => Navigator.pop(context),
              ),
            ),
            title: const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // --- Avatar ---
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _green, width: 2.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2.5),
                          child: ClipOval(child: _buildAvatarImage()),
                        ),
                      ),
                      AdaptiveTap(
                        onTap: isSaving ? null : _pickAvatar,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: _green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // --- Full Name ---
                  _buildFieldLabel('Full Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Enter your name',
                    enabled: !isSaving,
                  ),

                  const SizedBox(height: 24),

                  // --- Username ---
                  _buildFieldLabel('Username'),
                  const SizedBox(height: 8),
                  _buildUsernameField(enabled: !isSaving && _canEditUsername),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildUsernameStatusText(),
                  ),

                  const SizedBox(height: 24),

                  // --- Bio ---
                  _buildFieldLabel('Bio'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _bioController,
                    hint: 'Tell people about your coffee preferences...',
                    enabled: !isSaving,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 24),

                  // --- Email (read-only) ---
                  _buildFieldLabel('Email'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hint: '',
                    enabled: false,
                    suffixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email cannot be changed.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // --- Save Button ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (isSaving || !_canSubmit)
                          ? null
                          : _onSaveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        disabledBackgroundColor: _green.withOpacity(0.5),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withOpacity(0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helpers ---
  Widget _buildAvatarImage() {
    if (_avatarFile != null) {
      return Image.file(
        _avatarFile!,
        fit: BoxFit.cover,
        width: 125,
        height: 125,
      );
    }

    final profileState = context.read<ProfileCubit>().state;
    if (profileState is ProfileLoaded && profileState.avatarUrl != null) {
      return Image.network(
        profileState.avatarUrl!,
        fit: BoxFit.cover,
        width: 125,
        height: 125,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderAvatar(),
      );
    }

    return _buildPlaceholderAvatar();
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: const Color(0xFFE8E8E8),
      child: const Icon(
        Icons.person_rounded,
        size: 56,
        color: Color(0xFFBDBDBD),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 14,
        color: enabled ? Colors.black : Colors.grey[600],
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: enabled ? const Color(0xFFF5F5F5) : const Color(0xFFEEEEEE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // --- Specific Username Widgets ---
  Widget _buildUsernameField({required bool enabled}) {
    final hasInput = _usernameController.text.isNotEmpty;

    // Determine border color based on validation
    Color borderColor = _border;
    if (hasInput && _usernameController.text != _initialUsername) {
      if (_validationError != null || _isAvailable == false) {
        borderColor = Colors.red;
      } else if (_isAvailable == true) {
        borderColor = _green;
      }
    }

    return TextField(
      controller: _usernameController,
      enabled: enabled,
      style: TextStyle(
        fontSize: 14,
        color: enabled ? Colors.black : Colors.grey[600],
      ),
      decoration: InputDecoration(
        hintText: 'username',
        hintStyle: const TextStyle(color: Colors.grey),
        prefixText: '@',
        prefixStyle: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey[600],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        suffixIcon: _buildUsernameSuffixIcon(),
        filled: true,
        fillColor: enabled ? const Color(0xFFF5F5F5) : const Color(0xFFEEEEEE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: borderColor == _border ? Colors.black87 : borderColor,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget? _buildUsernameSuffixIcon() {
    if (_usernameController.text.isEmpty ||
        _usernameController.text == _initialUsername)
      return null;

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
    if (!_canEditUsername) {
      return Text(
        'You can change your username in $_daysUntilUsernameUnlock days.',
        style: const TextStyle(color: Colors.orange, fontSize: 12),
      );
    }

    if (_usernameController.text == _initialUsername ||
        _usernameController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_validationError != null) {
      return Text(
        _validationError!,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      );
    }
    if (_isChecking) {
      return const Text(
        'Checking availability...',
        style: TextStyle(color: _grey, fontSize: 12),
      );
    }
    if (_isAvailable == true) {
      return Text(
        '@${_usernameController.text} is available!',
        style: const TextStyle(color: _green, fontSize: 12),
      );
    }
    if (_isAvailable == false) {
      return Text(
        '@${_usernameController.text} is already taken.',
        style: const TextStyle(color: Colors.red, fontSize: 12),
      );
    }
    return const SizedBox.shrink();
  }
}
