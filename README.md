# Harmonic Music

An enhanced fork of [Harmony Music](https://github.com/anandnet/Harmony-Music) - A cross-platform music streaming app made with Flutter (Android, Windows, Linux)

## 🎵 About This Enhanced Fork

This is a significantly enhanced fork of the original Harmony Music project with numerous improvements, bug fixes, and new features. While maintaining the core functionality of the original project, this fork focuses on stability, performance, and user experience enhancements.

## 🔄 Key Improvements

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

## 🎯 All Original Features Plus Enhancements

* ✅ Ability to play song from YouTube/YouTube Music
* ✅ Song cache while playing
* ✅ Radio feature support
* ✅ Background music
* ✅ Playlist creation & bookmark support
* ✅ Artist & Album bookmark support
* ✅ Import song,Playlist,Album,Artist via sharing from YouTube/YouTube Music
* ✅ Streaming quality control
* ✅ Song downloading support
* ✅ Language support
* ✅ Skip silence
* ✅ Dynamic Theme
* ✅ Flexibility to switch between Bottom & Side Nav bar
* ✅ Enhanced Equalizer support with 10-band control
* ✅ Custom preset saving/loading
* ✅ System equalizer fallback
* ✅ Android Auto support
* ✅ Synced & Plain Lyrics support
* ✅ Sleep Timer
* ✅ No Advertisment
* ✅ No Login required
* ✅ Piped playlist integration
* ✅ Nothing device audio processing compatibility

## 📱 Platforms

* Android (Primary focus)
* Windows (Media Kit support)
* Linux (Media Kit support)

## 📦 Dependencies

All original dependencies plus:
* Enhanced Media Kit integration for audio processing
* Proper logging framework implementation

## 📋 Major Changes from Original

For a comprehensive list of all changes, please see [README_FORK.md](README_FORK.md)

## 📖 Documentation

For detailed information about all the enhancements and changes made in this fork, please refer to the comprehensive documentation in [README_FORK.md](README_FORK.md).

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