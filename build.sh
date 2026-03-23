#!/bin/bash
echo "Installing Flutter..."
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PATH:`pwd`/flutter/bin"
echo "Building Flutter Web..."
flutter pub get
flutter build web --release
