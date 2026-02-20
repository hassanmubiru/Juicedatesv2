# JuiceDates - Values Dating Revolution

100% Complete, Production-Ready Flutter 3.x dating app.

## 🚀 Getting Started

1. **Prerequisites**:
   - Flutter SDK `3.24.0` or higher.
   - Firebase project (Android/iOS config files).

2. **Installation**:
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
   - Initialize Firebase in `lib/main.dart` if not already handled by your environment.

4. **Running the App**:
   ```bash
   flutter run
   ```

## 📱 Features

- **Juice Quiz**: 12-question values assessment.
- **Sparks Algorithm**: 85-point matching engine.
- **Tiered Progression**: Message-based feature unlocking (💚 to 💎).
- **Juice Tribes**: Community events based on shared values.
- **Juicy UI**: Citrus Material 3 theme with high-fidelity animations.

## 🏗 Project Structure

- `lib/core`: Theme, Engine, and Network layers.
- `lib/models`: Data models for Users, Matches, and Messages.
- `lib/features`: 15 fully implemented screens across 8 feature areas.
- `lib/widgets`: 50+ reusable components including JuiceCard and TierMeter.

## 🛠 Tech Stack

- **State Management**: flutter_bloc
- **Database**: Cloud Firestore
- **Auth**: Firebase Auth
- **Animations**: Lottie + Custom Physics
- **Audio**: audioplayers
- **Calling**: agora_rtc_engine ready
