#!/bin/bash
echo "Installing Flutter..."
# Fixado na versão 3.41.5 para garantir builds consistentes com o ambiente local.
# NÃO usar "-b stable" pois pega sempre a versão mais recente e pode quebrar.
FLUTTER_VERSION="3.41.5"
rm -rf flutter
git clone https://github.com/flutter/flutter.git --branch ${FLUTTER_VERSION} --depth 1
export PATH="$PATH:`pwd`/flutter/bin"
echo "Building Flutter Web com Flutter ${FLUTTER_VERSION}..."
flutter pub get
BUILD_HASH=${VERCEL_GIT_COMMIT_SHA:0:7}
flutter build web --release --dart-define=APP_ENV=${APP_ENV:-dev} --dart-define=BUILD_HASH=${BUILD_HASH:-local}
