# 🔑 Firebase API Key Update

## In lib/config/firebase_config.dart ändern:

### ALT (kompromittiert):
```dart
apiKey: 'YOUR_FIREBASE_API_KEY_HERE',
```

### NEU (Ihren neuen Key hier eintragen):
```dart
apiKey: 'IHR_NEUER_API_KEY_HIER',
```

## Ändern Sie den Key in ALLEN Sections:
- FirebaseOptions web
- FirebaseOptions ios  
- FirebaseOptions macos
- FirebaseOptions windows

## Speichern mit: Ctrl+X → Y → Enter

## Danach testen:
```bash
flutter run -d macos
```

App sollte normal starten und Cloud Sync sollte funktionieren!