# 🏹 Arrow Araw: Sipag Lang

A vibrant arrow puzzle escape mobile game built with Flutter.

---

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
- **Records Screen** — Real-time statistics (Wins/Losses/Matches/Win Rate/Days Active) synced from the cloud.
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

### 🔢 Real-Time Arrow Counter (v1.3.0)

The HUD now shows a live **Arrows Remaining** counter directly below the progress bar.

- Backed by a `ValueNotifier<int>` (`arrowsRemaining`) in `BentLevelStateMixin`.
- Initialized to the total arrow count when a level starts or restarts.
- Decremented exactly once per arrow, inside the `Future.delayed(_solveDelay)` callback — fires the instant the exit animation completes.
- Uses `ValueListenableBuilder` so only the counter text rebuilds on each update, keeping the grid's `RepaintBoundary` completely isolated.
- Displays `"1 Arrow Remaining"` (singular) or `"N Arrows Remaining"` (plural).

### 🔒 Level Locking & Progression

- New accounts unlock **Level 1 only**.
- Levels 2–10 display a lock icon until unlocked.
- Clearing a level triggers an **unlock animation** for the next level.
- Clearing **all 10 levels** permanently unlocks free selection across all levels (**Master Unlock** via `LevelUnlockService.instance.unlockAll()`).
- Progress is dual-stored: SharedPreferences (local/instant) + Supabase `level_progress` table (remote/cross-device).

---

## 🔐 Authentication Flow & Account Isolation (v1.3.0)

### Sign Up

1. Fill in Username, Password, Confirm Password, and Email.
2. Tap **Send** to receive a 6-digit OTP code via email.
3. Enter the code and tap **Sign Up** to create your account.
4. New accounts start at **Level 1** with zero stats.

### Login

On every successful login, `AuthProvider._handleLoginSuccess()` calls
`LevelUnlockService.instance.resetProgress()` before writing to SharedPreferences.
This clears the local level-unlock cache so LevelUnlockService subsequently fetches
the authenticated user's real Supabase row — preventing any prior tester account's
locally cached progress from bleeding into the new session.

### Logout (Hard Reset)

`AuthProvider.logout()` calls `LevelUnlockService.instance.resetProgress()` before
clearing SharedPreferences. This ensures the next user to log in on the same device
always starts from a clean local state, regardless of how far the previous session progressed.

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

## 🔊 Audio System

| Sound File | Trigger |
|---|---|
| `assets/audio/Lobby-Music.mp3` | Menu / lobby background music (loops) |
| `assets/audio/Ingame-Music.mp3` | In-game background music (loops) |
| Arrow sound | Correct arrow tap — slides out |
| Wrong-move sound | Wrong tap / blocked arrow — life deducted |
| Win sound | Level victory |
| Lose sound | Game over (lives = 0 **only**) |

**Idle Resume** — `AudioService.startIdleResumeTimer()` resumes game music 2 seconds after the last tap.

**Settings Modal** provides functional toggles for:
- 🎵 **Background Music** — pause/resume lobby & in-game music
- 🔊 **Sound FX** — mute/unmute all SFX

---

## 📊 Records Screen

| Stat | Description |
|---|---|
| Wins | Total levels successfully cleared |
| Losses | Total game-overs (lives = 0 or timer expired) |
| Matches | Total games played (Wins + Losses) |
| Win Rate % | `(Wins / Matches) × 100` |
| Days Active | Calendar days the app has been used |

---

## 📂 Project Structure

```text
lib/
├── levels/
│   ├── level_base.dart          # Core engine + BentLevelStateMixin
│   ├── level_manager.dart       # Arrow generation algorithm
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
│   ├── auth_provider.dart       # Auth state + account isolation
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
│   ├── level_unlock_service.dart  # Dual-storage progress + reset
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
```

---

## 🏗️ Architecture & Logic

### Arrow Data Models

- **`BentCell`** — A single grid cell `(row, col)`.
- **`BentArrowData`** — Multi-segment arrow. Holds an ordered list of `BentCell` positions, an `escape` direction, a colour, and a `solved` flag. Exposes `hitRect(cellSize)` for tap detection with an extended hit zone in the escape direction.

