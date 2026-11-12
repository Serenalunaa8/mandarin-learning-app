# Nihaoki

Nihaoki is a Flutter app for learning Mandarin, with lessons, vocabulary,
practice, games, progress tracking, and location-based nearby-place discovery.

## Run locally

```powershell
flutter pub get
flutter run
```

The app's AI assistant uses a Supabase Edge Function. Configure it using
[supabase/AI_TUTOR_SETUP.md](./supabase/AI_TUTOR_SETUP.md).

Nearby places are retrieved from OpenStreetMap's Overpass API and displayed on
OpenStreetMap tiles. Results are limited to a 3 km radius from the device's
current location; they are not Google Maps data.
