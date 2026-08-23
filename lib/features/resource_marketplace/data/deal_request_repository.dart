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
    required this.location,
    required this.quantity,
    required this.note,
    required this.status,
    required this.sentAt,
  });

  final String id;
  final String listingId;
  final String requesterId;
  final String listingOwnerId;
  final String material;
  final String owner;
  final String location;
  final String quantity;
  final String note;
  final String status;
  final DateTime sentAt;

  factory DealRequestRecord.fromSupabase(Map<String, dynamic> data) => DealRequestRecord(
        id: data['id'] as String? ?? '',
        listingId: data['listing_id'] as String? ?? '',
        requesterId: data['requester_id'] as String? ?? '',
        listingOwnerId: data['listing_owner_id'] as String? ?? '',
        material: data['material'] as String? ?? 'Unnamed material',
        owner: data['owner'] as String? ?? 'Unspecified business',
        location: data['location'] as String? ?? 'Location not specified',
        quantity: data['quantity'] as String? ?? '',
        note: data['note'] as String? ?? '',
        status: data['status'] as String? ?? 'REQUEST SENT',
        sentAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class DealRequestRepository {
  DealRequestRepository({SupabaseClient? supabase}) : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<DealRequestRecord> sendRequest({required Listing listing, required String note}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('You need to be signed in before sending a deal request.');
    if (listing.ownerId == user.id) throw StateError('You cannot send a request to your own listing.');

    final createdRow = await _supabase
        .from('deal_requests')
        .insert({
          'listing_id': listing.id,
          'requester_id': user.id,
          'listing_owner_id': listing.ownerId,
          'material': listing.material,
          'owner': listing.owner,
          'location': listing.location,
          'quantity': '${listing.quantity.toStringAsFixed(0)} ${listing.unit}',
          'note': note.trim(),
        })
        .select()
        .single();

    return DealRequestRecord.fromSupabase(Map<String, dynamic>.from(createdRow));
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
        .map((row) => DealRequestRecord.fromSupabase(Map<String, dynamic>.from(row as Map)))
        .toList();
  }
}