### Core Engine (`BentLevelStateMixin`)

Mixed into every level screen. Key responsibilities:

- **Timer** — 60-second countdown via `Timer.periodic`; calls `triggerGameOver()` at zero.
- **Arrow Counter** — `ValueNotifier<int> arrowsRemaining` initialized to `arrows.length`. Decremented in the post-solve callback. Drives the HUD counter via `ValueListenableBuilder`.
- **Tap handling** — `onGridTap` / `onTap` → `_findTappedArrow` → `isPathClear` → animate or `wrongTap`.
- **Debouncing** — Per-arrow `_lastTapPerArrow` map prevents ghost taps within a single frame. `_pendingSolve` set blocks re-tapping an arrow already animating out.
- **Victory / Game Over** — `triggerVictory()` records the result via `GameProvider` and calls `LevelUnlockService`; `triggerGameOver()` records a loss.
- **Navigation** — Back button leads to `LevelSelectScreen`.

### Painter Logic (`StraightArrowPainter`)

- Straight shaft from tail-cell centre to head-cell edge, with glow + crisp passes.
- Arrowhead is a closed filled triangle. `hitTest` returns `false` (tap detection delegated to `hitRect`).

### State Management

Provider pattern. `GameProvider` tracks statistics; `AuthProvider` manages authentication and account isolation.

### Data Persistence

- **Cloud**: Stats and level progress stored in Supabase (`game_stats`, `level_progress`).
- **Local**: SharedPreferences for instant session handling and offline progress.

---

## 🛠️ Technology Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend | Supabase (Auth + PostgreSQL) |
| State Management | Provider |
| Audio | audioplayers |
| Email (Contact) | EmailJS REST API |

---

## 🗄️ Supabase Schema

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

### v1.3.0 — Production Final

- ✅ **Real-Time Arrow Counter** — `ValueNotifier<int> arrowsRemaining` added to `BentLevelStateMixin`. HUD shows live `"N Arrows Remaining"` counter via `ValueListenableBuilder`, decrementing on each exit-animation completion.
- ✅ **"Solid Square" label removed** — The static `Text('Solid Square · NxN · N Arrows')` widget and its spacer have been removed from all 10 level build methods. The HUD arrow counter replaces it.
- ✅ **Hard Reset on Logout** — `AuthProvider.logout()` now calls `LevelUnlockService.instance.resetProgress()` before clearing SharedPreferences, preventing level-progress bleed to the next session.
- ✅ **Account Isolation on Login** — `AuthProvider._handleLoginSuccess()` calls `resetProgress()` before persisting the session, forcing `LevelUnlockService` to fetch the authenticated user's real Supabase row on first load.
- ✅ **`LevelUnlockService.resetProgress()` doc updated** — Covers all three call-sites: account deletion, logout, and login.
- ✅ **README rewritten** — Merge conflict resolved; documents Real-Time Counter, Auth Isolation flow, and all prior features.

### v1.2.0

- ✅ Lint fixes — curly braces in flow-control structures across `level_base.dart` and `level_manager.dart`
- ✅ README corrected — level table updated to match actual grid sizes and arrow counts
- ✅ Architecture section rewritten to reflect `BentLevelStateMixin`, debounce logic, and `_gen` three-pass algorithm

### v1.1.0

- ✅ All 10 levels rewritten with precise shapes and exact arrow counts per spec
- ✅ HUD redesigned: Back Button · Level Label · Hearts · Timer + Linear Progress Bar
- ✅ Audio fixed: wrong-move sound on bad tap; lose sound only on zero lives
- ✅ Settings screen: Audio modal with Music and SFX toggles
- ✅ Records screen: Compact rows, accurate Wins/Losses/Matches/Win Rate/Days Active
- ✅ Master Unlock: clearing Level 10 permanently unlocks all levels for free replay
- ✅ Hard delete: account deletion removes user from Supabase Auth + all public tables

### v1.0.0 — Initial Release

- Core gameplay with 10 levels
- Supabase auth + stats sync
- OTP email verification
