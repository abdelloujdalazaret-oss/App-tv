#!/usr/bin/env bash
# Génère le projet Android autour du code et applique la configuration.
set -e
flutter create --platforms=android --org com.playerflow --project-name player_flow .
cp -r android_overlay/app/. android/app/

G=android/app/build.gradle
[ -f android/app/build.gradle.kts ] && G=android/app/build.gradle.kts
# minSdk 21
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 21/; s/minSdkVersion flutter.minSdkVersion/minSdkVersion 21/' "$G"
# R8 / ProGuard pour la release
if ! grep -q proguard-rules "$G"; then
  if [[ "$G" == *.kts ]]; then
    sed -i 's/signingConfig = signingConfigs.getByName("debug")/signingConfig = signingConfigs.getByName("debug")\n            isMinifyEnabled = true\n            isShrinkResources = true\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")/' "$G"
  else
    sed -i 's/signingConfig signingConfigs.debug/signingConfig signingConfigs.debug\n            minifyEnabled true\n            shrinkResources true\n            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro"/' "$G"
  fi
fi

flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
echo "OK. Lancez : flutter build apk --release"
