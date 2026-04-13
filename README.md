<<<<<<< HEAD
# 🏹 Arrow Araw: Sipag Lang
A vibrant arrow puzzle escape mobile game built with Flutter.

## ✨ Features

### 📱 Application Screens

- **Splash Screen** — Animated app entry with the official Main Logo.
- **Login Screen** — Secure user authentication via Supabase.
- **Sign Up Screen** — New user registration with OTP email verification.
- **Forgot Password Screen** — 3-step account recovery via OTP email verification.
- **Home Screen** — The main navigation hub with Welcome message.
- **Level Select Screen** — Dynamic map featuring 10 difficulty tiers with lock/unlock animations.

#### 🎮 Game Levels

| Level | Grid  | Arrow Count | Min Length | Max Length | Difficulty |
|-------|-------|-------------|------------|------------|------------|
| 1     | 8×8   | 10          | 2          | 3          | Easy       |
| 2     | 10×10 | 20          | 2          | 3          | Easy       |
| 3     | 11×11 | 30          | 2          | 4          | Normal     |
| 4     | 12×12 | 40          | 2          | 4          | Normal     |
| 5     | 13×13 | 50          | 2          | 4          | Hard       |
| 6     | 14×14 | 60          | 2          | 5          | Hard       |
| 7     | 15×15 | 70          | 2          | 5          | Expert     |
| 8     | 16×16 | 80          | 2          | 5          | Expert     |
| 9     | 17×17 | 90          | 2          | 5          | Master     |
| 10    | 18×18 | 100         | 2          | 5          | Master     |

> **Arrow shapes are straight lines only** (horizontal or vertical). Lengths cycle through `[2, 3, 4, 5, 2, 3, 2, 4, 3, 5]` for visual variety. No L-shapes or bends.

#### ⚙️ Other Screens

- **Settings Screen** — Audio toggles (Music / Sound FX), account management, support navigation.
- **Records Screen** — Real-time statistics (Wins/Losses/Matches/Win Rate/Days Active) synced from the cloud. Compact 60dp max-height rows.
- **About Screen** — Development mission and version info (v1.0.0).
- **Contact Screen** — Support channel → sends email to arrowarawsipaglang@gmail.com via EmailJS.
- **Privacy Policy Screen** — Data protection and Supabase storage terms.
- **Terms of Service Screen** — User guidelines and app rules.

---

## 🎯 Core Gameplay Mechanics

- **Straight Arrow Puzzle** — Each arrow occupies a straight horizontal or vertical run of grid cells. Tap arrows in the correct order to slide them off the board.
- **Escape Direction** — Each arrow has an `escape` direction (up/down/left/right). It can only slide out if its path to the grid edge is unobstructed by remaining arrows.
- **Tap Debouncing** — Arrows currently mid-animation are locked (`_pendingSolve` set) and cannot be re-tapped, preventing accidental rapid-tap life loss.
- **Solve Order** — Any arrow whose escape path is clear may be tapped. Tapping an arrow with a blocked path costs a life.
- **Lives System** — 3 lives per level. Wrong taps deduct 1 life each. Timer expiry ends the game immediately.
- **60-Second Timer** — Complete every level within 60 seconds. The HUD shows a linear depleting progress bar that turns red when ≤ 10 seconds remain.
- **HUD Layout** — `[Back ←] [Level N] · · · [♥♥♥] [Xs] [⚙]` followed by a colour-coded progress bar.

### 🔒 Level Locking & Progression

- New accounts unlock **Level 1 only**.
- Levels 2–10 display a lock icon until unlocked.
- Clearing a level triggers an **unlock animation** for the next level.
- Clearing **all 10 levels** permanently unlocks free selection across all levels (**Master Unlock** via `LevelUnlockService.instance.unlockAll()`).
- Progress is dual-stored: SharedPreferences (local/instant) + Supabase `level_progress` table (remote/cross-device).

---

## 🔊 Audio System

| Sound File | Trigger |
|---|---|
| `assets/audio/Lobby-Music.mp3` | Menu / lobby background music (loops) |
| `assets/audio/Ingame-Music.mp3` | In-game background music (loops) |
| Arrow sound | Correct arrow tap — slides out |
| Wrong-move sound | Wrong tap / blocked arrow — life deducted |
| Win sound | Level victory |
| Lose sound | Game over (lives = 0 **only**) |

**Idle Resume** — `AudioService.startIdleResumeTimer()` resumes game music 2 seconds after the last tap (preventing music stopping mid-play).

