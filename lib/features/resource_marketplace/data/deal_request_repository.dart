// Firestore repository for Marketplace deal requests.
// Requests are persistent records; a request is not a completed transaction.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  factory DealRequestRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawCreatedAt = data['createdAt'];
    return DealRequestRecord(
      id: document.id,
      listingId: data['listingId'] as String? ?? '',
      requesterId: data['requesterId'] as String? ?? '',
      listingOwnerId: data['listingOwnerId'] as String? ?? '',
      material: data['material'] as String? ?? 'Unnamed material',
      owner: data['owner'] as String? ?? 'Unspecified business',
      location: data['location'] as String? ?? 'Location not specified',
      quantity: data['quantity'] as String? ?? '',
      note: data['note'] as String? ?? '',
      status: data['status'] as String? ?? 'REQUEST SENT',
      sentAt: rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : DateTime.now(),
    );
  }
}

class DealRequestRepository {
  DealRequestRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<DealRequestRecord> sendRequest({required Listing listing, required String note}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('You need to be signed in before sending a deal request.');
    if (listing.ownerId == user.uid) throw StateError('You cannot send a deal request to your own listing.');

    final reference = _firestore.collection('deal_requests').doc();
    await reference.set({
      'listingId': listing.id,
      'requesterId': user.uid,
      'listingOwnerId': listing.ownerId,
      'material': listing.material,
      'owner': listing.owner,
      'location': listing.location,
      'quantity': '${listing.quantity.toStringAsFixed(0)} ${listing.unit}',
      'note': note.trim(),
      'status': 'REQUEST SENT',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return DealRequestRecord(
      id: reference.id,
      listingId: listing.id,
      requesterId: user.uid,
      listingOwnerId: listing.ownerId,
      material: listing.material,
      owner: listing.owner,
      location: listing.location,
      quantity: '${listing.quantity.toStringAsFixed(0)} ${listing.unit}',
      note: note.trim(),
      status: 'REQUEST SENT',
      sentAt: DateTime.now(),
    );
  }

  Future<List<DealRequestRecord>> fetchOutgoingRequests() async {
    final user = _auth.currentUser;
    if (user == null) return const [];

    final snapshot = await _firestore
        .collection('deal_requests')
        .where('requesterId', isEqualTo: user.uid)
        .get();
    final requests = snapshot.docs.map(DealRequestRecord.fromFirestore).toList();
    requests.sort((newer, older) => older.sentAt.compareTo(newer.sentAt));
    return requests;
  }
}
