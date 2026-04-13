class AppConstants {
  // Game Configuration
  static const int gridSize = 6;
  static const int initialLives = 3;
  static const double obstacleDensity = 0.2;

  // Animation Durations
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration arrowMoveDuration = Duration(milliseconds: 400);
  static const Duration gameOverDelay = Duration(milliseconds: 500);

  // Arrow Types
  static const List<String> arrowDirections = [
    'up',
    'down',
    'left',
    'right',
    'white',
  ];

  // Storage Keys
  static const String keyTotalWins = 'total_wins';
  static const String keyTotalLosses = 'total_losses';
  static const String keyTotalMatches = 'total_matches';
  static const String keyTotalDays = 'total_days';
  static const String keyUsername = 'username';
  static const String keyIsLoggedIn = 'is_logged_in';
  // Key for storing the highest unlocked level in SharedPreferences
  static const String keyHighestUnlockedLevel = 'highest_unlocked_level';

  // Asset Paths — Images
  static const String logoWithBg = 'assets/images/LOGO.png';
  static const String background = 'assets/images/background.png';
  static const String heartRed = 'assets/images/heart icon Red.png';
  static const String heartBlack = 'assets/images/heart icon Black.png';
  static const String gameOver = 'assets/images/Game Over.png';
  static const String victory = 'assets/images/Victory.png';
  // ✅ FIXED: Removed backButton asset constant — walang file, ginagamit na built-in icon

  // Asset Paths — Audio (all files live in assets/audio/)
  static const String soundArrow = 'assets/audio/Arrow-Sound.mp3';
  static const String soundLobbyMusic = 'assets/audio/Lobby-Music.mp3';
  static const String soundIngameMusic = 'assets/audio/Ingame-Music.mp3';
  static const String soundWin = 'assets/audio/Win-Sound.mp3';
  static const String soundLose = 'assets/audio/Lose-Sound.mp3';
  static const String soundWrongMove = 'assets/audio/Wrong Move-Sound.mp3';
}
