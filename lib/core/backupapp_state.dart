import 'package:flutter_riverpod/flutter_riverpod.dart';

class Listing {
  Listing({
    required this.id,
    required this.type,
    required this.material,
    required this.quantity,
    required this.unit,
    required this.location,
    required this.description,
    required this.owner,
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
  final bool verified;
}

class CompanyProfile {
  CompanyProfile({
    this.businessName = 'Kencana Precision Works',
    this.sector = 'Precision manufacturing',
    this.role = 'Factory owner',
    this.verified = true,
  });

  String businessName;
  String sector;
  String role;
  bool verified;
}

class IndustryHubState {
  IndustryHubState({
    CompanyProfile? profile,
    List<Listing>? listings,
    this.savedMatches = 2,
    this.negotiations = 1,
  })  : profile = profile ?? CompanyProfile(),
        listings = listings ?? demoListings;

  CompanyProfile profile;
  List<Listing> listings;
  int savedMatches;
  int negotiations;

  int get activeListings => listings.where((item) => item.owner == profile.businessName).length;
}

final demoListings = <Listing>[
  Listing(
    id: 'l-001',
    type: 'supply',
    material: 'Aluminium offcuts',
    quantity: 500,
    unit: 'kg',
    location: 'Shah Alam, Selangor',
    description: 'Clean 6061 aluminium machining offcuts, sorted and baled weekly.',
    owner: 'Kencana Precision Works',
    verified: true,
  ),
  Listing(
    id: 'l-002',
    type: 'demand',
    material: 'HDPE plastic pellets',
    quantity: 1200,
    unit: 'kg',
    location: 'Bayan Lepas, Penang',
    description: 'Looking for post-industrial HDPE regrind or pellets for injection moulding.',
    owner: 'Northern Form Plastics',
    verified: true,
  ),
  Listing(
    id: 'l-003',
    type: 'supply',
    material: 'Cardboard packaging',
    quantity: 2500,
    unit: 'kg',
    location: 'Johor Bahru, Johor',
    description: 'Dry OCC cardboard from a distribution centre. Collection available.',
    owner: 'Southern Logistics Hub',
    verified: false,
  ),
  Listing(
    id: 'l-004',
    type: 'demand',
    material: 'Copper wire scrap',
    quantity: 300,
    unit: 'kg',
    location: 'Ipoh, Perak',
    description: 'Seeking insulated and bare copper wire scrap for a local recovery line.',
    owner: 'Perak Circular Metals',
    verified: true,
  ),
];

class IndustryHubNotifier extends Notifier<IndustryHubState> {
  @override
  IndustryHubState build() => IndustryHubState();

  void updateProfile({String? businessName, String? sector, String? role}) {
    final profile = state.profile;
    if (businessName != null && businessName.trim().isNotEmpty) profile.businessName = businessName.trim();
    if (sector != null && sector.trim().isNotEmpty) profile.sector = sector.trim();
    if (role != null && role.trim().isNotEmpty) profile.role = role.trim();
    state = IndustryHubState(
      profile: profile,
      listings: [...state.listings],
      savedMatches: state.savedMatches,
      negotiations: state.negotiations,
    );
  }

  void addListing({
    required String type,
    required String material,
    required double quantity,
    required String unit,
    required String location,
    required String description,
  }) {
    final listing = Listing(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      material: material,
      quantity: quantity,
      unit: unit,
      location: location,
      description: description,
      owner: state.profile.businessName,
      verified: state.profile.verified,
    );
    state = IndustryHubState(
      profile: state.profile,
      listings: [listing, ...state.listings],
      savedMatches: state.savedMatches,
      negotiations: state.negotiations,
    );
  }

  void removeListing(String id) {
    state = IndustryHubState(
      profile: state.profile,
      listings: state.listings.where((item) => item.id != id).toList(),
      savedMatches: state.savedMatches,
      negotiations: state.negotiations,
    );
  }

  void saveMatch() {
    state = IndustryHubState(
      profile: state.profile,
      listings: [...state.listings],
      savedMatches: state.savedMatches + 1,
      negotiations: state.negotiations,
    );
  }

  void startNegotiation() {
    state = IndustryHubState(
      profile: state.profile,
      listings: [...state.listings],
      savedMatches: state.savedMatches,
      negotiations: state.negotiations + 1,
    );
  }
}

final appStateProvider = NotifierProvider<IndustryHubNotifier, IndustryHubState>(IndustryHubNotifier.new);
