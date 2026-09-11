import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_access.dart';

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
    this.status = 'ACTIVE',
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
  final String status;

  String get quantityLabel {
    final text = quantity.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Listing copyWith({
    String? owner,
    bool? verified,
    double? askingPricePerKg,
    String? status,
  }) =>
      Listing(
        id: id,
        type: type,
        material: material,
        quantity: quantity,
        unit: unit,
        location: location,
        description: description,
        owner: owner ?? this.owner,
        ownerId: ownerId,
        verified: verified ?? this.verified,
        askingPricePerKg:
            askingPricePerKg ?? this.askingPricePerKg,
        status: status ?? this.status,
      );

  factory Listing.fromSupabase(
    Map<String, dynamic> data,
  ) {
    final rawQuantity = data['quantity'];

    return Listing(
      id: data['id'] as String? ?? '',
      type: data['type'] as String? ?? 'supply',
      material:
          data['material'] as String? ?? 'Unnamed material',
      quantity: rawQuantity is num
          ? rawQuantity.toDouble()
          : double.tryParse('$rawQuantity') ?? 0,
      unit: data['unit'] as String? ?? 'kg',
      location: data['location'] as String? ??
          'Location not specified',
      description: data['description'] as String? ?? '',
      owner: data['owner'] as String? ??
          'Unspecified business',
      ownerId: data['owner_id'] as String? ?? '',
      verified: data['verified'] as bool? ?? false,
      askingPricePerKg:
          (data['asking_price_per_kg'] as num?)
              ?.toDouble(),
      status: data['status'] as String? ?? 'ACTIVE',
    );
  }
}

class CompanyProfile {
  const CompanyProfile({
    this.businessName = '',
    this.sector = '',
    this.role = '',
    this.verified = false,
    this.msicCode,
    this.msicDescription,
    this.contactName,
    this.contactPhone,
    this.profileImagePath,
  });

  final String businessName;
  final String sector;
  final String role;
  final bool verified;

  final String? msicCode;
  final String? msicDescription;

  final String? contactName;
  final String? contactPhone;

  final String? profileImagePath;

  bool get hasRequiredProfileIdentity =>
      businessName.trim().isNotEmpty &&
      sector.trim().isNotEmpty;

  bool get isProfileComplete =>
    businessName.trim().isNotEmpty &&
    (contactName ?? '').trim().isNotEmpty &&
    (contactPhone ?? '').trim().isNotEmpty &&
    sector.trim().isNotEmpty &&
    role.trim().isNotEmpty &&
    (msicCode ?? '').trim().isNotEmpty;

  factory CompanyProfile.fromSupabase(
    Map<String, dynamic> data,
  ) =>
      CompanyProfile(
        businessName:
            data['business_name'] as String? ?? '',
        sector: data['sector'] as String? ?? '',
        role: data['role'] as String? ?? '',
        verified: data['verified'] as bool? ?? false,
        msicCode: data['msic_code'] as String?,
        msicDescription:
            data['msic_description'] as String?,
        contactName: data['contact_name'] as String?,
        contactPhone:
            data['contact_phone'] as String?,
        profileImagePath:
            data['profile_image_url'] as String?,
      );

  CompanyProfile copyWith({
    String? businessName,
    String? sector,
    String? role,
    bool? verified,
    String? msicCode,
    String? msicDescription,
    String? contactName,
    String? contactPhone,
    String? profileImagePath,
    bool clearProfileImage = false,
  }) =>
      CompanyProfile(
        businessName:
            businessName ?? this.businessName,
        sector: sector ?? this.sector,
        role: role ?? this.role,
        verified: verified ?? this.verified,
        msicCode: msicCode ?? this.msicCode,
        msicDescription:
            msicDescription ?? this.msicDescription,
        contactName:
            contactName ?? this.contactName,
        contactPhone:
            contactPhone ?? this.contactPhone,
        profileImagePath: clearProfileImage
            ? null
            : profileImagePath ??
                this.profileImagePath,
      );
}

class IndustryHubState {
  const IndustryHubState({
    this.profile = const CompanyProfile(),
    this.listings = const [],
    this.savedMatches = 0,
    this.negotiations = 0,
    this.isLoading = true,
    this.userId = '',
  });

  final CompanyProfile profile;
  final List<Listing> listings;
  final int savedMatches;
  final int negotiations;
  final bool isLoading;
  final String userId;

  int get activeListings => listings
      .where(
        (item) =>
            item.ownerId == userId &&
            item.status == 'ACTIVE',
      )
      .length;

