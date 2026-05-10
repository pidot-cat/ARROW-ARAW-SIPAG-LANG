# Arrow Araw: Sipag Lang

> A logic-based puzzle game developed for the **Application Development & Emerging Technology** course.

---

## Table of Contents

1. [Project Description](#project-description)
2. [Key Features](#key-features)
3. [Tech Stack](#tech-stack)
4. [App Architecture](#app-architecture)
5. [Installation & Running the App](#installation--running-the-app)
6. [Internet Connectivity Requirement](#internet-connectivity-requirement)
7. [Authentication Flow](#authentication-flow)
8. [Gameplay Overview](#gameplay-overview)
9. [Project Structure](#project-structure)
10. [Known Constraints](#known-constraints)

---

## Project Description

**Arrow Araw: Sipag Lang** is a mobile-first logic puzzle game built with Flutter and Dart. Players are presented with a grid of coloured arrows of varying sizes and directions, and must figure out the correct order to tap and clear each arrow off the board without making mistakes.

The app was developed as a course requirement for **Application Development & Emerging Technology**, demonstrating real-world application of:

- Flutter state management via the Provider pattern
- Supabase as a Backend-as-a-Service (BaaS) for authentication and cloud data storage
- Real-time internet connectivity monitoring with enforced online-only access
- A scalable level architecture using mixins and procedural puzzle generation

**The game is online-only.** An active internet connection is required to launch and play. Users who go offline mid-session are blocked from all interaction until connectivity is restored.

---

## Key Features

### Arcade Logic Puzzle Mechanics
- 10 progressively harder levels, each with a unique grid size and arrow count (10 arrows on Level 1 up to 100 arrows on Level 10).
- Arrows can only escape the grid if their exit lane is unobstructed — the player must deduce the correct removal order.
- Three lives per round; a wrong tap costs a life. Losing all lives or running out of time triggers a Game Over.
- A countdown timer per level creates urgency. Adaptive animation speeds at higher levels maintain 60 fps on dense grids.
- All 10 levels are **guaranteed solvable** — the puzzle generator uses a reverse-solve algorithm that builds layouts from a known valid solution order.

### Real-Time Global Connectivity Monitoring (Online-Only Access)
- `ConnectivityProvider` monitors the device's network interface in real time using the `connectivity_plus` package.
- A DNS lookup to `google.com` confirms actual internet reachability (not just Wi-Fi signal), catching captive portals and gateway-less connections.
- `ConnectivityWrapper` is injected globally at the `MaterialApp` level so **every screen** is protected without any per-screen changes.
- When offline: a persistent red SnackBar appears and a full-screen blocking overlay (AbsorbPointer) prevents all user interaction.
- When connectivity is restored: a green "Internet connection restored" SnackBar appears and the overlay lifts automatically.
- The Splash Screen enforces connectivity before any navigation occurs — even previously authenticated users cannot proceed to the Home Screen while offline.

### User Records Tracking
- Each player's cumulative statistics are stored in Supabase and synced locally via SharedPreferences.
- Tracked metrics: **Total Wins**, **Total Losses**, **Total Matches Played**, **Win Rate (%)**, and **Days Played**.
- The Records Screen displays statistics in a modern glassmorphism card grid with a visual win-rate progress bar.
- Stats update in real time after every level completion via `GameProvider` (ChangeNotifier).

### Authentication System
- **Sign Up** — username, email, and password registration via Supabase Auth. Supports optional OTP email confirmation (6-digit code) when enabled in the Supabase Dashboard.
- **Login** — email + password sign-in with specific error handling for unconfirmed accounts and network failures.
- **Forgot Password** — a 3-step OTP recovery flow: enter email, verify 6-digit code, set new password.
- **Logout** — invalidates the Supabase session and clears all locally persisted data from SharedPreferences.
- **Delete Account** — re-authenticates the user before permanently removing account data from Supabase.
- **Account Isolation** — level progress and stats are reset on logout and re-login to prevent data bleed-over between accounts on shared devices.
- **Session Persistence** — SharedPreferences stores the login flag so previously authenticated users bypass the login screen on app restart (subject to internet availability).

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart) |
| **State Management** | Provider (`ChangeNotifier` pattern) |
| **Backend / Auth / Database** | Supabase (PostgreSQL + Supabase Auth) |
| **Local Persistence** | shared_preferences |
| **Connectivity Detection** | connectivity_plus + `dart:io` InternetAddress.lookup |
| **Audio** | audioplayers |
| **Animations** | flutter_animate + Flutter built-in AnimationController |
| **UI Design** | Figma (prototyping and design reference) |
| **Version Control** | Git / GitHub (CI via GitHub Actions) |
| **Language** | Dart 3.x |
| **Target Platforms** | Android (primary), Web (secondary) |

---

## App Architecture

The project follows a clean layered architecture:

```
UI Screens / Widgets
        |
        v
  Providers (State)         <- GameProvider, AuthProvider, ConnectivityProvider
        |
        v
  Services (API Layer)      <- SupabaseService, AudioService, LevelUnlockService
        |
        v
  Backend / Storage         <- Supabase (Auth + DB), SharedPreferences (local cache)
```

Three top-level providers are registered in `MultiProvider` at `main.dart`:

- `GameProvider` — active game state (level, lives, timer, stats persistence).
- `AuthProvider` — authentication state (login/logout/OTP, user identity, session).
- `ConnectivityProvider` — real-time internet status, notifies all screens on change.

---

## Installation & Running the App

### Prerequisites

- Flutter SDK `>=3.10.0` on your PATH
- Dart SDK `>=3.0.0`
- Android Studio or VS Code with the Flutter plugin installed
- A connected Android device or emulator (API level 21+)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/<your-org>/arrow-araw-sipag-lang.git
cd arrow-araw-sipag-lang

# 2. Install Flutter dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run

# 4. Build a release APK
flutter build apk --release
```

> **Important:** The app requires an active internet connection to start. Ensure your device or emulator has network access before launching.

### Supabase Configuration

The Supabase project URL and anon key are set in `lib/main.dart` inside `Supabase.initialize(...)`. To use your own Supabase project:

1. Create a project at supabase.com.
2. Enable **Email** under Authentication → Providers.
3. Create the tables: `game_stats` and `level_progress` (both with a `user_id` column referencing `auth.users`).
4. Optional: configure custom SMTP and update the email template to use `{{ .Token }}` for the OTP code flow.
5. Replace the `url` and `anonKey` values in `Supabase.initialize(...)`.

---

## Internet Connectivity Requirement

**Arrow Araw: Sipag Lang is an online-only application.** This is an intentional design decision.

All gameplay, authentication, and record-keeping depend on a live Supabase connection. The connectivity enforcement works as follows:

1. **On app launch** — `SplashScreen` performs a DNS check before routing anywhere. If offline, the user sees a SnackBar and the app waits, polling every 3 seconds.
2. **During any screen** — `ConnectivityProvider` streams real-time network changes. If the connection drops, `ConnectivityWrapper` immediately renders a blocking overlay across the entire app.
3. **On reconnection** — the overlay lifts automatically and a green SnackBar confirms the restoration.

The DNS check uses `InternetAddress.lookup('google.com')` with a 5-second timeout. This confirms end-to-end internet access rather than just detecting a network interface (which could be Wi-Fi with no internet gateway, or a captive portal).

---

## Authentication Flow

```
App Launch
    |
    +--[Online + valid session]----> Home Screen
    +--[Online + no session]-------> Login Screen
    +--[Offline]-------------------> Splash Screen (blocked, polls every 3 s)

Login Screen
    +-- Login         -------------> Home Screen (on success)
    +-- Sign Up       -------------> Sign Up Screen
    +-- Forgot Pwd    -------------> Forgot Password Screen (3-step OTP)

Sign Up Screen
    +-- [Email confirmation OFF] --> Home Screen (instant session)
    +-- [Email confirmation ON]  --> OTP code field revealed --> Home Screen
```

---

## Gameplay Overview

1. The player selects a level from the **Level Select** grid. Levels unlock sequentially after completion.
2. The game screen shows a grid of coloured, directional arrows.
3. Tap an arrow to send it off the board in its direction — **only if its escape lane is clear** of other arrows.
4. Tapping a blocked arrow costs one life.
5. Clear all arrows to win. Lose all 3 lives, or let the timer expire, and it is Game Over.
6. Winning a level saves a win to the player's Supabase stats record and unlocks the next stage.

---

## Project Structure

```
lib/
|-- main.dart                      Entry point: Supabase init, providers, routes, ConnectivityWrapper
|
|-- models/
|   |-- arrow_model.dart           ArrowModel data class (grid segments, direction, color, escape state)
|   +-- game_stats_model.dart      GameStatsModel (wins, losses, matches, winRate computed property)
|
|-- providers/
|   |-- auth_provider.dart         Auth state: login, logout, OTP verification, session persistence
|   |-- game_provider.dart         Game state: level, lives, countdown timer, stats sync
|   +-- connectivity_provider.dart Real-time internet monitor (DNS-verified, stream-based)
|
|-- services/
|   |-- supabase_service.dart      Single Supabase wrapper for all Auth and database calls
|   |-- audio_service.dart         Singleton audio engine: music + SFX, app-lifecycle aware
|   +-- level_unlock_service.dart  Dual-storage level progress: SharedPreferences + Supabase
|
|-- screens/
|   |-- splash_screen.dart         Launch screen: connectivity gate, animated logo, routing
|   |-- login_screen.dart          Email + password sign-in
|   |-- signup_screen.dart         Account creation with optional OTP email verification
|   |-- forgot_password_screen.dart 3-step OTP password recovery
|   |-- home_screen.dart           Main hub: Play, Records, Settings, About navigation
|   |-- level_select_screen.dart   10-level card grid (locked/unlocked state)
|   |-- game_screen.dart           Legacy single-screen game (retained for compatibility)
|   |-- records_screen.dart        Player stats in glassmorphism card layout
|   |-- settings_screen.dart       Music/SFX toggles, username change, account deletion
|   |-- contact_screen.dart        In-app contact / feedback form
|   |-- about_screen.dart          App description and team credits
|   |-- terms_screen.dart          Terms and Conditions
|   +-- policy_screen.dart         Privacy Policy
|
|-- levels/
|   |-- level_base.dart            Core engine mixin (BentLevelStateMixin): grid rendering,
|   |                                tap logic, timer, win/loss, animations (6 performance fixes)
|   |-- level_manager.dart         Procedural puzzle generator for all 10 levels (reverse-solve)
|   |-- game_screen_lvl_1.dart     Level 1  --  8x8  grid -- 10 arrows  (Beginner)
|   |-- game_screen_lvl_2.dart     Level 2  -- 10x10 grid -- 20 arrows  (Easy)
|   |-- game_screen_lvl_3.dart     Level 3  -- 12x12 grid -- 30 arrows  (Easy)
|   |-- game_screen_lvl_4.dart     Level 4  -- 14x14 grid -- 40 arrows  (Medium)
|   |-- game_screen_lvl_5.dart     Level 5  -- 16x16 grid -- 50 arrows  (Medium)
|   |-- game_screen_lvl_6.dart     Level 6  -- 18x18 grid -- 60 arrows  (Hard)
|   |-- game_screen_lvl_7.dart     Level 7  -- 20x20 grid -- 70 arrows  (Hard)
|   |-- game_screen_lvl_8.dart     Level 8  -- 22x22 grid -- 80 arrows  (Expert)
|   |-- game_screen_lvl_9.dart     Level 9  -- 24x24 grid -- 90 arrows  (Expert)
|   +-- game_screen_lvl_10.dart    Level 10 -- 18x18 grid -- 100 arrows (Final / Expert)
|
|-- widgets/
|   |-- connectivity_wrapper.dart  Global offline overlay + SnackBar via MaterialApp.builder
|   |-- background_wrapper.dart    Screen shell: background image, logo, back button
|   |-- gradient_button.dart       Primary CTA button with gradient fill and shadow
|   |-- gradient_input_field.dart  Styled text field with gradient border and visibility toggle
|   |-- life_indicator.dart        Row of heart icons representing remaining lives
|   |-- game_over_overlay.dart     Full-screen overlay shown on life-out or timeout
|   +-- victory_overlay.dart       Full-screen overlay shown on level cleared
|
+-- utils/
    |-- constants.dart             AppConstants: grid config, SharedPreferences keys, asset paths
    +-- app_colors.dart            AppColors: full colour palette, gradients, named arrow colours
```

---

## Known Constraints

- **Online-only.** The app will not navigate past the Splash Screen without an active internet connection. This is by design, not a bug.
- **Android and Web only.** iOS platform files exist in the project but iOS is not the primary test target.
- **Supabase free tier.** Projects on the Supabase free tier pause after 1 week of inactivity. If the app cannot connect, verify the Supabase project is active at supabase.com.
- **Sequential level unlocking.** Levels must be completed in order. There is no level-skip feature.
- **No guest mode.** All gameplay statistics and level progress require a Supabase-authenticated user account.

---

*Developed for the Application Development & Emerging Technology course.*  
*Built with Flutter · Supabase · and a lot of patience.*
