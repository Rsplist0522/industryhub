// Supabase-backed application state for IndustryHub.
// Profile and marketplace records are scoped to the signed-in workspace while
// the UI continues to expose simple immutable models.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.askingPricePerKg,
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
  final double? askingPricePerKg;

  Listing copyWith({String? owner, double? askingPricePerKg}) => Listing(
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
        askingPricePerKg: askingPricePerKg ?? this.askingPricePerKg,
      );

  factory Listing.fromSupabase(Map<String, dynamic> data) {
    final rawQuantity = data['quantity'];
    return Listing(
      id: data['id'] as String? ?? '',
      type: data['type'] as String? ?? 'supply',
      material: data['material'] as String? ?? 'Unnamed material',
      quantity: rawQuantity is num ? rawQuantity.toDouble() : double.tryParse('$rawQuantity') ?? 0,
      unit: data['unit'] as String? ?? 'kg',
      location: data['location'] as String? ?? 'Location not specified',
      description: data['description'] as String? ?? '',
      owner: data['owner'] as String? ?? 'Unspecified business',
      ownerId: data['owner_id'] as String? ?? '',
      verified: data['verified'] as bool? ?? false,
      askingPricePerKg: (data['asking_price_per_kg'] as num?)?.toDouble(),
    );
  }
}

class CompanyProfile {
  const CompanyProfile({
    this.businessName = 'Kencana Precision Works',
    this.sector = 'Precision manufacturing',
    this.role = 'Factory owner',
    this.verified = false,
    this.msicCode,
    this.msicDescription,
  });

  final String businessName;
  final String sector;
  final String role;
  final bool verified;
  final String? msicCode;
  final String? msicDescription;

  factory CompanyProfile.fromSupabase(Map<String, dynamic> data) => CompanyProfile(
        businessName: data['business_name'] as String? ?? 'Kencana Precision Works',
        sector: data['sector'] as String? ?? 'Precision manufacturing',
        role: data['role'] as String? ?? 'Factory owner',
        verified: data['verified'] as bool? ?? false,
        msicCode: data['msic_code'] as String?,
        msicDescription: data['msic_description'] as String?,
      );

  CompanyProfile copyWith({String? businessName, String? sector, String? role, bool? verified, String? msicCode, String? msicDescription}) => CompanyProfile(
        businessName: businessName ?? this.businessName,
        sector: sector ?? this.sector,
        role: role ?? this.role,
        verified: verified ?? this.verified,
        msicCode: msicCode ?? this.msicCode,
        msicDescription: msicDescription ?? this.msicDescription,
      );
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
  late final SupabaseClient _supabase;
  var _disposed = false;

  @override
  IndustryHubState build() {
    _supabase = Supabase.instance.client;
    ref.onDispose(() => _disposed = true);
    Future<void>.microtask(_loadProfileAndListings);
    return const IndustryHubState();
  }

  Future<User?> _ensureSignedInUser() async {
    final existingUser = _supabase.auth.currentUser;
    if (existingUser != null) return existingUser;
    final response = await _supabase.auth.signInAnonymously();
    return response.user;
  }

  Future<void> _loadProfileAndListings() async {
    if (!_disposed) state = state.copyWith(isLoading: true);
    try {
      final user = await _ensureSignedInUser();
      if (user == null) {
        if (!_disposed) state = state.copyWith(isLoading: false);
        return;
      }

      final profileRow = await _supabase.from('profiles').select().eq('user_id', user.id).maybeSingle();
      final profile = profileRow == null ? const CompanyProfile() : CompanyProfile.fromSupabase(profileRow);

      if (profileRow == null) {
        await _supabase.from('profiles').insert({
          'user_id': user.id,
          'business_name': profile.businessName,
          'sector': profile.sector,
          'role': profile.role,
        });
      }

      final listingRows = await _supabase.from('listings').select().order('created_at', ascending: false);
      final listings = (listingRows as List)
          .map((row) => Listing.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();

      if (_disposed) return;
      state = state.copyWith(profile: profile, listings: listings, isLoading: false);
    } catch (error) {
      debugPrint('IndustryHub Supabase load failed: $error');
      if (!_disposed) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refreshSupabaseData() => _loadProfileAndListings();

  Future<void> updateProfile({String? businessName, String? sector, String? role, String? msicCode, String? msicDescription}) async {
    final user = await _ensureSignedInUser();
    if (user == null) return;

    final updatedProfile = state.profile.copyWith(
      businessName: businessName?.trim().isNotEmpty == true ? businessName!.trim() : null,
      sector: sector?.trim().isNotEmpty == true ? sector!.trim() : null,
      role: role?.trim().isNotEmpty == true ? role!.trim() : null,
      msicCode: msicCode?.trim().isNotEmpty == true ? msicCode!.trim() : null,
      msicDescription: msicDescription?.trim().isNotEmpty == true ? msicDescription!.trim() : null,
    );

    try {
      await _supabase.from('profiles').update({
        'business_name': updatedProfile.businessName,
        'sector': updatedProfile.sector,
        'role': updatedProfile.role,
        'msic_code': updatedProfile.msicCode,
        'msic_description': updatedProfile.msicDescription,
      }).eq('user_id', user.id);

      var updatedListings = state.listings;
      if (updatedProfile.businessName != state.profile.businessName) {
        await _supabase.from('listings').update({'owner': updatedProfile.businessName}).eq('owner_id', user.id);
        updatedListings = state.listings
            .map((listing) => listing.ownerId == user.id ? listing.copyWith(owner: updatedProfile.businessName) : listing)
            .toList();
      }

      if (_disposed) return;
      state = state.copyWith(profile: updatedProfile, listings: updatedListings);
    } catch (error) {
      debugPrint('IndustryHub Supabase profile update failed: $error');
    }
  }

  Future<void> addListing({
    required String type,
    required String material,
    required double quantity,
    required String unit,
    required String location,
    required String description,
    double? askingPricePerKg,
  }) async {
    final user = await _ensureSignedInUser();
    if (user == null) return;

    try {
      final createdRow = await _supabase
          .from('listings')
          .insert({
            'type': type,
            'material': material.trim(),
            'quantity': quantity,
            'unit': unit,
            'location': location.trim(),
            'description': description.trim(),
            'asking_price_per_kg': askingPricePerKg,
            'owner': state.profile.businessName,
            'owner_id': user.id,
          })
          .select()
          .single();
      final listing = Listing.fromSupabase(Map<String, dynamic>.from(createdRow));
      if (_disposed) return;
      state = state.copyWith(listings: [listing, ...state.listings]);
    } catch (error) {
      debugPrint('IndustryHub Supabase listing creation failed: $error');
    }
  }

  Future<void> removeListing(String id) async {
    final user = await _ensureSignedInUser();
    if (user == null) return;

    try {
      await _supabase.from('listings').delete().eq('id', id).eq('owner_id', user.id);
      if (_disposed) return;
      state = state.copyWith(listings: state.listings.where((item) => item.id != id).toList());
    } catch (error) {
      debugPrint('IndustryHub Supabase listing removal failed: $error');
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