**Settings Modal** (in Settings Screen) provides functional toggles for:
- 🎵 **Background Music** — pause/resume `Lobby-Music` & `Ingame-Music`
- 🔊 **Sound FX** — mute/unmute all SFX (Arrow, Wrong Move, Win, Lose)

---

## 🔐 Authentication Flow

### Sign Up
1. Fill in Username, Password, Confirm Password, and Email.
2. Tap **Send** to receive a 6-digit OTP code via email.
3. Enter the code and tap **Sign Up** to create your account.
4. New accounts start at **Level 1** with zero stats.

### Forgot Password
1. **Step 1** — Enter your registered email address.
2. **Step 2** — Enter the 6-digit OTP code sent to your email.
3. **Step 3** — Set and confirm your new password.
4. Redirects back to Login upon success.

### Account Deletion (Hard Delete)
- Permanently removes the user from **Supabase Auth** (via `delete_user` RPC) AND all public tables (`game_stats`, `level_progress`, `records`, `history`).
- Local SharedPreferences are wiped.
- Re-registering with the same email **starts as a completely fresh user** (Level 1, zero stats).

---

## 📊 Records Screen

Displays accurate stats synced from Supabase:

| Stat | Description |
|---|---|
| Wins | Total levels successfully cleared |
| Losses | Total game-overs (lives = 0 or timer expired) |
| Matches | Total games played (Wins + Losses) |
| Win Rate % | `(Wins / Matches) × 100` |
| Days Active | Calendar days the app has been used |

All stat rows are compact (**max-height: 60dp**) with reduced padding for a professional look.

---

## 📂 Project Structure

```text
lib/
├── levels/
│   ├── level_base.dart          
│   ├── level_manager.dart       
│   ├── game_screen_lvl_1.dart
│   ├── game_screen_lvl_2.dart
│   ├── game_screen_lvl_3.dart
│   ├── game_screen_lvl_4.dart
│   ├── game_screen_lvl_5.dart
│   ├── game_screen_lvl_6.dart
│   ├── game_screen_lvl_7.dart
│   ├── game_screen_lvl_8.dart
│   ├── game_screen_lvl_9.dart
│   └── game_screen_lvl_10.dart
├── models/
│   ├── arrow_model.dart
│   └── game_stats_model.dart
├── providers/
│   ├── auth_provider.dart
│   └── game_provider.dart
├── screens/
│   ├── about_screen.dart
│   ├── contact_screen.dart
│   ├── forgot_password_screen.dart
│   ├── game_screen.dart
│   ├── home_screen.dart
│   ├── level_select_screen.dart
│   ├── login_screen.dart
│   ├── policy_screen.dart
│   ├── records_screen.dart
│   ├── settings_screen.dart
│   ├── signup_screen.dart
│   ├── splash_screen.dart
│   └── terms_screen.dart
├── services/
│   ├── audio_service.dart
│   ├── level_unlock_service.dart
│   └── supabase_service.dart
├── utils/
│   ├── app_colors.dart
│   └── constants.dart
├── widgets/
│   ├── background_wrapper.dart
│   ├── game_over_overlay.dart
│   ├── gradient_button.dart
│   ├── gradient_input_field.dart
│   ├── life_indicator.dart
│   └── victory_overlay.dart
└── main.dart

assets/
├── images/
│   ├── LOGO.png
│   ├── background.png
│   ├── Game Over.png
│   ├── Victory.png
│   ├── heart icon Red.png
│   └── heart icon Black.png
└── audio/
    ├── Lobby-Music.mp3
    └── Ingame-Music.mp3
```

---

## 🏗️ Architecture & Logic

### Arrow Data Models
- **`BentCell`** — A single grid cell `(row, col)`.
- **`BentArrowData`** — Multi-segment arrow. Holds an ordered list of `BentCell` positions, an `escape` direction, a colour, and a `solved` flag. Exposes `hitRect(cellSize)` for tap detection with an extended hit zone in the escape direction.
- **`BentArrowPainter`** — Type alias for `StraightArrowPainter` (kept for backward compatibility).

### Core Engine (`BentLevelStateMixin`)
Mixed into every level screen. Responsibilities:
- **Timer** — 60-second countdown via `Timer.periodic`; calls `triggerGameOver()` at zero.
- **Tap handling** — `onGridTap` / `onTap` → `_findTappedArrow` → `isPathClear` → animate or `wrongTap`.
- **Debouncing** — `_pendingSolve` (a `Set<int>`) prevents re-tapping an arrow already in its 380 ms slide-out animation.
- **Victory / Game Over** — `triggerVictory()` records the result via `GameProvider` and calls `LevelUnlockService`; `triggerGameOver()` records a loss.
- **Navigation** — Back button leads to `LevelSelectScreen` (not Home).

