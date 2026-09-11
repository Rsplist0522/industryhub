

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
    this.requesterReadAt,
    this.ownerReadAt,
    this.quantityValue,
    this.unit = 'kg',
    this.askingPricePerKg,
  });

  final String id;
  final String listingId;
  final String requesterId;
  final String listingOwnerId;
  final String material;
  final String owner;
  final String requesterName;
  final String location;


  final String quantity;


  final double? quantityValue;
  final String unit;
  final double? askingPricePerKg;

  final String note;



  final String responseNote;

  final String status;
  final DateTime sentAt;
  final DateTime? requesterReadAt;
  final DateTime? ownerReadAt;

  factory DealRequestRecord.fromSupabase(Map<String, dynamic> data) {
    final rawQuantityValue = data['quantity_value'];
    final rawAskingPrice = data['asking_price_per_kg'];

    return DealRequestRecord(
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
      quantityValue: rawQuantityValue is num
          ? rawQuantityValue.toDouble()
          : double.tryParse('$rawQuantityValue'),
      unit: data['unit'] as String? ?? 'kg',
      askingPricePerKg: rawAskingPrice is num
          ? rawAskingPrice.toDouble()
          : double.tryParse('$rawAskingPrice'),
      note: data['note'] as String? ?? '',
      responseNote: data['response_note'] as String? ?? '',
      status: data['status'] as String? ?? 'REQUEST SENT',
      sentAt:
          DateTime.tryParse(data['created_at'] as String? ?? '') ??
          DateTime.now(),
      requesterReadAt: DateTime.tryParse(
        data['requester_read_at'] as String? ?? '',
      ),
      ownerReadAt: DateTime.tryParse(
        data['owner_read_at'] as String? ?? '',
      ),
    );
  }

  DealRequestRecord copyWith({
    String? status,
    String? responseNote,
    DateTime? requesterReadAt,
    DateTime? ownerReadAt,
    double? quantityValue,
    String? unit,
    double? askingPricePerKg,
  }) =>
      DealRequestRecord(
        id: id,
        listingId: listingId,
        requesterId: requesterId,
        listingOwnerId: listingOwnerId,
        material: material,
        owner: owner,
        requesterName: requesterName,
        location: location,
        quantity: quantity,
        quantityValue: quantityValue ?? this.quantityValue,
        unit: unit ?? this.unit,
        askingPricePerKg: askingPricePerKg ?? this.askingPricePerKg,
        note: note,
        responseNote: responseNote ?? this.responseNote,
        status: status ?? this.status,
        sentAt: sentAt,
        requesterReadAt: requesterReadAt ?? this.requesterReadAt,
        ownerReadAt: ownerReadAt ?? this.ownerReadAt,
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

    try {
      final createdRow = await _supabase.rpc(
        'create_deal_request',
        params: {
          'p_listing_id': listing.id,
          'p_note': note.trim(),
        },
      );

      if (createdRow is! Map) {
        throw StateError('The deal request could not be created.');
      }

      return DealRequestRecord.fromSupabase(
        Map<String, dynamic>.from(createdRow),
      );
    } on PostgrestException catch (error) {
      throw StateError(error.message);
    }
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

  Future<List<DealRequestRecord>> fetchRelevantRequests() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];

    final rows = await _supabase
        .from('deal_requests')
        .select()
        .or(
          'requester_id.eq.${user.id},listing_owner_id.eq.${user.id}',
        )
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

    try {
      await _supabase.rpc(
        'cancel_deal_request',
        params: {'p_request_id': requestId},
      );
    } on PostgrestException catch (error) {
      throw StateError(error.message);
    }
  }

  Future<void> respondToRequest(
    String requestId, {
    required bool accept,
    String reason = '',
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before responding to a deal request.');
    }

    if (!accept && reason.trim().isEmpty) {
      throw StateError('Choose a decline reason before rejecting the request.');
    }

    try {
      await _supabase.rpc(
        'respond_to_deal_request',
        params: {
          'p_request_id': requestId,
          'p_accept': accept,
          'p_reason': reason.trim(),
        },
      );
    } on PostgrestException catch (error) {
      throw StateError(error.message);
    }
  }

  Future<void> markOwnerNotificationRead(String requestId) async {
    try {
      await _supabase.rpc(
        'mark_deal_request_owner_read',
        params: {'p_request_id': requestId},
      );
    } on PostgrestException catch (error) {
      throw StateError(error.message);
    }
  }

  Future<void> markRequesterNotificationRead(String requestId) async {
    try {
      await _supabase.rpc(
        'mark_deal_request_requester_read',
        params: {'p_request_id': requestId},
      );
    } on PostgrestException catch (error) {
      throw StateError(error.message);
    }
  }

  Stream<List<DealRequestRecord>> watchOutgoingRequests() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream<List<DealRequestRecord>>.value(const []);
    }

    return _supabase
        .from('deal_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map(
                (row) => DealRequestRecord.fromSupabase(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(),
        );
  }

  Stream<List<DealRequestRecord>> watchIncomingRequests() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream<List<DealRequestRecord>>.value(const []);
    }

    return _supabase
        .from('deal_requests')
        .stream(primaryKey: ['id'])
        .eq('listing_owner_id', user.id)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map(
                (row) => DealRequestRecord.fromSupabase(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(),
        );
  }

  Stream<List<DealRequestRecord>> watchRelevantRequests() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream<List<DealRequestRecord>>.value(const []);
    }


    return _supabase
        .from('deal_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .map(
                (row) => DealRequestRecord.fromSupabase(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList(),
        );
  }
}
