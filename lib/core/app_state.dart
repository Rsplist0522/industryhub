// Firestore-backed application state for IndustryHub.
// Replaces local-only profile and listing mutations with Cloud Firestore reads
// and writes. Saved matches and FairPrice counters remain local for now.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Listing {
  const Listing({
    required this.id,
    required this.type,
    required this.material,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.description,
    required this.owner,
    required this.ownerId,
    this.verified = false,
  });

  final String id;
  final String type;
  final String material;
  final double quantity;
  final String unit;
  final String location;
  final String description;
  final String owner;
  final String ownerId;
  final bool verified;

  Listing copyWith({String? owner}) => Listing(
        id: id,
        type: type,
        material: material,
        quantity: quantity,
        unit: unit,
        location: location,
        description: description,
        owner: owner ?? this.owner,
        ownerId: ownerId,
        verified: verified,
      );

  factory Listing.fromFirestore(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawQuantity = data['quantity'];
    return Listing(
      id: document.id,
      type: data['type'] as String? ?? 'supply',
      material: data['material'] as String? ?? 'Unnamed material',
      quantity: rawQuantity is num ? rawQuantity.toDouble() : 0,
      unit: data['unit'] as String? ?? 'kg',
      location: data['location'] as String? ?? 'Location not specified',
      description: data['description'] as String? ?? '',
      owner: data['owner'] as String? ?? 'Unspecified business',
      ownerId: data['ownerId'] as String? ?? '',
      verified: data['verified'] as bool? ?? false,
    );
  }

  Map<String, Object?> toFirestore() => {
        'type': type,
        'material': material,
        'quantity': quantity,
        'unit': unit,
        'location': location,
        'description': description,
        'owner': owner,
        'ownerId': ownerId,
        'verified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class CompanyProfile {
  const CompanyProfile({
    this.businessName = 'Kencana Precision Works',
    this.sector = 'Precision manufacturing',
    this.role = 'Factory owner',
    this.verified = false,
  });

  final String businessName;
  final String sector;
  final String role;
  final bool verified;

  factory CompanyProfile.fromFirestore(Map<String, dynamic> data) => CompanyProfile(
        businessName: data['businessName'] as String? ?? 'Kencana Precision Works',
        sector: data['sector'] as String? ?? 'Precision manufacturing',
        role: data['role'] as String? ?? 'Factory owner',
        verified: data['verified'] as bool? ?? false,
      );

  CompanyProfile copyWith({String? businessName, String? sector, String? role, bool? verified}) => CompanyProfile(
        businessName: businessName ?? this.businessName,
        sector: sector ?? this.sector,
        role: role ?? this.role,
        verified: verified ?? this.verified,
      );

  Map<String, Object?> toFirestore() => {
        'businessName': businessName,
        'sector': sector,
        'role': role,
        'verified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class IndustryHubState {
  const IndustryHubState({
    this.profile = const CompanyProfile(),
    this.listings = const [],
    this.savedMatches = 2,
    this.negotiations = 1,
    this.isLoading = true,
  });

  final CompanyProfile profile;
  final List<Listing> listings;
  final int savedMatches;
  final int negotiations;
  final bool isLoading;

  int get activeListings => listings.where((item) => item.owner == profile.businessName).length;

  IndustryHubState copyWith({
    CompanyProfile? profile,
    List<Listing>? listings,
    int? savedMatches,
    int? negotiations,
    bool? isLoading,
  }) =>
      IndustryHubState(
        profile: profile ?? this.profile,
        listings: listings ?? this.listings,
        savedMatches: savedMatches ?? this.savedMatches,
        negotiations: negotiations ?? this.negotiations,
        isLoading: isLoading ?? this.isLoading,
      );
}

class IndustryHubNotifier extends Notifier<IndustryHubState> {
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  var _disposed = false;

  @override
  IndustryHubState build() {
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(_loadProfileAndListings);
    return const IndustryHubState();
  }

  Future<void> _loadProfileAndListings() async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final profileReference = _firestore.collection('users').doc(user.uid);
      final profileSnapshot = await profileReference.get();
      final profile = profileSnapshot.exists
          ? CompanyProfile.fromFirestore(profileSnapshot.data() ?? const <String, dynamic>{})
          : const CompanyProfile();

      if (!profileSnapshot.exists) {
        await profileReference.set({...profile.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
      }

      final listingSnapshot = await _firestore.collection('listings').get();
      final listings = listingSnapshot.docs.map(Listing.fromFirestore).toList();
      if (_disposed) return;
      state = state.copyWith(profile: profile, listings: listings, isLoading: false);
    } catch (error) {
      debugPrint('IndustryHub Firestore load failed: $error');
      if (!_disposed) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshFirestoreData() => _loadProfileAndListings();

  Future<void> updateProfile({String? businessName, String? sector, String? role}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final updatedProfile = state.profile.copyWith(
      businessName: businessName?.trim().isNotEmpty == true ? businessName!.trim() : null,
      sector: sector?.trim().isNotEmpty == true ? sector!.trim() : null,
      role: role?.trim().isNotEmpty == true ? role!.trim() : null,
    );

    try {
      await _firestore.collection('users').doc(user.uid).set(updatedProfile.toFirestore(), SetOptions(merge: true));
      var updatedListings = state.listings;
      if (updatedProfile.businessName != state.profile.businessName) {
        final ownedSnapshot = await _firestore.collection('listings').where('ownerId', isEqualTo: user.uid).get();
        final batch = _firestore.batch();
        for (final document in ownedSnapshot.docs) {
          batch.update(document.reference, {'owner': updatedProfile.businessName, 'updatedAt': FieldValue.serverTimestamp()});
        }
        if (ownedSnapshot.docs.isNotEmpty) await batch.commit();
        updatedListings = state.listings.map((listing) => listing.ownerId == user.uid ? listing.copyWith(owner: updatedProfile.businessName) : listing).toList();
      }
      if (_disposed) return;
      state = state.copyWith(profile: updatedProfile, listings: updatedListings);
    } catch (error) {
      debugPrint('IndustryHub profile update failed: $error');
    }
  }

  Future<void> addListing({
    required String type,
    required String material,
    required double quantity,
    required String unit,
    required String location,
    required String description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final reference = _firestore.collection('listings').doc();
    final listing = Listing(
      id: reference.id,
      type: type,
      material: material.trim(),
      quantity: quantity,
      unit: unit,
      location: location.trim(),
      description: description.trim(),
      owner: state.profile.businessName,
      ownerId: user.uid,
      verified: state.profile.verified,
    );

    try {
      await reference.set({...listing.toFirestore(), 'createdAt': FieldValue.serverTimestamp()});
      if (_disposed) return;
      state = state.copyWith(listings: [listing, ...state.listings]);
    } catch (error) {
      debugPrint('IndustryHub listing creation failed: $error');
    }
  }

  Future<void> removeListing(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('listings').doc(id).delete();
      if (_disposed) return;
      state = state.copyWith(listings: state.listings.where((item) => item.id != id).toList());
    } catch (error) {
      debugPrint('IndustryHub listing removal failed: $error');
    }
  }

  void saveMatch() {
    state = state.copyWith(savedMatches: state.savedMatches + 1);
  }

  void startNegotiation() {
    state = state.copyWith(negotiations: state.negotiations + 1);
  }
}

final appStateProvider = NotifierProvider<IndustryHubNotifier, IndustryHubState>(IndustryHubNotifier.new);
