// Supabase persistence for M4 Marketplace outgoing deal requests.
// The public Marketplace UI stays unchanged and imports this file as
// deal_request_repository.dart after replacement.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_state.dart';

class DealRequestRecord {
  const DealRequestRecord({
    required this.id,
    required this.listingId,
    required this.requesterId,
    required this.listingOwnerId,
    required this.material,
    required this.owner,
    required this.requesterName,
    required this.location,
    required this.quantity,
    required this.note,
    required this.responseNote,
    required this.status,
    required this.sentAt,
  });

  final String id;
  final String listingId;
  final String requesterId;
  final String listingOwnerId;
  final String material;
  final String owner;
  // Snapshot of the requesting business's name, so the listing owner has
  // something to show besides a bare user id when reviewing a request.
  final String requesterName;
  final String location;
  final String quantity;
  final String note;
  final String responseNote;
  final String status;
  final DateTime sentAt;

  factory DealRequestRecord.fromSupabase(Map<String, dynamic> data) =>
      DealRequestRecord(
        id: data['id'] as String? ?? '',
        listingId: data['listing_id'] as String? ?? '',
        requesterId: data['requester_id'] as String? ?? '',
        listingOwnerId: data['listing_owner_id'] as String? ?? '',
        material: data['material'] as String? ?? 'Unnamed material',
        owner: data['owner'] as String? ?? 'Unspecified business',
        requesterName:
            data['requester_name'] as String? ?? 'A ReSource business',
        location: data['location'] as String? ?? 'Location not specified',
        quantity: data['quantity'] as String? ?? '',
        note: data['note'] as String? ?? '',
        responseNote: data['response_note'] as String? ?? '',
        status: data['status'] as String? ?? 'REQUEST SENT',
        sentAt:
            DateTime.tryParse(data['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  DealRequestRecord copyWith({String? status, String? responseNote}) => DealRequestRecord(
    id: id,
    listingId: listingId,
    requesterId: requesterId,
    listingOwnerId: listingOwnerId,
    material: material,
    owner: owner,
    requesterName: requesterName,
    location: location,
    quantity: quantity,
    note: note,
    responseNote: responseNote ?? this.responseNote,
    status: status ?? this.status,
    sentAt: sentAt,
  );
}

class DealRequestRepository {
  DealRequestRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<DealRequestRecord> sendRequest({
    required Listing listing,
    required String note,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError(
        'You need to be signed in before sending a deal request.',
      );
    }
    if (listing.ownerId == user.id) {
      throw StateError('You cannot send a request to your own listing.');
    }

    final requesterProfile = await _supabase
        .from('profiles')
        .select('business_name, sector')
        .eq('user_id', user.id)
        .maybeSingle();
    final requesterName =
        (requesterProfile?['business_name'] as String?)?.trim();
    final requesterSector =
        (requesterProfile?['sector'] as String?)?.trim();
    if ((requesterName == null || requesterName.isEmpty) ||
        (requesterSector == null || requesterSector.isEmpty)) {
      throw StateError(
        'Complete your business name and industry sector before sending a deal request.',
      );
    }

    final createdRow = await _supabase
        .from('deal_requests')
        .insert({
          'listing_id': listing.id,
          'requester_id': user.id,
          'listing_owner_id': listing.ownerId,
          'material': listing.material,
          'owner': listing.owner,
          'requester_name': requesterName,
          'location': listing.location,
          'quantity': '${listing.quantity.toStringAsFixed(0)} ${listing.unit}',
          'note': note.trim(),
        })
        .select()
        .single();

    return DealRequestRecord.fromSupabase(
      Map<String, dynamic>.from(createdRow),
    );
  }

  Future<List<DealRequestRecord>> fetchOutgoingRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];

    final rows = await _supabase
        .from('deal_requests')
        .select()
        .eq('requester_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => DealRequestRecord.fromSupabase(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<void> cancelRequest(String requestId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before cancelling a deal request.');
    }

    await _supabase
        .from('deal_requests')
        .update({
          'status': 'CANCELLED',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('requester_id', user.id);
  }

  /// Requests sent TO listings this user owns, i.e. the ones only the
  /// listing owner is allowed to accept or reject.
  Future<List<DealRequestRecord>> fetchIncomingRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];

    final rows = await _supabase
        .from('deal_requests')
        .select()
        .eq('listing_owner_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (row) => DealRequestRecord.fromSupabase(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  /// Accept or reject a request sent to one of the current user's listings.
  /// The `.eq('listing_owner_id', user.id)` guard, backed by the matching
  /// RLS policy, is what stops anyone but the listing owner from doing this.
  Future<void> respondToRequest(
    String requestId, {
    required bool accept,
    String reason = '',
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before responding to a deal request.');
    }

    final requestRow = await _supabase
        .from('deal_requests')
        .select('listing_id')
        .eq('id', requestId)
        .eq('listing_owner_id', user.id)
        .maybeSingle();

    if (requestRow == null) {
      throw StateError('This request is no longer available to accept.');
    }

    final listingId = requestRow['listing_id'] as String?;

    await _supabase
        .from('deal_requests')
        .update({
          'status': accept ? 'ACCEPTED' : 'REJECTED',
          'response_note': accept ? '' : reason.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('listing_owner_id', user.id);

    if (accept && listingId != null && listingId.isNotEmpty) {
      await _supabase
          .from('deal_requests')
          .update({
            'status': 'REJECTED',
            'response_note': 'This listing was accepted by another business and is no longer available.',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('listing_id', listingId)
          .neq('id', requestId)
          .inFilter('status', ['REQUEST SENT']);

      await _supabase.from('listings').delete().eq('id', listingId);
    }
  }

  /// Live view of this user's outgoing requests. Used instead of a one-shot
  /// fetch so the status updates on screen the moment the other business
  /// accepts, rejects, or the record otherwise changes — no manual refresh.
  Stream<List<DealRequestRecord>> watchOutgoingRequests() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream<List<DealRequestRecord>>.value(const []);

    return _supabase
        .from('deal_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => DealRequestRecord.fromSupabase(
                    Map<String, dynamic>.from(row),
                  ))
              .toList(),
        );
  }

  /// Live view of requests sent to this user's listings, so a new incoming
  /// request (or a cancellation) shows up without a manual refresh.
  Stream<List<DealRequestRecord>> watchIncomingRequests() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream<List<DealRequestRecord>>.value(const []);

    return _supabase
        .from('deal_requests')
        .stream(primaryKey: ['id'])
        .eq('listing_owner_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map((row) => DealRequestRecord.fromSupabase(
                    Map<String, dynamic>.from(row),
                  ))
              .toList(),
        );
  }
}