  IndustryHubState copyWith({
    CompanyProfile? profile,
    List<Listing>? listings,
    int? savedMatches,
    int? negotiations,
    bool? isLoading,
    String? userId,
  }) =>
      IndustryHubState(
        profile: profile ?? this.profile,
        listings: listings ?? this.listings,
        savedMatches:
            savedMatches ?? this.savedMatches,
        negotiations:
            negotiations ?? this.negotiations,
        isLoading: isLoading ?? this.isLoading,
        userId: userId ?? this.userId,
      );
}

class IndustryHubNotifier
    extends Notifier<IndustryHubState> {
  late final SupabaseClient _supabase;
  StreamSubscription<AuthState>? _authSubscription;

  var _disposed = false;

  @override
  IndustryHubState build() {
    _supabase = Supabase.instance.client;

    _authSubscription =
        _supabase.auth.onAuthStateChange.listen(
      (authState) {
        switch (authState.event) {
          case AuthChangeEvent.initialSession:
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.signedOut:
          case AuthChangeEvent.userUpdated:
            _loadProfileAndListings();
          default:
            break;
        }
      },
    );

    ref.onDispose(() {
      _disposed = true;
      _authSubscription?.cancel();
    });

    Future<void>.microtask(
      _loadProfileAndListings,
    );

    return const IndustryHubState();
  }

  Future<User?> _ensureSignedInUser() async {
    if (!hasVerifiedSupabaseSession(_supabase)) {
      return null;
    }

    return _supabase.auth.currentUser;
  }

  Future<void> _loadProfileAndListings() async {
    if (!_disposed) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final user = await _ensureSignedInUser();

      if (user == null) {
        if (!_disposed) {
          state = const IndustryHubState(
            isLoading: false,
          );
        }
        return;
      }

      final profileRow = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      final profile = profileRow == null
          ? const CompanyProfile()
          : CompanyProfile.fromSupabase(
              profileRow,
            );

      if (profileRow == null) {
        await _supabase.from('profiles').insert({
          'user_id': user.id,
          'business_name':
              profile.businessName,
          'sector': profile.sector,
          'role': profile.role,
        });
      }

      final listingRows = await _supabase
          .from('listings')
          .select()
          .eq('status', 'ACTIVE')
          .order(
            'created_at',
            ascending: false,
          );

      final listings = (listingRows as List)
          .map(
            (row) => Listing.fromSupabase(
              Map<String, dynamic>.from(
                row as Map,
              ),
            ),
          )
          .toList();

      final savedMatches = await _countOwnRows(
        'saved_matches',
        user.id,
      );

      final negotiations = await _countOwnRows(
        'fair_price_sessions',
        user.id,
      );

      if (_disposed ||
          !hasVerifiedSupabaseSession(_supabase) ||
          _supabase.auth.currentUser?.id !=
              user.id) {
        return;
      }

      state = state.copyWith(
        profile: profile,
        listings: listings,
        savedMatches: savedMatches,
        negotiations: negotiations,
        isLoading: false,
        userId: user.id,
      );
    } catch (error) {
      debugPrint(
        'IndustryHub Supabase load failed: $error',
      );

      if (!_disposed) {
        state = state.copyWith(
          isLoading: false,
        );
      }
    }
  }

  Future<void> refreshSupabaseData() =>
      _loadProfileAndListings();

  Future<int> _countOwnRows(
    String table,
    String userId,
  ) async {
    try {
      final rows = await _supabase
          .from(table)
          .select('id')
          .eq('user_id', userId);

      return (rows as List).length;
    } catch (error) {
      debugPrint(
        'IndustryHub $table count could not be loaded: $error',
      );

      return 0;
    }
  }

  Future<void> updateProfile({
    String? businessName,
    String? sector,
    String? role,
    String? msicCode,
    String? msicDescription,
    bool clearMsic = false,
    String? contactName,
    String? contactPhone,
    String? profileImagePath,
    bool clearProfileImage = false,
  }) async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      throw StateError(
        'Sign in before updating your profile.',
      );
    }

    final updatedProfile = CompanyProfile(
      businessName:
          businessName?.trim().isNotEmpty == true
              ? businessName!.trim()
              : state.profile.businessName,
      sector:
          sector?.trim().isNotEmpty == true
              ? sector!.trim()
              : state.profile.sector,
      role:
          role?.trim().isNotEmpty == true
              ? role!.trim()
              : state.profile.role,
      verified: state.profile.verified,
      msicCode: clearMsic
          ? null
          : (
              msicCode?.trim().isNotEmpty ==
                      true
                  ? msicCode!.trim()
                  : state.profile.msicCode
            ),
      msicDescription: clearMsic
          ? null
          : (
              msicDescription
                          ?.trim()
                          .isNotEmpty ==
                      true
                  ? msicDescription!.trim()
                  : state
                      .profile
                      .msicDescription
            ),
      contactName:
          contactName ?? state.profile.contactName,
      contactPhone:
          contactPhone ??
          state.profile.contactPhone,
      profileImagePath: clearProfileImage
          ? null
          : profileImagePath ??
              state.profile.profileImagePath,
    );

    try {
      final updateMap = {
        'business_name':
            updatedProfile.businessName,
        'sector': updatedProfile.sector,
        'role': updatedProfile.role,
        'msic_code':
            updatedProfile.msicCode,
        'msic_description':
            updatedProfile.msicDescription,
        'contact_name':
            updatedProfile.contactName,
        'contact_phone':
            updatedProfile.contactPhone,
        'profile_image_url':
            updatedProfile.profileImagePath,
      };

      final updatedRow = await _supabase
          .from('profiles')
          .update(updateMap)
          .eq('user_id', user.id)
          .select()
          .single();

      final savedProfile = CompanyProfile.fromSupabase(
        Map<String, dynamic>.from(updatedRow),
      );

      final updatedListings = state.listings
          .map(
            (listing) => listing.ownerId == user.id
                ? listing.copyWith(
                    owner: savedProfile.businessName,
                    verified: savedProfile.verified,
                  )
                : listing,
          )
          .toList();

      if (_disposed) return;

      state = state.copyWith(
        profile: savedProfile,
        listings: updatedListings,
      );
    } catch (error) {
      debugPrint(
        'IndustryHub Supabase profile update failed: $error',
      );

      rethrow;
    }
  }

  Future<int> createPresentationListings()
      async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      throw StateError(
        'Sign in before loading presentation listings.',
      );
    }

    final existingRows = await _supabase
        .from('listings')
        .select('id')
        .eq('owner_id', user.id)
        .eq('status', 'ACTIVE')
        .ilike(
          'description',
          '[PRESENTATION SAMPLE]%',
        );

    if ((existingRows as List).isNotEmpty) {
      return 0;
    }

    if (!state
        .profile
        .hasRequiredProfileIdentity) {
      throw StateError(
        'Complete your business profile before loading presentation listings.',
      );
    }

    final owner =
        state.profile.businessName.trim();

    final rows =
        await _supabase.from('listings').insert([
      {
        'type': 'supply',
        'material':
            'Aluminium machining offcuts',
        'quantity': 1200,
        'unit': 'kg',
        'location': 'Pulau Pinang',
        'description':
            '[PRESENTATION SAMPLE] Sorted, dry aluminium machining offcuts; collection-ready in 7 days. Replace this sample with your real supply record before production.',
        'asking_price_per_kg': 12.80,
        'owner': owner,
        'owner_id': user.id,
      },
      {
        'type': 'demand',
        'material':
            'Recycled HDPE pellets',
        'quantity': 800,
        'unit': 'kg',
        'location': 'Selangor',
        'description':
            '[PRESENTATION SAMPLE] Buyer seeking consistent recycled HDPE pellets for injection-moulding production. Confirm grade, colour, and delivery terms before agreement.',
        'asking_price_per_kg': null,
        'owner': owner,
        'owner_id': user.id,
      },
      {
        'type': 'supply',
        'material':
            'Copper wire granules',
        'quantity': 600,
        'unit': 'kg',
        'location': 'Johor',
        'description':
            '[PRESENTATION SAMPLE] Clean copper wire granules with batch photos available on request. Replace this sample with a verified business listing before production.',
        'asking_price_per_kg': 26.50,
        'owner': owner,
        'owner_id': user.id,
      },
    ]).select();

    final createdListings =
        (rows as List)
            .map(
              (row) => Listing.fromSupabase(
                Map<String, dynamic>.from(
                  row as Map,
                ),
              ),
            )
            .toList();

    if (!_disposed) {
      state = state.copyWith(
        listings: [
          ...createdListings,
          ...state.listings,
        ],
      );
    }

    return createdListings.length;
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

    if (user == null) {
      throw StateError(
        'Sign in before publishing a listing.',
      );
    }

    if (!state
        .profile
        .hasRequiredProfileIdentity) {
      throw StateError(
        'Complete your business profile before publishing a listing.',
      );
    }

    try {
      final createdRow = await _supabase
          .from('listings')
          .insert({
            'type': type,
            'material': material.trim(),
            'quantity': quantity,
            'unit': unit,
            'location': location.trim(),
            'description':
                description.trim(),
            'asking_price_per_kg':
                askingPricePerKg,
            'owner':
                state.profile.businessName,
            'owner_id': user.id,
          })
          .select()
          .single();

      final listing =
          Listing.fromSupabase(
        Map<String, dynamic>.from(
          createdRow,
        ),
      );

      if (_disposed) return;

      state = state.copyWith(
        listings: [
          listing,
          ...state.listings,
        ],
      );
    } catch (error) {
      debugPrint(
        'IndustryHub Supabase listing creation failed: $error',
      );

      rethrow;
    }
  }

  Future<void> updateListing({
    required String id,
    required String type,
    required String material,
    required double quantity,
    required String unit,
    required String location,
    required String description,
    double? askingPricePerKg,
  }) async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      throw StateError(
        'Sign in before updating a listing.',
      );
    }

    try {
      final updatedRow = await _supabase
          .from('listings')
          .update({
            'type': type,
            'material': material.trim(),
            'quantity': quantity,
            'unit': unit,
            'location': location.trim(),
            'description':
                description.trim(),
            'asking_price_per_kg':
                askingPricePerKg,
          })
          .eq('id', id)
          .eq('owner_id', user.id)
          .select()
          .single();

      final updatedListing =
          Listing.fromSupabase(
        Map<String, dynamic>.from(
          updatedRow,
        ),
      );

      if (_disposed) return;

      state = state.copyWith(
        listings: state.listings
            .map(
              (listing) =>
                  listing.id == id
                      ? updatedListing
                      : listing,
            )
            .toList(),
      );
    } catch (error) {
      debugPrint(
        'IndustryHub Supabase listing update failed: $error',
      );

      rethrow;
    }
  }

  Future<void> removeListing(
    String id,
  ) async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      throw StateError(
        'Sign in before removing a listing.',
      );
    }

    try {
      await _supabase.rpc(
        'withdraw_listing',
        params: {
          'p_listing_id': id,
        },
      );

      if (_disposed) return;

      state = state.copyWith(
        listings: state.listings
            .where(
              (item) => item.id != id,
            )
            .toList(),
      );
    } catch (error) {
      debugPrint(
        'IndustryHub Supabase listing removal failed: $error',
      );

      rethrow;
    }
  }

  Future<Set<String>>
      fetchSavedMatchIds() async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      return const <String>{};
    }

    final rows = await _supabase
        .from('saved_matches')
        .select('programme_id')
        .eq('user_id', user.id);

    return (rows as List)
        .map(
          (row) =>
              (row as Map)['programme_id'],
        )
        .whereType<String>()
        .toSet();
  }

  Future<void> saveMatch({
    required String programmeId,
    required String programmeName,
    required String provider,
    required String sourceUrl,
    required String sourceName,
  }) async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      throw StateError(
        'Sign in before saving a training match.',
      );
    }

    if (!state
        .profile
        .hasRequiredProfileIdentity) {
      throw StateError(
        'Complete your business profile before saving skill-match recommendations.',
      );
    }

    await _supabase
        .from('saved_matches')
        .upsert(
      {
        'user_id': user.id,
        'programme_id': programmeId,
        'programme_name':
            programmeName,
        'provider': provider,
        'source_url': sourceUrl,
        'source_name': sourceName,
      },
      onConflict:
          'user_id,programme_id',
    );

    final count = await _countOwnRows(
      'saved_matches',
      user.id,
    );

    if (!_disposed) {
      state = state.copyWith(
        savedMatches: count,
      );
    }
  }

  Future<void> saveNegotiation({
    required String product,
    required double quantity,
    required double proposedPrice,
    required double floorPrice,
    required double targetPrice,
    required double ceilingPrice,
    required String condition,
    required String collectionTerms,
    required String strategy,
    required bool hasLiveEvidence,
  }) async {
    final user = await _ensureSignedInUser();

    if (user == null) {
      throw StateError(
        'Sign in before saving a price session.',
      );
    }

    if (!state
        .profile
        .hasRequiredProfileIdentity) {
      throw StateError(
        'Complete your business profile before saving a FairPrice recommendation.',
      );
    }

    await _supabase
        .from('fair_price_sessions')
        .insert({
      'user_id': user.id,
      'product': product.trim(),
      'quantity': quantity,
      'proposed_price':
          proposedPrice,
      'floor_price': floorPrice,
      'target_price': targetPrice,
      'ceiling_price':
          ceilingPrice,
      'condition': condition,
      'collection_terms':
          collectionTerms,
      'strategy': strategy,
      'has_live_evidence':
          hasLiveEvidence,
    });

    final count = await _countOwnRows(
      'fair_price_sessions',
      user.id,
    );

    if (!_disposed) {
      state = state.copyWith(
        negotiations: count,
      );
    }
  }
}

final appStateProvider =
    NotifierProvider<
        IndustryHubNotifier,
        IndustryHubState>(
  IndustryHubNotifier.new,
);