#!/usr/bin/env bash
# Render static-site build for the BALAGHJO Flutter web app
# (serves both the mobile web app at /index.html and the admin
# dashboard at /admin.html). Render has no Flutter, so install it.
set -e

if [ ! -d .flutter ]; then
  echo "==> Installing Flutter SDK"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git .flutter
fi

export PATH="$PWD/.flutter/bin:$PATH"
flutter config --no-analytics

echo "==> Building web"
flutter build web --release --dart-define=API_BASE_URL=https://balaghjo.onrender.com
