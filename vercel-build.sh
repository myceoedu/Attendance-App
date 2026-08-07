#!/usr/bin/env bash
set -e

FLUTTER_REVISION="8defaa71a77c16e8547abdbfad2053ce3a6e2d5b"

if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

git -C flutter fetch --depth 1 origin "$FLUTTER_REVISION"
git -C flutter checkout --detach "$FLUTTER_REVISION"

export PATH="$PWD/flutter/bin:$PATH"

flutter --version
flutter pub get

BUILD_ARGS=()
if [ -n "${SUPABASE_URL:-}" ]; then
  BUILD_ARGS+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
fi
if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  BUILD_ARGS+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
fi

if [ ${#BUILD_ARGS[@]} -eq 0 ]; then
  echo "Note: SUPABASE_URL / SUPABASE_ANON_KEY not set on Vercel — using app defaults."
fi

# Release web (PageSpeed-oriented):
# - no source maps (smaller deploy)
# - tree-shake unused Material/Cupertino glyphs
# - host CanvasKit on same origin (better cache / no gstatic CDN hop)
# - max dart2js optimization
flutter build web --release \
  --no-source-maps \
  --tree-shake-icons \
  --no-web-resources-cdn \
  -O4 \
  "${BUILD_ARGS[@]}"
