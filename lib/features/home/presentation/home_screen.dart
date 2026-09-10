import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/app_state.dart';
import '../../../core/widgets.dart';
import '../../resource_marketplace/data/deal_request_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _dealRequestRepository = DealRequestRepository();
  final _notifications = <DealRequestRecord>[];
  StreamSubscription<List<DealRequestRecord>>? _notificationSubscription;
  bool _notificationsLoading = true;
  String? _notificationError;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToNotifications() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _dealRequestRepository
        .watchRelevantRequests()
        .listen(
          (records) {
            if (!mounted) return;
            setState(() {
              _notifications
                ..clear()
                ..addAll(records);
              _notificationsLoading = false;
              _notificationError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _notificationsLoading = false;
              _notificationError =
                  'Marketplace notifications could not be loaded.';
            });
            debugPrint('Home notification stream failed: $error');
          },
        );
  }

  int get _unreadCount =>
      _notifications.where(_isUnreadNotification).length;

  bool _isOwnerSide(DealRequestRecord request) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return userId != null && request.listingOwnerId == userId;
  }

  bool _isUnreadNotification(DealRequestRecord request) {
    if (_isOwnerSide(request)) {
      // Owners need attention for a new request or a requester cancellation.
      if (request.status != 'REQUEST SENT' && request.status != 'CANCELLED') {
        return false;
      }
      return request.ownerReadAt == null;
    }

    // Requesters only need a new notification when the other business has
    // accepted or rejected their request.
    if (request.status != 'ACCEPTED' && request.status != 'REJECTED') {
      return false;
    }
    return request.requesterReadAt == null;
  }

  Future<void> _markNotificationRead(DealRequestRecord request) async {
    if (!_isUnreadNotification(request)) return;

    try {
      if (_isOwnerSide(request)) {
        await _dealRequestRepository.markOwnerNotificationRead(request.id);
      } else {
        await _dealRequestRepository.markRequesterNotificationRead(request.id);
      }

      if (!mounted) return;
      final index = _notifications.indexWhere((item) => item.id == request.id);
      if (index >= 0) {
        final now = DateTime.now();
        setState(() {
          _notifications[index] = _isOwnerSide(request)
              ? request.copyWith(ownerReadAt: now)
              : request.copyWith(requesterReadAt: now);
        });
      }
    } catch (error) {
      debugPrint('Could not mark notification as read: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _showNotificationCentre() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notifications',
                            style: Theme.of(sheetContext).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _unreadCount == 0
                                ? 'You are all caught up.'
                                : '$_unreadCount unread marketplace ${_unreadCount == 1 ? 'notification' : 'notifications'}.',
                            style: const TextStyle(
                              color: AppColors.slate,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh notifications',
                      onPressed: _subscribeToNotifications,
                      icon: const Icon(Icons.refresh_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _notificationsLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _notificationError != null
                    ? _NotificationEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Notifications are unavailable.',
                        description: _notificationError!,
                      )
                    : _notifications.isEmpty
                    ? const _NotificationEmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: 'No notifications yet.',
                        description:
                            'New marketplace deal requests and responses will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final request = _notifications[index];
                          final unread = _isUnreadNotification(request);
                          return _NotificationTile(
                            request: request,
                            isOwnerSide: _isOwnerSide(request),
                            unread: unread,
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 220),
                              );
                              if (!mounted) return;
                              await _openNotification(request);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(DealRequestRecord request) async {
    await _markNotificationRead(request);
    if (!mounted) return;

    final isOwnerSide = _isOwnerSide(request);
    final canRespond = isOwnerSide && request.status == 'REQUEST SENT';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.chalk,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _notificationTitle(request, isOwnerSide),
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  _RequestStatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _notificationDescription(request, isOwnerSide),
                style: const TextStyle(
                  color: AppColors.slate,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              _NotificationDetailLine(
                label: 'Material',
                value: request.material,
              ),
              _NotificationDetailLine(
                label: isOwnerSide ? 'From' : 'Business',
                value: isOwnerSide ? request.requesterName : request.owner,
              ),
              _NotificationDetailLine(
                label: 'Quantity',
                value: request.quantity,
              ),
              _NotificationDetailLine(
                label: 'Location',
                value: request.location,
              ),
              _NotificationDetailLine(
                label: 'Created',
                value: _formatDateTime(request.sentAt),
              ),
              if (request.note.trim().isNotEmpty)
                _NotificationDetailLine(
                  label: 'Message',
                  value: request.note,
                ),
              if (request.responseNote.trim().isNotEmpty)
                _NotificationDetailLine(
                  label: 'Response',
                  value: request.responseNote,
                ),
              const SizedBox(height: 18),
              if (canRespond) ...[
                const Text(
                  'Respond to this request',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accepting makes the listing unavailable to other pending requests. Declining keeps the listing active.',
                  style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final reason = await _askRejectionReason();
                          if (reason == null || !mounted) return;
                          await _respondFromNotification(
                            sheetContext,
                            request,
                            accept: false,
                            reason: reason,
                          );
                        },
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _respondFromNotification(
                          sheetContext,
                          request,
                          accept: true,
                        ),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/marketplace');
                    },
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Open Marketplace'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _askRejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline this request?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 240,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'For example: Quantity is no longer available.',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Decline request'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _respondFromNotification(
    BuildContext sheetContext,
    DealRequestRecord request, {
    required bool accept,
    String reason = '',
  }) async {
    try {
      await _dealRequestRepository.respondToRequest(
        request.id,
        accept: accept,
        reason: reason,
      );
      await ref.read(appStateProvider.notifier).refreshSupabaseData();
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Request from ${request.requesterName} accepted.'
                : 'Request from ${request.requesterName} declined.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError ? error.message.toString() : '$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update this request: $message')),
      );
    }
  }

  String _notificationTitle(DealRequestRecord request, bool isOwnerSide) {
    if (isOwnerSide) {
      return switch (request.status) {
        'REQUEST SENT' => 'New deal request',
        'CANCELLED' => 'Deal request cancelled',
        'ACCEPTED' => 'Request accepted',
        'REJECTED' => 'Request closed',
        _ => 'Marketplace update',
      };
    }

    return switch (request.status) {
      'ACCEPTED' => 'Your deal request was accepted',
      'REJECTED' => 'Your deal request was declined',
      'CANCELLED' => 'Deal request cancelled',
      _ => 'Deal request sent',
    };
  }

  String _notificationDescription(DealRequestRecord request, bool isOwnerSide) {
    if (isOwnerSide) {
      return switch (request.status) {
        'REQUEST SENT' =>
          '${request.requesterName} requested ${request.quantity} of ${request.material}.',
        'CANCELLED' =>
          '${request.requesterName} cancelled the request for ${request.material}.',
        'ACCEPTED' =>
          'The request from ${request.requesterName} for ${request.material} was accepted.',
        'REJECTED' =>
          'The request from ${request.requesterName} for ${request.material} is closed.',
        _ => 'There is an update to your ${request.material} listing.',
      };
    }

    return switch (request.status) {
      'ACCEPTED' => '${request.owner} accepted your request for ${request.material}.',
      'REJECTED' => '${request.owner} declined your request for ${request.material}.',
      'CANCELLED' => 'Your request for ${request.material} was cancelled.',
      _ => 'Your request for ${request.material} was sent to ${request.owner}.',
    };
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final profile = state.profile;
    final now = DateTime.now();
    final profileReady = profile.hasRequiredProfileIdentity;
    final hasListings = state.activeListings > 0;
    final actionRoute = !profileReady
        ? '/resource-profile'
        : !hasListings
        ? '/resource-profile'
        : state.savedMatches == 0
        ? '/skill-match'
        : '/fair-price';
    final actionLabel = !profileReady
        ? 'Complete your profile'
        : !hasListings
        ? 'Add your first listing'
        : state.savedMatches == 0
        ? 'Find a training match'
        : 'Run a price check';
    final actionTitle = !profileReady
        ? 'Set up your business identity'
        : !hasListings
        ? 'Publish your first listing'
        : state.savedMatches == 0
        ? 'Build your team capability plan'
        : 'Pressure-test your next quote';
    final actionDescription = !profileReady
        ? 'Add your business name and industry sector before you unlock marketplace and matching features.'
        : !hasListings
        ? 'Publish a supply or demand listing so your business becomes discoverable in the local marketplace.'
        : state.savedMatches == 0
        ? 'Describe a workforce need and save a shortlist of suitable programmes.'
        : 'Use the benchmark-led advisor before you commit to a material price.';

    return AppShell(
      title: 'IndustryHub',
      actions: [
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh workspace',
            onPressed: () =>
                ref.read(appStateProvider.notifier).refreshSupabaseData(),
            icon: const Icon(Icons.refresh_outlined),
          ),
        IconButton(
          tooltip: _unreadCount == 0
              ? 'Open notifications'
              : 'Open notifications ($_unreadCount unread)',
          onPressed: _showNotificationCentre,
          icon: Badge.count(
            count: _unreadCount,
            isLabelVisible: _unreadCount > 0,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          tooltip: 'Open business profile',
          onPressed: () => context.go('/resource-profile'),
          icon: const Icon(Icons.account_circle_outlined),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: _signOut,
          icon: const Icon(Icons.logout_outlined),
        ),
        const SizedBox(width: 6),
      ],
      bottomNavigationBar: const _HomeNavigationBar(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(appStateProvider.notifier).refreshSupabaseData();
          _subscribeToNotifications();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
          children: [
            Eyebrow(_formatDate(now)),
            const SizedBox(height: 8),
            Text(
              '${_greeting(now)},',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            Text(
              '${profile.businessName}.',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 20),
            MetricStrip(
              metrics: [
                MapEntry('active listings', _twoDigits(state.activeListings)),
                MapEntry(
                  'negotiations in progress',
                  _twoDigits(state.negotiations),
                ),
                MapEntry(
                  'training matches saved',
                  _twoDigits(state.savedMatches),
                ),
              ],
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: _showNotificationCentre,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.22),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Badge.count(
                        count: _unreadCount,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        child: const Icon(Icons.notifications_active_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You have $_unreadCount unread marketplace ${_unreadCount == 1 ? 'notification' : 'notifications'}.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.north_east,
                        color: AppColors.amber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow(
                            'RECOMMENDED NEXT MOVE',
                            color: AppColors.amber,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            actionTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            actionDescription,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.slate,
                                  height: 1.35,
                                ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => context.push(actionRoute),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: Text(actionLabel),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            const SpecDivider(label: 'OPERATIONS CONSOLE'),
            const SizedBox(height: 16),
            ModuleCard(
              eyebrow: 'M1 / SKILLMATCH AI',
              title: 'Skill Advisor',
              description:
                  'Turn a hiring or upskilling need into a ranked shortlist of local programmes.',
              icon: Icons.psychology_outlined,
              onTap: () => context.push('/skill-match'),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              eyebrow: 'M2 / FAIRPRICE',
              title: 'Price Advisor',
              description:
                  'Pressure-test a proposed price with a transparent, benchmark-led negotiation.',
              icon: Icons.compare_arrows,
              accent: AppColors.amber,
              onTap: () => context.push('/fair-price'),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              eyebrow: 'M3 / RESOURCE PROFILES',
              title: 'My Profile & Listings',
              description:
                  'Keep your business profile verified and manage the materials you can supply or need.',
              icon: Icons.badge_outlined,
              accent: AppColors.green,
              onTap: () => context.push('/resource-profile'),
            ),
            const SizedBox(height: 12),
            ModuleCard(
              eyebrow: 'M4 / MARKETPLACE',
              title: 'ReSource Marketplace',
              description:
                  'Browse nearby industrial materials and move from discovery to a deal request.',
              icon: Icons.storefront_outlined,
              accent: AppColors.rust,
              onTap: () => context.push('/marketplace'),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      state.isLoading
                          ? Icons.sync_outlined
                          : Icons.cloud_done_outlined,
                      color: state.isLoading
                          ? AppColors.amber
                          : AppColors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.isLoading
                            ? 'Refreshing your workspace records from Supabase.'
                            : 'Your profile, listings, deal requests and notification state are synchronised with Supabase.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.slate,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String _greeting(DateTime date) {
    if (date.hour < 12) return 'Good morning';
    if (date.hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  static String _formatDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[date.weekday - 1].toUpperCase()} / ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.request,
    required this.isOwnerSide,
    required this.unread,
    required this.onTap,
  });

  final DealRequestRecord request;
  final bool isOwnerSide;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = isOwnerSide
        ? switch (request.status) {
            'REQUEST SENT' => 'New request from ${request.requesterName}',
            'CANCELLED' => '${request.requesterName} cancelled a request',
            'ACCEPTED' => 'Accepted request from ${request.requesterName}',
            'REJECTED' => 'Closed request from ${request.requesterName}',
            _ => 'Marketplace update',
          }
        : switch (request.status) {
            'ACCEPTED' => '${request.owner} accepted your request',
            'REJECTED' => '${request.owner} declined your request',
            'CANCELLED' => 'Your request was cancelled',
            _ => 'Request sent to ${request.owner}',
          };

    return Material(
      color: unread ? AppColors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: unread ? AppColors.line : Colors.transparent,
          ),
        ),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.navy.withValues(alpha: 0.08),
              child: const Icon(Icons.handshake_outlined, color: AppColors.navy),
            ),
            if (unread)
              const Positioned(
                right: -1,
                top: -1,
                child: CircleAvatar(
                  radius: 5,
                  backgroundColor: Colors.red,
                ),
              ),
          ],
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500),
        ),
        subtitle: Text(
          '${request.material} · ${request.quantity}\nTap to view details${isOwnerSide && request.status == 'REQUEST SENT' ? ' and respond' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.slate, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _RequestStatusChip extends StatelessWidget {
  const _RequestStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ACCEPTED' => AppColors.green,
      'REJECTED' || 'CANCELLED' => AppColors.rust,
      _ => AppColors.amber,
    };
    return StatusChip(label: status, color: color);
  }
}

class _NotificationDetailLine extends StatelessWidget {
  const _NotificationDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(height: 1.35)),
        ),
      ],
    ),
  );
}

class _NotificationEmptyState extends StatelessWidget {
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: AppColors.slate),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeNavigationBar extends StatelessWidget {
  const _HomeNavigationBar({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == 0) context.go('/home');
        if (index == 1) context.go('/marketplace');
        if (index == 2) context.go('/resource-profile');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view),
          label: 'Console',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: 'Market',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}