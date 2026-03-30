#!/bin/bash

# ==============================================================================
# Split Bill Production Deployment Script
# This script builds the app with obfuscation and deploys only the binary + 
# localized release notes (15 locales) to the stores.
# ==============================================================================

set -e # Exit on error

echo "🚀 Starting Production Deployment for 1.1.0+8 (Internal Note: 1.1.0=8)"

# 1. Prepare Metadata (Full Localization for 15+ Locales)
echo "📝 Generating full localized metadata (Titles, Descriptions, Promo, etc.)..."
python3 fastlane/update_metadata.py
python3 fastlane/trimmer.py

# 2. METADATA SECURITY: We no longer delete files here. 
# The 'update_metadata.py' script now handles creating all necessary files for 15 locales.
echo "✅ Metadata preparation complete."

# 3. Build Android (AAB) with Obfuscation
if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ Android AAB already exists. Skipping build..."
else
    echo "🤖 Building Android AAB (Obfuscated)..."
    flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
fi

# 4. Build iOS (IPA) with Obfuscation
if ls build/ios/ipa/*.ipa 1> /dev/null 2>&1; then
    echo "✅ iOS IPA already exists. Skipping build..."
else
    echo "🍎 Building iOS IPA (Obfuscated)..."
    flutter build ipa --release --obfuscate --split-debug-info=build/ios/archive/symbols
fi

# 5. Deploy to Google Play Store
echo "🚀 Deploying to Google Play Store (Production)..."
fastlane android deploy

# 6. Deploy to Apple App Store
echo "🚀 Deploying to Apple App Store (Production)..."
fastlane ios release

echo "✅ Deployment process completed successfully!"
