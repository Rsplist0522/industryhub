import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';
import '../core/widgets.dart';
import '../app/theme.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(appStateProvider).profile;

    String initials() {
      final name = profile.contactName ?? profile.businessName;
      if (name.trim().isEmpty) return 'IH';
      final parts = name.trim().split(' ');
      final a = parts.first.isNotEmpty ? parts.first[0] : '';
      final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
      return (a + b).toUpperCase();
    }

    return AppShell(
      title: 'Account',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                      ? CircleAvatar(
                          radius: 36,
                          backgroundImage: NetworkImage(profile.avatarUrl!),
                        )
                      : CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.navy,
                          child: Text(initials(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.businessName.isEmpty ? 'Untitled business' : profile.businessName, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(profile.role.isEmpty ? 'No role set' : profile.role, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            StatusChip(label: profile.verified ? 'VERIFIED' : 'UNVERIFIED', color: profile.verified ? AppColors.green : AppColors.rust),
                            const SizedBox(width: 10),
                            // MSIC details are intentionally omitted from the user account header
                            // to keep Normal User Profile distinct from M3.
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact & Account', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if ((profile.contactName ?? '').isNotEmpty) _InfoRow(label: 'Contact', value: profile.contactName!),
                  if ((profile.contactEmail ?? '').isNotEmpty) _InfoRow(label: 'Email', value: profile.contactEmail!),
                  if ((profile.contactPhone ?? '').isNotEmpty) _InfoRow(label: 'Phone', value: profile.contactPhone!),
                  const SizedBox(height: 12),
                  // Personal profile should not expose M3 business sector or MSIC info.
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showEditPersonalProfile(context, ref),
                          child: const Text('Edit personal profile'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.go('/resource-profile'),
                          child: const Text('Edit business & M3 profile'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SpecDivider(label: 'PRIVACY'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Privacy & data', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 8),
                  Text('Your account identity and contact details are stored in your Supabase workspace. Editing the M3 Resource profile only affects marketplace-visible business details.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditPersonalProfile(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(appStateProvider).profile;
  final nameController = TextEditingController(text: profile.contactName ?? '');
  final emailController = TextEditingController(text: profile.contactEmail ?? '');
  final phoneController = TextEditingController(text: profile.contactPhone ?? '');
  String? newAvatarUrl = profile.avatarUrl;

  final formKey = GlobalKey<FormState>();
  String? pickedLocalPath;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Edit personal profile'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      final picker = ImagePicker();
                      final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
                      if (xfile == null) return;
                      setState(() => pickedLocalPath = xfile.path);
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user == null) throw StateError('Sign in before updating avatar.');
                      final bucket = 'profile-images';
                      final remotePath = 'avatars/${user.id}/${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';
                      try {
                        final file = File(xfile.path);
                        await Supabase.instance.client.storage.from(bucket).upload(remotePath, file);
                        final publicUrl = Supabase.instance.client.storage.from(bucket).getPublicUrl(remotePath);
                        if (publicUrl.isNotEmpty) {
                          newAvatarUrl = publicUrl;
                          setState(() {});
                        } else {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Image uploaded but public URL unavailable.')));
                          }
                        }
                      } catch (error) {
                        debugPrint('Avatar upload failed: $error');
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
                        }
                      }
                    } catch (error) {
                      debugPrint('Pick image failed: $error');
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not pick image: $error')));
                      }
                    }
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.chalk,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                      image: pickedLocalPath != null
                          ? DecorationImage(image: FileImage(File(pickedLocalPath!)), fit: BoxFit.cover)
                          : (newAvatarUrl != null && newAvatarUrl!.isNotEmpty)
                              ? DecorationImage(image: NetworkImage(newAvatarUrl!), fit: BoxFit.cover)
                              : null,
                    ),
                    child: pickedLocalPath == null && (newAvatarUrl == null || newAvatarUrl!.isEmpty)
                        ? const Center(child: Icon(Icons.camera_alt_outlined))
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Contact name'),
                  validator: (v) => null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                final user = Supabase.instance.client.auth.currentUser;
                if (user == null) throw StateError('Sign in before updating profile.');
                await ref.read(appStateProvider.notifier).updateProfile(
                      contactName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                      contactEmail: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                      contactPhone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                      avatarUrl: newAvatarUrl,
                    );
                if (context.mounted) Navigator.pop(dialogContext);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personal profile saved.')));
              } catch (error) {
                debugPrint('Save personal profile failed: $error');
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $error')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 140,
                child: Text(label, style: const TextStyle(
                    color: AppColors.slate, fontSize: 13))),
            Expanded(child: Text(value)),
          ],
        ),
      );
}