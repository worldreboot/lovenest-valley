import 'dart:ui';

enum MediaType { photo, voice, text, link }
enum SeedState { sprout, wilted, bloomStage1, bloomStage2, bloomStage3, archived }

class PlotPosition {
  final double x;
  final double y;

  const PlotPosition(this.x, this.y);

  factory PlotPosition.fromJson(Map<String, dynamic> json) {
    return PlotPosition(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }

  Offset toOffset() => Offset(x, y);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlotPosition && other.x == x && other.y == y;
  }

  @override
  int get hashCode => x.hashCode ^ y.hashCode;

  @override
  String toString() => 'PlotPosition($x, $y)';
}

class Seed {
  final String id;
  final String? coupleId;
  final String planterId;
  final MediaType mediaType;
  final String? mediaUrl;
  final String? textContent;
  final String? secretHope;
  final SeedState state;
  final int growthScore;
  final PlotPosition plotPosition;
  final String? bloomVariantSeed;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  const Seed({
    required this.id,
    this.coupleId,
    required this.planterId,
    required this.mediaType,
    this.mediaUrl,
    this.textContent,
    this.secretHope,
    required this.state,
    required this.growthScore,
    required this.plotPosition,
    this.bloomVariantSeed,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory Seed.fromJson(Map<String, dynamic> json) {
    return Seed(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String?,
      planterId: json['planter_id'] as String,
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == json['media_type'],
      ),
      mediaUrl: json['media_url'] as String?,
      textContent: json['text_content'] as String?,
      secretHope: json['secret_hope'] as String?,
      state: _parseState(json['state'] as String),
      growthScore: json['growth_score'] as int,
      plotPosition: PlotPosition(
        (json['plot_x'] as num).toDouble(),
        (json['plot_y'] as num).toDouble(),
      ),
      bloomVariantSeed: json['bloom_variant_seed'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUpdatedAt: DateTime.parse(json['last_updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'planter_id': planterId,
      'media_type': mediaType.name,
      'media_url': mediaUrl,
      'text_content': textContent,
      'secret_hope': secretHope,
      'state': _stateToString(state),
      'growth_score': growthScore,
      'plot_position': plotPosition.toJson(),
      'bloom_variant_seed': bloomVariantSeed,
      'created_at': createdAt.toIso8601String(),
      'last_updated_at': lastUpdatedAt.toIso8601String(),
    };
  }

  static SeedState _parseState(String state) {
    switch (state) {
      case 'sprout':
        return SeedState.sprout;
      case 'wilted':
        return SeedState.wilted;
      case 'bloom_stage_1':
        return SeedState.bloomStage1;
      case 'bloom_stage_2':
        return SeedState.bloomStage2;
      case 'bloom_stage_3':
        return SeedState.bloomStage3;
      case 'archived':
        return SeedState.archived;
      default:
        return SeedState.sprout;
    }
  }

  static String _stateToString(SeedState state) {
    switch (state) {
      case SeedState.sprout:
        return 'sprout';
      case SeedState.wilted:
        return 'wilted';
      case SeedState.bloomStage1:
        return 'bloom_stage_1';
      case SeedState.bloomStage2:
        return 'bloom_stage_2';
      case SeedState.bloomStage3:
        return 'bloom_stage_3';
      case SeedState.archived:
        return 'archived';
    }
  }

  static PlotPosition _parsePosition(dynamic position) {
    if (position is String) {
      // Parse PostgreSQL POINT format: "(x,y)"
      final cleaned = position.replaceAll('(', '').replaceAll(')', '');
      final parts = cleaned.split(',');
      return PlotPosition(
        double.parse(parts[0]),
        double.parse(parts[1]),
      );
    } else if (position is Map<String, dynamic>) {
      return PlotPosition.fromJson(position);
    }
    throw ArgumentError('Invalid position format: $position');
  }

  Seed copyWith({
    String? id,
    String? coupleId,
    String? planterId,
    MediaType? mediaType,
    String? mediaUrl,
    String? textContent,
    String? secretHope,
    SeedState? state,
    int? growthScore,
    PlotPosition? plotPosition,
    String? bloomVariantSeed,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return Seed(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      planterId: planterId ?? this.planterId,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      textContent: textContent ?? this.textContent,
      secretHope: secretHope ?? this.secretHope,
      state: state ?? this.state,
      growthScore: growthScore ?? this.growthScore,
      plotPosition: plotPosition ?? this.plotPosition,
      bloomVariantSeed: bloomVariantSeed ?? this.bloomVariantSeed,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  bool get isBloom => [
        SeedState.bloomStage1,
        SeedState.bloomStage2,
        SeedState.bloomStage3
      ].contains(state);

  bool get canRevealSecret => [
        SeedState.bloomStage2,
        SeedState.bloomStage3
      ].contains(state);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Seed &&
        other.id == id &&
        other.coupleId == coupleId &&
        other.planterId == planterId &&
        other.mediaType == mediaType &&
        other.mediaUrl == mediaUrl &&
        other.textContent == textContent &&
        other.secretHope == secretHope &&
        other.state == state &&
        other.growthScore == growthScore &&
        other.plotPosition == plotPosition &&
        other.bloomVariantSeed == bloomVariantSeed &&
        other.createdAt == createdAt &&
        other.lastUpdatedAt == lastUpdatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        coupleId.hashCode ^
        planterId.hashCode ^
        mediaType.hashCode ^
        mediaUrl.hashCode ^
        textContent.hashCode ^
        secretHope.hashCode ^
        state.hashCode ^
        growthScore.hashCode ^
        plotPosition.hashCode ^
        bloomVariantSeed.hashCode ^
        createdAt.hashCode ^
        lastUpdatedAt.hashCode;
  }

  @override
  String toString() {
    return 'Seed(id: $id, coupleId: $coupleId, planterId: $planterId, '
        'mediaType: $mediaType, state: $state, growthScore: $growthScore, '
        'plotPosition: $plotPosition, createdAt: $createdAt)';
  }
} 