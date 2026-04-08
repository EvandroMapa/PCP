#!/bin/bash
echo "Installing Flutter..."
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi
export PATH="$PATH:`pwd`/flutter/bin"
echo "Building Flutter Web..."
flutter pub get
BUILD_HASH=${VERCEL_GIT_COMMIT_SHA:0:7}
flutter build web --release --dart-define=APP_ENV=${APP_ENV:-dev} --dart-define=BUILD_HASH=${BUILD_HASH:-local}
