import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/theme.dart';
import '../core/app_state.dart';
import '../core/widgets.dart';
import 'resource_marketplace/data/deal_request_repository.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() =>
      _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _dealRequestRepository = DealRequestRepository();

  late final TextEditingController _contactNameController;
  late final TextEditingController _phoneController;

  bool _editing = false;
  bool _saving = false;
  bool _refreshing = false;
  bool _imageBusy = false;
  bool _imageLoading = false;
  bool _notificationsLoading = false;

  String? _signedImageUrl;
  String? _loadedImagePath;
  String? _notificationError;

  List<DealRequestRecord> _notifications = const [];

  @override
  void initState() {
    super.initState();

    final profile = ref.read(appStateProvider).profile;

    _contactNameController = TextEditingController(
      text: profile.contactName ?? '',
    );

    _phoneController = TextEditingController(
      text: profile.contactPhone ?? '',
    );

    Future<void>.microtask(() async {
      await _loadProfileImage(profile.profileImagePath);
      await _loadNotifications();
    });
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }





  Future<void> _refreshProfile() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
    });

    try {
      await ref
          .read(appStateProvider.notifier)
          .refreshSupabaseData();

      if (!mounted) return;

      final profile =
          ref.read(appStateProvider).profile;

      _syncContactFields(profile);

      await _loadProfileImage(
        profile.profileImagePath,
        force: true,
      );

      await _loadNotifications();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not refresh profile: $error',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _syncContactFields(CompanyProfile profile) {
    if (_editing) return;

    _contactNameController.text =
        profile.contactName ?? '';

    _phoneController.text =
        profile.contactPhone ?? '';
  }





  Future<void> _loadProfileImage(
    String? imagePath, {
    bool force = false,
  }) async {
    final path = imagePath?.trim() ?? '';

    if (path.isEmpty) {
      if (!mounted) return;

      setState(() {
        _signedImageUrl = null;
        _loadedImagePath = null;
        _imageLoading = false;
      });

      return;
    }

    if (!force &&
        path == _loadedImagePath &&
        _signedImageUrl != null) {
      return;
    }

    if (mounted) {
      setState(() {
        _imageLoading = true;
      });
    }

    try {






      final signedUrl = await Supabase
          .instance.client.storage
          .from('profile-images')
          .createSignedUrl(
            path,
            3600,
          );

      if (!mounted) return;

      setState(() {
        _signedImageUrl = signedUrl;
        _loadedImagePath = path;
        _imageLoading = false;
      });
    } catch (error) {
      debugPrint(
        'Profile image could not be loaded: $error',
      );

      if (!mounted) return;

      setState(() {
        _signedImageUrl = null;
        _loadedImagePath = path;
        _imageLoading = false;
      });
    }
  }

  Future<void> _showImageOptions() async {
    if (_imageBusy) return;

    final profile =
        ref.read(appStateProvider).profile;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              0,
              12,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  title:
                      const Text('Take photo'),
                  subtitle: const Text(
                    'Use your phone camera',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _pickAndUploadImage(
                      ImageSource.camera,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text(
                    'Choose from gallery',
                  ),
                  subtitle: const Text(
                    'Select an existing image',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);

                    _pickAndUploadImage(
                      ImageSource.gallery,
                    );
                  },
                ),
                if ((profile.profileImagePath ?? '')
                    .trim()
                    .isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                    ),
                    title: const Text(
                      'Remove profile image',
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removeProfileImage();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImage(
    ImageSource source,
  ) async {
    if (_imageBusy) return;

    try {
      final picked =
          await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );

      if (picked == null) return;

      final user = Supabase
          .instance.client.auth.currentUser;

      if (user == null) {
        throw StateError(
          'Please sign in before updating the profile image.',
        );
      }

      final extension =
          _imageExtension(picked.name);

      if (extension == null) {
        throw StateError(
          'Please choose a supported image file.',
        );
      }

      setState(() {
        _imageBusy = true;
      });

      final oldPath = ref
          .read(appStateProvider)
          .profile
          .profileImagePath;







      final newPath =
          '${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage
          .from('profile-images')
          .upload(
            newPath,
            File(picked.path),
            fileOptions: FileOptions(
              upsert: false,
              contentType:
                  _imageContentType(extension),
            ),
          );

      try {



        await ref
            .read(appStateProvider.notifier)
            .updateProfile(
              profileImagePath: newPath,
            );
      } catch (error) {




        try {
          await Supabase
              .instance.client.storage
              .from('profile-images')
              .remove([newPath]);
        } catch (_) {

        }

        rethrow;
      }

      await _loadProfileImage(
        newPath,
        force: true,
      );





      if (oldPath != null &&
          oldPath.trim().isNotEmpty &&
          oldPath != newPath) {
        try {
          await Supabase
              .instance.client.storage
              .from('profile-images')
              .remove([oldPath]);
        } catch (error) {
          debugPrint(
            'Previous profile image could not be removed: $error',
          );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile image updated.'),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update profile image: $error',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _imageBusy = false;
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    if (_imageBusy) return;

    final oldPath = ref
        .read(appStateProvider)
        .profile
        .profileImagePath;

    if (oldPath == null ||
        oldPath.trim().isEmpty) {
      return;
    }

    setState(() {
      _imageBusy = true;
    });

    try {



      await ref
          .read(appStateProvider.notifier)
          .updateProfile(
            clearProfileImage: true,
          );

      try {
        await Supabase.instance.client.storage
            .from('profile-images')
            .remove([oldPath]);
      } catch (error) {
        debugPrint(
          'Profile image file could not be removed: $error',
        );
      }

      if (!mounted) return;

      setState(() {
        _signedImageUrl = null;
        _loadedImagePath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Profile image removed.'),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not remove profile image: $error',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _imageBusy = false;
        });
      }
    }
  }

  String? _imageExtension(
    String fileName,
  ) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'jpg';
    }

    if (lower.endsWith('.png')) {
      return 'png';
    }

    if (lower.endsWith('.webp')) {
      return 'webp';
    }

    return null;
  }

  String _imageContentType(
    String extension,
  ) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }





  void _startEditing() {
    final profile =
        ref.read(appStateProvider).profile;

    _contactNameController.text =
        profile.contactName ?? '';

    _phoneController.text =
        profile.contactPhone ?? '';

    setState(() {
      _editing = true;
    });
  }

  void _cancelEditing() {
    final profile =
        ref.read(appStateProvider).profile;

    _contactNameController.text =
        profile.contactName ?? '';

    _phoneController.text =
        profile.contactPhone ?? '';

    setState(() {
      _editing = false;
    });
  }

  Future<void> _saveContactDetails() async {
    if (_saving) return;

    if (!(_formKey.currentState
            ?.validate() ??
        false)) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(appStateProvider.notifier)
          .updateProfile(
            contactName:
                _contactNameController.text
                    .trim(),
            contactPhone:
                _phoneController.text.trim(),
          );

      if (!mounted) return;

      setState(() {
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Contact details updated.'),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save contact details: $error',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _validateContactName(
    String? value,
  ) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter the contact person name.';
    }

    if (text.length < 2) {
      return 'Contact person name is too short.';
    }

    if (text.length > 100) {
      return 'Contact person name cannot exceed 100 characters.';
    }

    return null;
  }

  String? _validatePhone(
    String? value,
  ) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter a contact phone number.';
    }

    if (!RegExp(
      r'^[0-9+()\-\s]+$',
    ).hasMatch(text)) {
      return 'Enter a valid phone number.';
    }

    final digits =
        text.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (digits.length < 7 ||
        digits.length > 15) {
      return 'Phone number should contain 7 to 15 digits.';
    }

    return null;
  }





  Future<void> _loadNotifications() async {
    if (_notificationsLoading) return;

    if (mounted) {
      setState(() {
        _notificationsLoading = true;
        _notificationError = null;
      });
    }

    try {
      final records =
          await _dealRequestRepository
              .fetchRelevantRequests();

      if (!mounted) return;

      setState(() {
        _notifications = records;
        _notificationError = null;
      });
    } catch (error) {
      debugPrint(
        'Profile notifications could not be loaded: $error',
      );

      if (!mounted) return;

      setState(() {
        _notificationError =
            'Notifications could not be loaded.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _notificationsLoading = false;
        });
      }
    }
  }

  bool _isOwnerSide(
    DealRequestRecord request,
  ) {
    final userId = Supabase
        .instance.client.auth.currentUser?.id;

    return userId != null &&
        request.listingOwnerId == userId;
  }

  bool _isUnreadNotification(
    DealRequestRecord request,
  ) {
    if (_isOwnerSide(request)) {





      if (request.status !=
              'REQUEST SENT' &&
          request.status != 'CANCELLED') {
        return false;
      }

      return request.ownerReadAt == null;
    }






    if (request.status != 'ACCEPTED' &&
        request.status != 'REJECTED') {
      return false;
    }

    return request.requesterReadAt == null;
  }

  int get _unreadCount => _notifications
      .where(_isUnreadNotification)
      .length;

  Future<void> _markNotificationRead(
    DealRequestRecord request,
  ) async {
    if (!_isUnreadNotification(request)) {
      return;
    }

    try {
      if (_isOwnerSide(request)) {
        await _dealRequestRepository
            .markOwnerNotificationRead(
          request.id,
        );
      } else {
        await _dealRequestRepository
            .markRequesterNotificationRead(
          request.id,
        );
      }

      await _loadNotifications();
    } catch (error) {
      debugPrint(
        'Could not mark notification as read: $error',
      );
    }
  }

  Future<void> _showNotifications() async {
    await _loadNotifications();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final availableHeight =
            MediaQuery.sizeOf(
          sheetContext,
        ).height;

        return SafeArea(
          top: false,
          child: SizedBox(
            height:
                availableHeight * 0.72,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    0,
                    10,
                    10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'Notifications',
                              style: Theme.of(
                                sheetContext,
                              )
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              _unreadCount == 0
                                  ? 'You are all caught up.'
                                  : '$_unreadCount unread ${_unreadCount == 1 ? 'notification' : 'notifications'}.',
                              style:
                                  const TextStyle(
                                color:
                                    AppColors.slate,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'Refresh notifications',
                        onPressed: () async {
                          Navigator.pop(
                            sheetContext,
                          );

                          await _loadNotifications();

                          if (mounted) {
                            _showNotifications();
                          }
                        },
                        icon: const Icon(
                          Icons.refresh_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _notificationsLoading
                      ? const Center(
                          child:
                              CircularProgressIndicator(),
                        )
                      : _notificationError !=
                              null
                          ? _NotificationEmptyState(
                              icon: Icons
                                  .cloud_off_outlined,
                              title:
                                  'Notifications unavailable',
                              description:
                                  _notificationError!,
                            )
                          : _notifications
                                  .isEmpty
                              ? const _NotificationEmptyState(
                                  icon: Icons
                                      .notifications_none_outlined,
                                  title:
                                      'No notifications yet',
                                  description:
                                      'New deal requests and responses will appear here.',
                                )
                              : ListView
                                  .separated(
                                  padding:
                                      const EdgeInsets
                                          .fromLTRB(
                                    12,
                                    10,
                                    12,
                                    20,
                                  ),
                                  itemCount:
                                      _notifications
                                          .length,
                                  separatorBuilder:
                                      (_, _) =>
                                          const SizedBox(
                                    height: 6,
                                  ),
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    final request =
                                        _notifications[
                                            index];

                                    final ownerSide =
                                        _isOwnerSide(
                                      request,
                                    );

                                    final unread =
                                        _isUnreadNotification(
                                      request,
                                    );

                                    return Card(
                                      child:
                                          ListTile(
                                        leading:
                                            Icon(
                                          ownerSide
                                              ? Icons
                                                  .call_received_outlined
                                              : Icons
                                                  .call_made_outlined,
                                          color: unread
                                              ? AppColors
                                                  .navy
                                              : AppColors
                                                  .slate,
                                        ),
                                        title: Text(
                                          _notificationTitle(
                                            request,
                                            ownerSide,
                                          ),
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                unread
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                          ),
                                        ),
                                        subtitle:
                                            Text(
                                          _notificationDescription(
                                            request,
                                            ownerSide,
                                          ),
                                          maxLines:
                                              3,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                        ),
                                        trailing:
                                            unread
                                                ? Container(
                                                    width:
                                                        8,
                                                    height:
                                                        8,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color:
                                                          AppColors.rust,
                                                      shape:
                                                          BoxShape.circle,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.chevron_right,
                                                  ),
                                        onTap:
                                            () async {
                                          await _markNotificationRead(
                                            request,
                                          );

                                          if (!mounted ||
                                              !sheetContext
                                                  .mounted) {
                                            return;
                                          }

                                          Navigator.pop(
                                            sheetContext,
                                          );

                                          context.push(
                                            '/marketplace',
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _notificationTitle(
    DealRequestRecord request,
    bool ownerSide,
  ) {
    if (ownerSide) {
      return switch (request.status) {
        'REQUEST SENT' =>
          'New deal request',
        'CANCELLED' =>
          'Deal request cancelled',
        'ACCEPTED' =>
          'Request accepted',
        'REJECTED' =>
          'Request closed',
        _ => 'Marketplace update',
      };
    }

    return switch (request.status) {
      'ACCEPTED' =>
        'Your deal request was accepted',
      'REJECTED' =>
        'Your deal request was declined',
      'CANCELLED' =>
        'Deal request cancelled',
      _ => 'Deal request update',
    };
  }

  String _notificationDescription(
    DealRequestRecord request,
    bool ownerSide,
  ) {
    if (ownerSide) {
      return switch (request.status) {
        'REQUEST SENT' =>
          '${request.requesterName} requested ${request.quantity} of ${request.material}.',
        'CANCELLED' =>
          '${request.requesterName} cancelled the request for ${request.material}.',
        _ =>
          'There is an update to your ${request.material} listing.',
      };
    }

    return switch (request.status) {
      'ACCEPTED' =>
        '${request.owner} accepted your request for ${request.material}.',
      'REJECTED' =>
        '${request.owner} declined your request for ${request.material}.',
      _ =>
        'Your request for ${request.material} has been updated.',
    };
  }





  Future<void> _signOut() async {
    try {
      await Supabase
          .instance.client.auth
          .signOut();

      if (!mounted) return;

      context.go('/login');
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not sign out: $error',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }
  }





  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(appStateProvider);

    final profile = state.profile;

    final authUser = Supabase
        .instance.client.auth.currentUser;

    final email =
        authUser?.email?.trim().isNotEmpty ==
                true
            ? authUser!.email!.trim()
            : 'Email unavailable';





    if (profile.profileImagePath !=
            _loadedImagePath &&
        !_imageLoading &&
        !_imageBusy) {
      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (mounted) {
            _loadProfileImage(
              profile.profileImagePath,
            );
          }
        },
      );
    }

    _syncContactFields(profile);

    return AppShell(
      title: 'Profile',
      showBack: true,
      actions: [
        if (_refreshing)
          const Padding(
            padding:
                EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _refreshProfile,
            icon: const Icon(
              Icons.refresh_outlined,
            ),
          ),

        IconButton(
          tooltip: _unreadCount == 0
              ? 'Open notifications'
              : 'Open notifications ($_unreadCount unread)',
          onPressed: _showNotifications,
          icon: Badge.count(
            count: _unreadCount,
            isLabelVisible:
                _unreadCount > 0,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            child: const Icon(
              Icons.notifications_outlined,
            ),
          ),
        ),

        IconButton(
          tooltip: 'Sign out',
          onPressed: _signOut,
          icon: const Icon(
            Icons.logout_outlined,
          ),
        ),

        const SizedBox(width: 4),
      ],

      bottomNavigationBar:
          const AppBottomNav(
        currentIndex: 2,
      ),

      body: state.isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _refreshProfile,
              child: LayoutBuilder(
                builder:
                    (context, constraints) {




                  final wide =
                      constraints.maxWidth >=
                          720;

                  final horizontalPadding =
                      wide ? 28.0 : 18.0;

                  return SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 1000,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            _ProfileHeader(
                              wide: wide,
                              businessName:
                                  profile.businessName
                                          .trim()
                                          .isEmpty
                                      ? 'Company name not set'
                                      : profile
                                          .businessName
                                          .trim(),
                              email: email,
                              role: profile
                                      .role
                                      .trim()
                                      .isEmpty
                                  ? 'Role not assigned'
                                  : profile.role
                                      .trim(),
                              verified:
                                  profile.verified,
                              imageUrl:
                                  _signedImageUrl,
                              imageLoading:
                                  _imageLoading ||
                                      _imageBusy,
                              onImageTap:
                                  _imageBusy
                                      ? null
                                      : _showImageOptions,
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _VerificationCard(
                              profile: profile,
                              onManageClassification:
                                  () {
                                context.push(
                                  '/resource-profile',
                                );
                              },
                            ),

                            const SizedBox(
                              height: 24,
                            ),

                            const SpecDivider(
                              label:
                                  'ACCOUNT INFORMATION',
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _AccountInformationCard(
                              formKey:
                                  _formKey,
                              editing:
                                  _editing,
                              saving: _saving,
                              businessName: profile
                                      .businessName
                                      .trim()
                                      .isEmpty
                                  ? 'Not provided'
                                  : profile
                                      .businessName
                                      .trim(),
                              email: email,
                              role: profile
                                      .role
                                      .trim()
                                      .isEmpty
                                  ? 'Not assigned'
                                  : profile.role
                                      .trim(),
                              contactName:
                                  profile
                                      .contactName,
                              contactPhone:
                                  profile
                                      .contactPhone,
                              contactNameController:
                                  _contactNameController,
                              phoneController:
                                  _phoneController,
                              validateContactName:
                                  _validateContactName,
                              validatePhone:
                                  _validatePhone,
                              onEdit:
                                  _startEditing,
                              onCancel:
                                  _cancelEditing,
                              onSave:
                                  _saveContactDetails,
                            ),

                            const SizedBox(
                              height: 24,
                            ),

                            const SpecDivider(
                              label:
                                  'BUSINESS CLASSIFICATION',
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _BusinessClassificationCard(
                              sector:
                                  profile.sector,
                              msicCode:
                                  profile.msicCode,
                              msicDescription:
                                  profile
                                      .msicDescription,
                              onManage: () {
                                context.push(
                                  '/resource-profile',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}





class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.wide,
    required this.businessName,
    required this.email,
    required this.role,
    required this.verified,
    required this.imageUrl,
    required this.imageLoading,
    required this.onImageTap,
  });

  final bool wide;
  final String businessName;
  final String email;
  final String role;
  final bool verified;
  final String? imageUrl;
  final bool imageLoading;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final image = _ProfileImage(
      imageUrl: imageUrl,
      loading: imageLoading,
      onTap: onImageTap,
    );

    final details = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          businessName,
          textAlign: wide
              ? TextAlign.left
              : TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .displayMedium,
        ),
        const SizedBox(height: 6),
        Text(
          email,
          textAlign: wide
              ? TextAlign.left
              : TextAlign.center,
          style: const TextStyle(
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          role,
          textAlign: wide
              ? TextAlign.left
              : TextAlign.center,
          style: const TextStyle(
            color: AppColors.slate,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        StatusChip(
          label: verified
              ? 'PROFILE VERIFIED'
              : 'PROFILE INCOMPLETE',
          color: verified
              ? AppColors.green
              : AppColors.rust,
        ),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        image,
                        const SizedBox(width: 22),
                        Expanded(
                          child: details,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        image,
                        const SizedBox(height: 16),
                        details,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}





class _ProfileImage extends StatelessWidget {
  const _ProfileImage({
    required this.imageUrl,
    required this.loading,
    required this.onTap,
  });

  final String? imageUrl;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 104,
            height: 104,
            clipBehavior:
                Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.navy
                  .withValues(
                alpha: 0.08,
              ),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              border: Border.all(
                color: AppColors.line,
              ),
            ),
            child: loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : imageUrl != null &&
                        imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                          context,
                          error,
                          stackTrace,
                        ) {
                          return const Icon(
                            Icons
                                .business_outlined,
                            size: 44,
                            color:
                                AppColors.navy,
                          );
                        },
                      )
                    : const Icon(
                        Icons
                            .business_outlined,
                        size: 44,
                        color:
                            AppColors.navy,
                      ),
          ),
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                border: Border.all(
                  color: AppColors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons
                    .camera_alt_outlined,
                color: AppColors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}





class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.profile,
    required this.onManageClassification,
  });

  final CompanyProfile profile;
  final VoidCallback onManageClassification;

  @override
  Widget build(BuildContext context) {
    final verified = profile.verified;

    final missing = <String>[
      if (profile.businessName.trim().isEmpty)
        'company name',

      if (profile.sector.trim().isEmpty)
        'industry sector',

      if (profile.role.trim().isEmpty)
        'account role',

      if ((profile.msicCode ?? '').trim().isEmpty)
        'MSIC classification',

      if ((profile.contactName ?? '').trim().isEmpty)
        'contact person',

      if ((profile.contactPhone ?? '').trim().isEmpty)
        'contact phone',
    ];

    final color = verified
        ? AppColors.green
        : AppColors.rust;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                verified
                    ? Icons.verified_outlined
                    : Icons.info_outline,
                color: color,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      verified
                          ? 'Profile verified'
                          : 'Profile incomplete',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      verified
                          ? 'Your required personal and business information is complete.'
                          : 'Complete your required personal and business information to verify your profile automatically.',
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!verified && missing.isNotEmpty) ...[
            const SizedBox(height: 14),

            Text(
              'Still needed: ${missing.join(', ')}.',
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],

          if (!verified &&
              (
                profile.sector.trim().isEmpty ||
                profile.role.trim().isEmpty ||
                (profile.msicCode ?? '').trim().isEmpty
              )) ...[
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onManageClassification,
                icon: const Icon(
                  Icons.manage_accounts_outlined,
                ),
                label: const Text(
                  'Complete business classification',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}





class _AccountInformationCard
    extends StatelessWidget {
  const _AccountInformationCard({
    required this.formKey,
    required this.editing,
    required this.saving,
    required this.businessName,
    required this.email,
    required this.role,
    required this.contactName,
    required this.contactPhone,
    required this.contactNameController,
    required this.phoneController,
    required this.validateContactName,
    required this.validatePhone,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final bool editing;
  final bool saving;

  final String businessName;
  final String email;
  final String role;

  final String? contactName;
  final String? contactPhone;

  final TextEditingController
      contactNameController;

  final TextEditingController
      phoneController;

  final String? Function(String?)
      validateContactName;

  final String? Function(String?)
      validatePhone;

  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Company account',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleMedium,
                    ),
                  ),

                  if (!editing)
                    TextButton.icon(
                      onPressed:
                          onEdit,
                      icon:
                          const Icon(
                        Icons
                            .edit_outlined,
                        size: 18,
                      ),
                      label:
                          const Text(
                        'Edit contact',
                      ),
                    ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              _InformationRow(
                icon: Icons
                    .business_outlined,
                label:
                    'Company name',
                value: businessName,
              ),

              const Divider(
                height: 28,
              ),

              if (editing) ...[
                TextFormField(
                  controller:
                      contactNameController,
                  validator:
                      validateContactName,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Contact person *',
                    prefixIcon: Icon(
                      Icons
                          .person_outline,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 14,
                ),

                TextFormField(
                  controller:
                      phoneController,
                  validator:
                      validatePhone,
                  keyboardType:
                      TextInputType.phone,
                  textInputAction:
                      TextInputAction.done,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Contact phone number *',
                    prefixIcon: Icon(
                      Icons
                          .phone_outlined,
                    ),
                    hintText:
                        'Example: +60 12-345 6789',
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment:
                      WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed:
                          saving
                              ? null
                              : onCancel,
                      child:
                          const Text(
                        'Cancel',
                      ),
                    ),

                    FilledButton.icon(
                      onPressed:
                          saving
                              ? null
                              : onSave,
                      icon: saving
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                                color:
                                    AppColors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .save_outlined,
                            ),
                      label: Text(
                        saving
                            ? 'Saving...'
                            : 'Save changes',
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _InformationRow(
                  icon: Icons
                      .person_outline,
                  label:
                      'Contact person',
                  value:
                      (contactName ??
                                  '')
                              .trim()
                              .isEmpty
                          ? 'Not provided'
                          : contactName!
                              .trim(),
                ),

                const Divider(
                  height: 28,
                ),

                _InformationRow(
                  icon: Icons
                      .email_outlined,
                  label: 'Login email',
                  value: email,
                ),

                const Divider(
                  height: 28,
                ),

                _InformationRow(
                  icon: Icons
                      .phone_outlined,
                  label:
                      'Contact phone number',
                  value:
                      (contactPhone ??
                                  '')
                              .trim()
                              .isEmpty
                          ? 'Not provided'
                          : contactPhone!
                              .trim(),
                ),

                const Divider(
                  height: 28,
                ),

                _InformationRow(
                  icon: Icons
                      .badge_outlined,
                  label:
                      'Account role',
                  value: role,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}





class _BusinessClassificationCard
    extends StatelessWidget {
  const _BusinessClassificationCard({
    required this.sector,
    required this.msicCode,
    required this.msicDescription,
    required this.onManage,
  });

  final String sector;
  final String? msicCode;
  final String? msicDescription;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            _InformationRow(
              icon: Icons
                  .factory_outlined,
              label:
                  'Industry sector',
              value:
                  sector.trim().isEmpty
                      ? 'Not provided'
                      : sector.trim(),
            ),

            const Divider(
              height: 28,
            ),

            _InformationRow(
              icon:
                  Icons.numbers_outlined,
              label: 'MSIC code',
              value:
                  (msicCode ?? '')
                          .trim()
                          .isEmpty
                      ? 'Not selected'
                      : msicCode!
                          .trim(),
            ),

            if ((msicDescription ?? '')
                .trim()
                .isNotEmpty) ...[
              const Divider(
                height: 28,
              ),

              _InformationRow(
                icon: Icons
                    .description_outlined,
                label:
                    'Classification',
                value:
                    msicDescription!
                        .trim(),
              ),
            ],

            const SizedBox(
              height: 18,
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onManage,
                icon: const Icon(
                  Icons
                      .settings_outlined,
                ),
                label: const Text(
                  'Manage business classification',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





class _InformationRow
    extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.navy
                .withValues(
              alpha: 0.06,
            ),
            borderRadius:
                BorderRadius.circular(
              6,
            ),
          ),
          child: Icon(
            icon,
            size: 19,
            color: AppColors.navy,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(
                  color:
                      AppColors.slate,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                value,
                style:
                    const TextStyle(
                  color:
                      AppColors.ink,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}





class _NotificationEmptyState
    extends StatelessWidget {
  const _NotificationEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(28),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: AppColors.slate,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              description,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    AppColors.slate,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}