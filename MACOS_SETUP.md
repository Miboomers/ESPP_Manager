# macOS Code Signing Setup

## Benötigte Informationen von Dir:

### 1. Apple Developer Account Details:
- **Team ID**: Deine 10-stellige Team ID (findest du im Apple Developer Portal)
- **Apple ID**: Die E-Mail-Adresse deines Developer Accounts
- **Bundle Identifier**: Soll `com.esppmanager.esppManager` bleiben oder ändern?

### 2. Setup-Schritte:

#### Schritt 1: Xcode öffnen
```bash
open macos/Runner.xcworkspace
```

#### Schritt 2: Signing & Capabilities konfigurieren
1. **Runner** (Target) auswählen
2. **Signing & Capabilities** Tab
3. **Team** dropdown → Deine Apple Developer Team auswählen
4. **Bundle Identifier** prüfen: `com.esppmanager.esppManager`

#### Schritt 3: Entitlements prüfen
Die Dateien sind bereits konfiguriert:
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

Beide enthalten bereits:
```xml
<key>com.apple.security.keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.esppmanager.esppManager</string>
    <string>$(AppIdentifierPrefix)com.esppmanager.esppManager.shared</string>
</array>
```

#### Schritt 4: Build und Test
```bash
flutter run -d macos
```

## Aktuelle Entitlements:

### DebugProfile.entitlements:
- ✅ App Sandbox
- ✅ Network Client/Server
- ✅ Keychain Access Groups
- ✅ Application Groups
- ✅ JIT Compilation (für Debug)

### Release.entitlements:
- ✅ App Sandbox  
- ✅ Network Client
- ✅ Keychain Access Groups
- ✅ Application Groups

## Fallback-Lösung (falls Probleme):

AuthService ist bereits so konfiguriert, dass er bei macOS/Web auf SharedPreferences zurückfällt, wenn Keychain nicht verfügbar ist.

## Nach erfolgreicher Konfiguration:

Dann funktionieren:
- ✅ Keychain-basierte Verschlüsselung
- ✅ PIN-Speicherung
- ✅ Biometrische Authentifizierung
- ✅ Alle App-Features nativ

---

**Was benötige ich von dir?**
1. Deine **Team ID** aus dem Apple Developer Portal
2. Bestätigung der **Bundle ID**: `com.esppmanager.esppManager`
3. Soll ich andere Identifier verwenden?