#!/bin/bash

echo "🔐 Firebase Secure Setup für ESPP Manager"
echo "========================================="
echo ""

# Check if firebase_config.dart already exists
if [ -f "lib/config/firebase_config.dart" ]; then
    echo "✅ firebase_config.dart existiert bereits"
    echo "   Datei ist in .gitignore und wird NICHT committed"
else
    echo "⚠️  firebase_config.dart fehlt!"
    echo ""
    echo "Bitte kopieren Sie firebase_config.dart.example zu firebase_config.dart"
    echo "und fügen Sie Ihre Firebase-Konfiguration ein:"
    echo ""
    echo "  cp lib/config/firebase_config.dart.example lib/config/firebase_config.dart"
    echo "  nano lib/config/firebase_config.dart"
    echo ""
    exit 1
fi

# Check if GoogleService-Info.plist files are in git
echo ""
echo "🔍 Prüfe ob sensible Dateien in Git sind..."

FILES_TO_CHECK=(
    "macos/Runner/GoogleService-Info.plist"
    "ios/Runner/GoogleService-Info.plist"
    "android/app/google-services.json"
)

FOUND_IN_GIT=false

for file in "${FILES_TO_CHECK[@]}"; do
    if git ls-files --error-unmatch "$file" 2>/dev/null; then
        echo "❌ WARNUNG: $file ist in Git!"
        FOUND_IN_GIT=true
    fi
done

if [ "$FOUND_IN_GIT" = true ]; then
    echo ""
    echo "⚠️  KRITISCH: Sensible Dateien sind in Git!"
    echo ""
    echo "Diese Dateien entfernen mit:"
    echo "  git rm --cached macos/Runner/GoogleService-Info.plist"
    echo "  git rm --cached ios/Runner/GoogleService-Info.plist"
    echo "  git commit -m 'Remove sensitive Firebase config files'"
    echo ""
    echo "Dann Git-History bereinigen mit:"
    echo "  git filter-branch --force --index-filter \\"
    echo "    'git rm --cached --ignore-unmatch **/GoogleService-Info.plist' \\"
    echo "    --prune-empty --tag-name-filter cat -- --all"
else
    echo "✅ Keine sensiblen Dateien in Git gefunden"
fi

echo ""
echo "📋 Sicherheits-Checkliste:"
echo "=========================="
echo ""
echo "[ ] firebase_config.dart ist NICHT in Git"
echo "[ ] GoogleService-Info.plist Dateien sind NICHT in Git"
echo "[ ] .gitignore enthält alle Firebase-Config-Dateien"
echo "[ ] Keine API Keys direkt im Code"
echo "[ ] Firebase API Keys in Console rotiert (falls bereits exposed)"
echo ""
echo "🔐 Erst wenn ALLE Punkte ✅ sind, kann das Repo public gemacht werden!"
echo ""