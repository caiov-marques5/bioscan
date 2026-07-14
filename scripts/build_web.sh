#!/usr/bin/env bash
# Builds the Flutter web app inside Vercel's build container.
# Flutter isn't preinstalled on Vercel, so we fetch the stable SDK on the fly.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.3}"
FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Downloading Flutter $FLUTTER_VERSION ..."
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version
flutter config --enable-web

cd flutter_app
# Generate platform folders (web/, etc.) that aren't checked into the repo.
flutter create --platforms=web --project-name bioscan .
flutter pub get
flutter build web --release
echo "Web build complete -> flutter_app/build/web"
