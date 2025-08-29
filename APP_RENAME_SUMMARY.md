# App Rename: Harmony Music → Harmonic

This document summarizes all the changes made to rename the app from "Harmony Music" to "Harmonic".

## ✅ **Completed Changes**

### **1. Main Configuration**
- **File**: [`pubspec.yaml`](pubspec.yaml)
  - `name`: `harmonymusic` → `harmonic`
  - `description`: Updated to reflect Harmonic branding with "perfect harmony"

### **2. Android Configuration**
- **File**: [`android/app/build.gradle`](android/app/build.gradle)
  - `applicationId`: `com.anandnet.harmonymusic` → `com.jon4short.harmonic`
  - `namespace`: Updated to match new application ID

- **File**: [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
  - `android:label`: `Harmony Music` → `Harmonic`

### **3. iOS Configuration**
- **File**: [`ios/Runner/Info.plist`](ios/Runner/Info.plist)
  - `CFBundleDisplayName`: `Harmonymusic` → `Harmonic`
  - `CFBundleName`: `harmonymusic` → `harmonic`

### **4. Web Configuration**
- **File**: [`web/manifest.json`](web/manifest.json)
  - `name`: `harmonymusic` → `Harmonic`
  - `short_name`: `harmonymusic` → `Harmonic`
  - `description`: Updated with Harmonic branding

- **File**: [`web/index.html`](web/index.html)
  - `title`: `harmonymusic` → `Harmonic`
  - `apple-mobile-web-app-title`: Updated to `Harmonic`
  - `description`: Updated meta description

### **5. Linux Configuration**
- **File**: [`linux/CMakeLists.txt`](linux/CMakeLists.txt)
  - `BINARY_NAME`: `harmonymusic` → `harmonic`
  - `APPLICATION_ID`: `com.example.harmonymusic` → `com.jon4short.harmonic`

### **6. Windows Configuration**
- **File**: [`windows/CMakeLists.txt`](windows/CMakeLists.txt)
  - `project()`: `harmonymusic` → `harmonic`
  - `BINARY_NAME`: `harmonymusic` → `harmonic`

### **7. macOS Configuration**
- **File**: [`macos/Runner/Configs/AppInfo.xcconfig`](macos/Runner/Configs/AppInfo.xcconfig)
  - `PRODUCT_NAME`: `harmonymusic` → `harmonic`
  - `PRODUCT_BUNDLE_IDENTIFIER`: `com.anandnet.harmonymusic` → `com.jon4short.harmonic`

## 🎨 **Logo & Branding (Still Required)**

The following logo/icon files need to be updated with Harmonic branding:

### **Main Icons** (Replace with Harmonic logo)
- [`assets/icons/icon.png`](assets/icons/icon.png) - Cross-platform app icon
- [`assets/icons/icon.ico`](assets/icons/icon.ico) - Windows icon

### **Android Icons** (All densities)
- [`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png)
- [`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png`](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png)
- [`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.png`](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_background.png)
- [`android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_monochrome.png`](android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_monochrome.png)
- Similar files in `mipmap-hdpi`, `mipmap-mdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`

### **iOS Icons** (Complete icon set)
- [`ios/Runner/Assets.xcassets/AppIcon.appiconset/`](ios/Runner/Assets.xcassets/AppIcon.appiconset/) - All iOS app icons
- App Store icon: `Icon-App-1024x1024@1x.png`
- Various sizes from 20x20 to 83.5x83.5 at different resolutions

### **Web Icons**
- [`web/icons/Icon-192.png`](web/icons/Icon-192.png)
- [`web/icons/Icon-512.png`](web/icons/Icon-512.png)
- [`web/icons/Icon-maskable-192.png`](web/icons/Icon-maskable-192.png)
- [`web/icons/Icon-maskable-512.png`](web/icons/Icon-maskable-512.png)
- [`web/favicon.png`](web/favicon.png)

## 🎵 **Harmonic Design Concepts**

### **Visual Identity for "Harmonic"**
- **Musical Harmony**: Focus on musical intervals and chord progressions
- **Mathematical Beauty**: Golden ratio, wave patterns, frequency visualization
- **Logo Ideas**:
  - Overlapping sine waves creating harmony
  - Musical staff with harmonic intervals
  - Geometric shapes representing harmonic series
  - Sound waves converging into perfect harmony
  - Tuning fork with resonant waves

### **Color Palette Suggestions**
- **Primary**: Deep blues and purples (calming harmony)
- **Accents**: Gold/amber for warmth and resonance
- **Gradients**: Smooth transitions representing harmonic flow
- **Dark Theme**: Deep navy with golden highlights
- **Light Theme**: Clean whites with soft blue accents

## 🚀 **Next Steps**

1. **Design Harmonic Logo**: Create new logo reflecting musical harmony theme
2. **Generate Icon Sizes**: Use tools like [App Icon Generator](https://appicon.co/) 
3. **Update All Icons**: Replace existing icons with Harmonic branded versions
4. **Test Build**: Run `flutter clean && flutter pub get && flutter run`
5. **Update Documentation**: Update README.md and other docs with new name
6. **Update Repository**: Consider renaming repository to match

## 🔧 **Build Commands After Rename**

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Test the rename
flutter run

# Build for distribution with new name
./build_split_apks.sh
```

## 📱 **Application IDs Changed**

| Platform | Old ID | New ID |
|----------|--------|--------|
| Android | `com.anandnet.harmonymusic` | `com.jon4short.harmonic` |
| iOS | `com.anandnet.harmonymusic` | `com.jon4short.harmonic` |
| macOS | `com.anandnet.harmonymusic` | `com.jon4short.harmonic` |
| Linux | `com.example.harmonymusic` | `com.jon4short.harmonic` |

## ✅ **Status: Configuration Complete**

All platform configuration files have been updated. The app is now ready to be built as "Harmonic" once the logo/icon assets are replaced with the new Harmonic branding.