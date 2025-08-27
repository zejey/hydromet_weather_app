# HydroMet Weather App

**HydroMet Weather App** is an advanced weather information and risk-awareness application, developed specifically for San Pedro, Laguna, Philippines.  
It provides real-time weather updates, local hazard warnings, air quality data, emergency hotlines, and safety tips for residents—all in a user-friendly, interactive interface.

---

## Features

- **Real-Time Weather Data:**  
  Get current weather conditions, 24-hour forecasts, and detailed weather metrics for San Pedro, Laguna.
- **Hazard Monitoring:**  
  Visualize local flood, storm surge, heat, air pollution, landslide, and earthquake risks on an interactive map.
- **Air Quality Index:**  
  Stay informed about the current air quality and receive health advice.
- **Emergency Hotlines & Safety Tips:**  
  Quick access to local emergency numbers and preparedness guides.
- **Push Notifications:**  
  Receive important weather and safety alerts (available to logged-in users).
- **User Authentication:**  
  Secure OTP-based login via mobile phone number.

---

## Requirements

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.0+ recommended)
- Dart (comes with Flutter)
- [Firebase Account & Project](https://firebase.google.com/)  
  (for OTP authentication and notifications)
- [OpenWeatherMap API Key](https://openweathermap.org/api)  
  (for weather and air quality data)
- Internet connection

### Python Backend (if you plan to use Python modules):

Some features may require Python scripts or services (see `python/` or relevant directory if available).

- Python 3.8+
- Required Python packages (see `requirements.txt`):

  ```bash
  pip install -r requirements.txt
  ```

### Flutter/Dart Dependencies

See `pubspec.yaml` for a full list of required Dart/Flutter packages, but main ones include:
- `flutter_map`
- `latlong2`
- `firebase_auth`
- `cloud_firestore`
- `shared_preferences`
- `http`

---

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/zejey/hydromet_weather_app.git
   cd hydromet_weather_app
   ```

2. **Install Flutter/Dart dependencies:**
   ```bash
   flutter pub get
   ```

3. **(If using Python backend) Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up Firebase:**
   - Create a Firebase project.
   - Enable Phone Authentication.
   - Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) and place in the appropriate directory.

5. **Add your OpenWeatherMap API key:**
   - Replace the placeholder API key in `weather_service.dart` with your own.

6. **Run the app:**
   ```bash
   flutter run
   ```

---

## About the Team

**Developed by:**  
**Group 4 HydroMET**  
Polytechnic University of San Pedro,  
Bachelor of Science in Information Technology (BSIT)

---

## License

This project is for educational purposes.

---