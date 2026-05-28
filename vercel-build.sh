#!/usr/bin/env bash
set -e

if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
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

flutter build web --release "${BUILD_ARGS[@]}"
