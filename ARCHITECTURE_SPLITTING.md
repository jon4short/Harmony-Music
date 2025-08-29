# Architecture Splitting for Harmony Music

This document explains the architecture splitting configuration that reduces APK size by up to 75%.

## Overview

Architecture splitting creates separate APKs for different CPU architectures instead of including all architectures in a single APK. This dramatically reduces the download size for end users.

## Configuration

### Android Build Configuration

The `android/app/build.gradle` has been configured with:

1. **ABI Splits**: Enabled for arm64-v8a, armeabi-v7a, x86, x86_64
2. **Universal APK**: Also builds a universal APK as fallback
3. **Version Code Management**: Unique version codes for each architecture

### Architecture Details

| Architecture | Target Devices | Usage |
|-------------|----------------|-------|
| `arm64-v8a` | Modern Android phones (2019+) | **Primary** - Most devices |
| `armeabi-v7a` | Older Android phones (2012-2019) | **Secondary** - Legacy support |
| `x86` | Intel tablets, emulators | **Testing** - Limited real-world use |
| `x86_64` | Intel devices, emulators | **Testing** - Limited real-world use |
| `universal` | All devices | **Fallback** - Largest size |

## Building Split APKs

### Method 1: Using Build Script (Recommended)
```bash
./build_split_apks.sh
```

### Method 2: Manual Flutter Command
```bash
flutter build apk --release --split-per-abi
```

### Method 3: Build Specific Architecture
```bash
# For ARM64 only (most common)
flutter build apk --release --target-platform android-arm64

# For ARM32 only
flutter build apk --release --target-platform android-arm
```

## Expected Size Reduction

### Before Architecture Splitting
- Universal APK: ~208MB

### After Architecture Splitting
- arm64-v8a APK: ~52MB (75% reduction)
- armeabi-v7a APK: ~52MB (75% reduction)
- x86 APK: ~52MB (75% reduction)
- x86_64 APK: ~52MB (75% reduction)
- universal APK: ~208MB (unchanged - includes all)

## Play Store Distribution

### Automatic Delivery
When you upload multiple architecture-specific APKs to Google Play Store:

1. **Automatic Selection**: Play Store automatically serves the correct APK based on device architecture
2. **Smaller Downloads**: Users get 75% smaller downloads
3. **Better Experience**: Faster installation and updates
4. **Fallback Support**: Universal APK serves as fallback for unsupported architectures

### Upload Strategy
1. Upload all architecture-specific APKs
2. Upload universal APK with higher version code as fallback
3. Enable "Multiple APK support" in Play Console

## Version Code Management

The configuration automatically manages version codes:

```
Architecture-specific version code = (architecture_code * 1000) + base_version_code

Example:
- Base version: 25
- arm64-v8a: 2025 (2 * 1000 + 25)
- armeabi-v7a: 1025 (1 * 1000 + 25)
- x86: 3025 (3 * 1000 + 25)
- x86_64: 4025 (4 * 1000 + 25)
```

## Testing

### Local Testing
```bash
# Install specific architecture on device
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Check device architecture
adb shell getprop ro.product.cpu.abi
```

### Recommended Testing Matrix
- **ARM64**: Test on modern phones (Pixel, Samsung Galaxy S20+)
- **ARM32**: Test on older devices (Android 7-9)
- **Universal**: Test as fallback on various devices

## Benefits

### For Users
- ✅ 75% smaller downloads
- ✅ Faster installation
- ✅ Reduced storage usage
- ✅ Faster updates

### For Developers
- ✅ Better Play Store rankings (smaller APK size)
- ✅ Reduced bandwidth costs
- ✅ Improved user acquisition
- ✅ Better performance metrics

## Troubleshooting

### Build Issues
If architecture splitting fails:
1. Check Flutter version compatibility
2. Verify NDK installation
3. Clean and rebuild: `flutter clean && flutter pub get`

### Distribution Issues
If Play Store rejects APKs:
1. Ensure version codes are unique and ascending
2. Check that all APKs have same package name
3. Verify signing consistency across APKs

## Additional Optimizations

For even smaller APKs, consider:
1. **ProGuard/R8**: Enable code shrinking
2. **Remove unused resources**: Clean asset folders
3. **Optimize images**: Use WebP format
4. **Minify**: Enable resource minification

## Commands Reference

```bash
# Build all split APKs
flutter build apk --release --split-per-abi

# Build universal APK
flutter build apk --release

# Analyze APK size
flutter build apk --analyze-size

# Check what's in the APK
unzip -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```