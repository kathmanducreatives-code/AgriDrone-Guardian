#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting AgriDrone Web Build Process..."

# 1. Get dependencies
echo "📦 Running flutter pub get..."
flutter pub get

# 2. Build for web
echo "🛠 Building Flutter Web (Release)..."
flutter build web --release

# 3. Inject Vercel configuration
if [ -f "vercel.json" ]; then
    echo "📋 Copying vercel.json to build/web/..."
    cp vercel.json build/web/vercel.json
else
    echo "⚠️ Warning: vercel.json not found in root. Creating a default one in build/web/..."
    cat <<EOF > build/web/vercel.json
{
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
EOF
fi

test -f build/web/index.html
test -d build/web/assets

echo "✅ Build complete! Output is in build/web/"
