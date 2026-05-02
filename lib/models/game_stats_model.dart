// ─────────────────────────────────────────────────────────────────────────────
// lib/models/game_stats_model.dart
// Data model for a player's cumulative game statistics.
//
// Stores wins, losses, total matches, and total days played.
// Exposes a computed winRate getter (percentage, 0–100).
//
// Serialisation:
//   toMap()       — converts to Map<String, dynamic> for Supabase upsert or
//                   SharedPreferences storage.
//   fromMap()     — factory constructor that rehydrates the model from a stored
//                   map; missing keys default to zero to handle legacy records.
//
// copyWith() allows producing modified snapshots without mutating the instance,
// which is important for ChangeNotifier providers that compare old vs new state.
// ─────────────────────────────────────────────────────────────────────────────
class GameStatsModel {
  int totalWins;
  int totalLosses;
  int totalMatches;
  int totalDays;

  GameStatsModel({
    this.totalWins = 0,
    this.totalLosses = 0,
    this.totalMatches = 0,
    this.totalDays = 1,
  });

  // Calculate win rate percentage
  double get winRate {
    if (totalMatches == 0) return 0.0;
    return (totalWins / totalMatches) * 100;
  }

  // Increment wins
  void addWin() {
    totalWins++;
    totalMatches++;
  }

  // Increment losses
  void addLoss() {
    totalLosses++;
    totalMatches++;
  }

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'totalMatches': totalMatches,
      'totalDays': totalDays,
    };
  }

  // Create from Map
  factory GameStatsModel.fromMap(Map<String, dynamic> map) {
    return GameStatsModel(
      totalWins: map['totalWins'] ?? 0,
      totalLosses: map['totalLosses'] ?? 0,
      totalMatches: map['totalMatches'] ?? 0,
      totalDays: map['totalDays'] ?? 1,
    );
  }

  GameStatsModel copyWith({
    int? totalWins,
    int? totalLosses,
    int? totalMatches,
    int? totalDays,
  }) {
    return GameStatsModel(
      totalWins: totalWins ?? this.totalWins,
      totalLosses: totalLosses ?? this.totalLosses,
      totalMatches: totalMatches ?? this.totalMatches,
      totalDays: totalDays ?? this.totalDays,
    );
  }
}
