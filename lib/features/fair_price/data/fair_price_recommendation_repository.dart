import 'package:supabase_flutter/supabase_flutter.dart';

class SavedFairPriceRecommendation {
  const SavedFairPriceRecommendation({
    required this.id,
    required this.userId,
    required this.materialCategory,
    required this.product,
    required this.quantity,
    required this.proposedPricePerKg,
    required this.materialCondition,
    required this.collectionTerms,
    required this.recommendedLow,
    required this.recommendedHigh,
    required this.suggestedTarget,
    required this.strategy,
    this.confidence,
    this.peerObservationCount = 0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.hasLiveEvidence = false,
  });

  final String id;
  final String userId;
  final String materialCategory;
  final String product;
  final double quantity;
  final double proposedPricePerKg;
  final String materialCondition;
  final String collectionTerms;
  final double recommendedLow;
  final double recommendedHigh;
  final double suggestedTarget;
  final String strategy;
  final double? confidence;
  final int peerObservationCount;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasLiveEvidence;

  factory SavedFairPriceRecommendation.fromJson(Map<String, dynamic> json) {
    return SavedFairPriceRecommendation(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      materialCategory: (json['material_category'] as String?) ?? '',
      product: (json['product'] as String?) ?? 'Unspecified material',
      quantity: _toDouble(json['quantity']) ?? 0,
      proposedPricePerKg: _toDouble(json['proposed_price']) ?? 0,
      materialCondition: (json['condition'] as String?) ?? 'Unspecified',
      collectionTerms: (json['collection_terms'] as String?) ?? 'Buyer collects',
      recommendedLow: _toDouble(json['floor_price']) ?? 0,
      recommendedHigh: _toDouble(json['ceiling_price']) ?? 0,
      suggestedTarget: _toDouble(json['target_price']) ?? 0,
      strategy: (json['strategy'] as String?) ?? 'No strategy saved',
      confidence: _toDouble(json['confidence']),
      peerObservationCount: _toInt(json['peer_observation_count']),
      notes: (json['notes'] as String?) ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      hasLiveEvidence: json['has_live_evidence'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'material_category': materialCategory,
        'product': product,
        'quantity': quantity,
        'proposed_price': proposedPricePerKg,
        'condition': materialCondition,
        'collection_terms': collectionTerms,
        'floor_price': recommendedLow,
        'ceiling_price': recommendedHigh,
        'target_price': suggestedTarget,
        'strategy': strategy,
        'confidence': confidence,
        'peer_observation_count': peerObservationCount,
        'notes': notes,
        'has_live_evidence': hasLiveEvidence,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class FairPriceRecommendationRepository {
  FairPriceRecommendationRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<List<SavedFairPriceRecommendation>> fetchMyRecommendations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return const [];

    final rows = await _supabase
        .from('fair_price_sessions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (row) => SavedFairPriceRecommendation.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  Future<SavedFairPriceRecommendation> createRecommendation({
    required String materialCategory,
    required String product,
    required double quantity,
    required double proposedPricePerKg,
    required String materialCondition,
    required String collectionTerms,
    required double recommendedLow,
    required double recommendedHigh,
    required double suggestedTarget,
    required String strategy,
    double? confidence,
    int peerObservationCount = 0,
    String notes = '',
    bool hasLiveEvidence = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before saving a FairPrice recommendation.');
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'material_category': materialCategory.trim(),
      'product': product.trim(),
      'quantity': quantity,
      'proposed_price': proposedPricePerKg,
      'floor_price': recommendedLow,
      'target_price': suggestedTarget,
      'ceiling_price': recommendedHigh,
      'condition': materialCondition,
      'collection_terms': collectionTerms,
      'strategy': strategy,
      'has_live_evidence': hasLiveEvidence,
      'peer_observation_count': peerObservationCount,
      'notes': notes.trim(),
    };

    final validConfidence = confidence;
    if (validConfidence != null && validConfidence.isFinite) {
      payload['confidence'] = validConfidence;
    }

    final createdRow = await _supabase
        .from('fair_price_sessions')
        .insert(payload)
        .select()
        .single();

    return SavedFairPriceRecommendation.fromJson(
      Map<String, dynamic>.from(createdRow),
    );
  }

  Future<SavedFairPriceRecommendation> updateRecommendation({
    required String id,
    required String materialCategory,
    required String product,
    required double quantity,
    required double proposedPricePerKg,
    required String materialCondition,
    required String collectionTerms,
    required double recommendedLow,
    required double recommendedHigh,
    required double suggestedTarget,
    required String strategy,
    double? confidence,
    int peerObservationCount = 0,
    String notes = '',
    bool hasLiveEvidence = false,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before updating a FairPrice recommendation.');
    }

    final payload = <String, dynamic>{
      'material_category': materialCategory.trim(),
      'product': product.trim(),
      'quantity': quantity,
      'proposed_price': proposedPricePerKg,
      'floor_price': recommendedLow,
      'target_price': suggestedTarget,
      'ceiling_price': recommendedHigh,
      'condition': materialCondition,
      'collection_terms': collectionTerms,
      'strategy': strategy,
      'has_live_evidence': hasLiveEvidence,
      'peer_observation_count': peerObservationCount,
      'notes': notes.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final validConfidence = confidence;
    if (validConfidence != null && validConfidence.isFinite) {
      payload['confidence'] = validConfidence;
    }

    final updatedRow = await _supabase
        .from('fair_price_sessions')
        .update(payload)
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();

    return SavedFairPriceRecommendation.fromJson(
      Map<String, dynamic>.from(updatedRow),
    );
  }

  Future<void> deleteRecommendation(String id) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('Sign in before deleting a FairPrice recommendation.');
    }

    await _supabase
        .from('fair_price_sessions')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }
}
