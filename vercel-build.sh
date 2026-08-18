#!/usr/bin/env bash
set -e

# The app uses current DropdownButtonFormField APIs; pin a stable SDK new
# enough to compile them while keeping Vercel deployments reproducible.
FLUTTER_VERSION="3.44.9"

if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git \
    --branch "$FLUTTER_VERSION" \
    --depth 1 \
    flutter
fi

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
# - no Flutter PWA worker (home-screen icon must fetch each new Vercel deploy)
flutter build web --release \
  --no-source-maps \
  --tree-shake-icons \
  --no-web-resources-cdn \
  --pwa-strategy=none \
  -O4 \
  "${BUILD_ARGS[@]}"

# Phones that already installed the old Flutter worker still request this URL
# (no-store). Copy the kill-switch after build so Flutter cannot omit it.
cp -f web/flutter_service_worker.js build/web/flutter_service_worker.js

DEPLOY_ID="${VERCEL_GIT_COMMIT_SHA:-}"
if [ -z "$DEPLOY_ID" ]; then
  DEPLOY_ID="$(date -u +%Y%m%dT%H%M%SZ)"
fi
printf '%s\n' "$DEPLOY_ID" > build/web/deploy-id.txt
echo "Wrote deploy-id.txt=$DEPLOY_ID"