### Painter Logic (`StraightArrowPainter`)
- Draws a **straight line** from the tail cell centre to a tip point `0.45 × cellSize` beyond the head in the escape direction.
- Renders a glow pass (blurred, semi-transparent) behind the crisp shaft.
- Arrowhead is a **closed filled triangle** (`Path..close()`) — no stray line artefacts.
- `hitTest` returns `false` so tap detection is delegated to `BentArrowData.hitRect` instead.

### Arrow Generation (`level_manager.dart` — `_gen`)
Three-pass algorithm:
1. **Pass 1** — Scans every cell; tries horizontal then vertical placement with a cycling length pattern `[2,3,4,5,2,3,2,4,3,5]`.
2. **Pass 2** — Fills remaining quota with length-2 horizontal arrows.
3. **Pass 3** — Fills remaining quota with length-2 vertical arrows.

Escape direction heuristic: arrows touching the left/right edge point outward; interior arrows point toward the nearer edge.

### Collision Detection (`isPathClear`)
Builds a set of occupied cells (all unsolved arrows except the tapped one), then walks from the arrow's head in the escape direction to the grid boundary. Returns `false` on first occupied cell found.

### State Management
Provider pattern. `GameProvider` tracks grid state and statistics; `AuthProvider` manages Supabase authentication.

### Data Persistence
- **Cloud**: Stats and level progress stored in Supabase (`game_stats`, `level_progress` tables).
- **Local**: SharedPreferences for fast local session handling and offline progress.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend | Supabase (Auth + PostgreSQL) |
| State Management | Provider |
| Animations | flutter_animate |
| Audio | audioplayers |
| Email (Contact) | EmailJS REST API |
| Design | Figma & Canva |

---

## 🗄️ Supabase Schema

### Required Tables

```sql
-- Game statistics
create table game_stats (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  total_wins int default 0,
  total_losses int default 0,
  total_matches int default 0,
  total_days int default 1,
  updated_at timestamptz default now()
);

-- Level progress (unlock state)
create table level_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  highest_unlocked_level int default 1,
  updated_at timestamptz default now()
);
```

### Required RPC (for hard account delete)

```sql
create or replace function delete_user()
returns void language plpgsql security definer as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;
```

---

## 👨‍💻 About the Developer

Developed by a student of Urdaneta City University. This project is a practical application of advanced mobile development, emphasizing the philosophy: **Sipag Lang** (Hard Work Only).

---

## 📋 Changelog

### v1.2.0 — Latest
- ✅ **Lint fixes** — all `for` loop bodies in `level_base.dart` (lines 116, 162, 242) and `level_manager.dart` (lines 41, 47, 52, 56) wrapped in curly braces per `curly_braces_in_flow_control_structures` rule
- ✅ **README corrected** — level table updated to match actual grid sizes (8×8 → 18×18) and arrow counts (10 → 100) from `level_manager.dart`
- ✅ **Arrow shape clarified** — straight lines only (no L-shapes); `StraightArrowPainter` documented accurately
- ✅ **Audio asset paths corrected** — `assets/audio/` (not `assets/sounds/`)
- ✅ Architecture section rewritten to reflect `BentLevelStateMixin`, debounce logic, and `_gen` three-pass algorithm

### v1.1.0
- ✅ All 10 levels rewritten with precise shapes and exact arrow counts per spec
- ✅ HUD redesigned: Back Button · Level Label · Hearts · Timer + Linear Progress Bar
- ✅ Audio fixed: wrong-move sound on bad tap; lose sound only on zero lives
- ✅ Music paths corrected: `Lobby-Music.mp3` (menu) · `Ingame-Music.mp3` (game)
- ✅ Settings screen: Audio modal with Music and SFX toggles
- ✅ Records screen: Compact 60dp rows, accurate Wins/Losses/Matches/Win Rate/Days Active
- ✅ Master Unlock: clearing Level 10 permanently unlocks all levels for free replay
- ✅ Hard delete: account deletion removes user from Supabase Auth + all public tables
- ✅ `recordLevelLoss()` added to GameProvider — losses now accurately tracked
- ✅ Contact screen: EmailJS sends to arrowarawsipaglang@gmail.com with validation

### v1.0.0 — Initial Release
- Core gameplay with 10 levels
- Supabase auth + stats sync
- OTP email verification
=======
# ARROW-ARAW-SIPAG-LANG
MOBILE GAME APP PROJECT
>>>>>>> f629d3f55275e3ee57b4b34a2a45eaeaf7a720cd
