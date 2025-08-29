# Harmonic Music

A cross-platform music streaming app made with Flutter (Android, Windows, Linux) - Enhanced Fork of Harmony Music

## 🎵 About This Fork

This is a significantly enhanced fork of the original [Harmony Music](https://github.com/anandnet/Harmony-Music) project with numerous improvements, bug fixes, and new features. While maintaining the core functionality of the original project, this fork focuses on stability, performance, and user experience enhancements.

## 🔄 Fork Improvements

### 🛠️ Technical Improvements
- **Enhanced Equalizer System**: Built-in Media Kit equalizer with 10-band frequency control
- **Proper Logging Framework**: Replaced all print statements with production-ready logging
- **Code Quality**: Fixed 25+ code analysis issues and warnings
- **Package Name Update**: Updated from `com.anandnet.harmonymusic` to `com.jon4short.harmonic`
- **JNI Bindings Fix**: Corrected package name mismatches in Android Kotlin bindings
- **Permission Fixes**: Added necessary Android permissions for audio effects

### 🎚️ Audio Features
- **Built-in Equalizer**: 10-band equalizer with ±15dB range and 7 preset profiles
- **Custom Presets**: Save and load custom equalizer configurations
- **Media Kit Integration**: Direct MPV audio filter support (when available)
- **System Equalizer Fallback**: Automatic fallback to Android system equalizer
- **Nothing Device Support**: Special handling for Nothing phones/buds audio processing

### 📱 UI/UX Enhancements
- **Modern Material Design 3**: Updated UI with Material Design 3 components
- **Equalizer Screen**: Dedicated equalizer interface with vertical sliders
- **Preset Chips**: Easy selection of audio profiles
- **Real-time Feedback**: Visual indicators for active equalizer settings

### 🧪 Testing & Quality
- **Comprehensive Test Suite**: 12 test cases covering equalizer functionality
- **AudioFlux Testing**: Key detection service testing
- **Widget Tests**: Basic UI component verification
- **Production Logging**: Proper error handling and logging throughout

### 🗑️ Cleanup & Optimization
- **Removed Unnecessary Files**: Deleted 17+ temporary scripts and test files
- **Unused Import Cleanup**: Removed 9+ unused import warnings
- **Code Modernization**: Updated deprecated methods and practices

## 📋 Major Changes from Original

### Core Functionality
1. **Equalizer Redesign**: Completely rebuilt equalizer system with Media Kit support
2. **Audio Processing**: Enhanced audio filter implementation using MPV superequalizer
3. **Device Compatibility**: Special handling for Nothing ecosystem devices
4. **Error Handling**: Robust error handling with proper logging instead of print statements

### Code Structure
1. **New Models**: `EqualizerBand`, `EqualizerPreset`, `EqualizerConfig` data models
2. **Services**: `MediaKitEqualizer` service for audio processing
3. **UI Components**: Dedicated equalizer screen with Material Design 3
4. **Testing**: Comprehensive test suite for new functionality

### Android Integration
1. **Package Name**: Changed from `com.anandnet.harmonymusic` to `com.jon4short.harmonic`
2. **Permissions**: Added `MODIFY_AUDIO_SETTINGS` and `RECORD_AUDIO` for equalizer
3. **JNI Bindings**: Fixed package name mismatches in Kotlin bindings
4. **Manifest Updates**: Updated AndroidManifest.xml with proper permissions

## 🎯 Features

All original Harmony Music features plus:

* ✅ Enhanced Equalizer with 10-band control
* ✅ Custom preset saving/loading
* ✅ System equalizer fallback
* ✅ Nothing device audio processing compatibility
* ✅ Modern Material Design 3 UI
* ✅ Comprehensive testing suite
* ✅ Production-ready logging
* ✅ Improved code quality and maintainability

## 📱 Platforms

* Android (Primary focus)
* Windows (Media Kit support)
* Linux (Media Kit support)

## 📦 Dependencies

All original dependencies plus:
* Enhanced Media Kit integration for audio processing
* Proper logging framework implementation

## 🙏 Credits & Acknowledgments

This project is a fork of [Harmony Music](https://github.com/anandnet/Harmony-Music) by [anandnet](https://github.com/anandnet).

### Original Project Credits:
* [Flutter documentation](https://docs.flutter.dev/) - Best guide for cross-platform UI/app development
* [Suragch](https://suragch.medium.com/) - Articles related to Just Audio & state management
* [sigma67](https://github.com/sigma67) - Unofficial YouTube Music API project
* [vfsfitvnm](https://github.com/vfsfitvnm) - ViMusic app UI inspiration
* [LRCLIB](https://lrclib.net) - Synced lyrics provider
* [Piped](https://piped.video) - Playlist integration

### Original Major Packages:
* just_audio: ^0.9.40 - Audio player for Android
* media_kit: ^1.1.9 - Audio player for Linux and Windows
* audio_service: ^0.18.15 - Background music & platform audio services
* get: ^4.6.6 - State management, dependency injection, and routing
* youtube_explode_dart: ^2.0.2 - Third-party package for song URLs
* hive: ^2.2.3 - Offline database
* hive_flutter: ^1.1.0

## 📄 License

Harmonic Music maintains the same licensing as the original Harmony Music:

```
Harmony Music is free software licensed under GPL v3.0 with the following conditions:

- Copied/Modified versions of this software cannot be used for 'non-free' and profit purposes.
- You cannot publish copied/modified versions of this app on closed-source app repositories
  like PlayStore/AppStore.
```

## 🚨 Disclaimer

```
This project has been created while learning, and learning is the main intention.
This project is not sponsored or affiliated with, funded, authorized, endorsed by any content provider.
Any song, content, trademark used in this app are intellectual property of their respective owners.
Harmonic Music is not responsible for any infringement of copyright or other intellectual property rights that may result
from the use of the songs and other content available through this app.

This Software is released "as-is", without any warranty, responsibility or liability.
In no event shall the Author of this Software be liable for any special, consequential,
incidental or indirect damages whatsoever (including, without limitation, any 
other pecuniary loss) arising out of the use of inability to use this product, even if
Author of this Software is aware of the possibility of such damages and known defect.
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 Support

For support, please open an issue on the GitHub repository.