# ADB Stress Testing Suite for Harmony Music App

A comprehensive stress testing solution using Android Debug Bridge (ADB) to test your Harmony Music app on real devices and emulators.

## 🚀 Features

### Bash Script (`adb_stress_test.sh`)
- **Device Health Monitoring**: Memory, CPU, and battery usage tracking
- **UI Stress Testing**: Automated monkey testing with configurable events
- **Audio Playback Testing**: Media control stress testing
- **Background/Foreground Transitions**: App lifecycle testing
- **Network Condition Testing**: WiFi/mobile data switching scenarios
- **Comprehensive Logging**: Detailed logs and diagnostic reports

### Python Script (`adb_stress_test.py`)
- **Real-time Monitoring**: Live performance data collection
- **Advanced Analytics**: Memory leak detection and performance analysis
- **Visual Reports**: HTML reports with charts and recommendations
- **Crash Detection**: Automatic crash and ANR monitoring
- **Data Export**: JSON data export for further analysis

## 📋 Prerequisites

1. **Android SDK Platform Tools** installed and in PATH
2. **ADB access** to your device/emulator
3. **Developer options** and **USB debugging** enabled on device
4. **Python 3.6+** (for Python script)
5. **Optional**: matplotlib and pandas for visual charts (`pip install matplotlib pandas`)

## 🔧 Setup

1. **Update Package Name**: Edit the package name in the scripts to match your app:
   ```bash
   # Default package name - update this!
   APP_PACKAGE="com.ryanheise.audioserviceexample"
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x adb_stress_test.sh
   chmod +x adb_stress_test.py
   ```

3. **Connect your device**:
   ```bash
   adb devices
   ```

## 🎯 Usage

### Bash Script (Recommended for Quick Tests)

```bash
# Basic usage
./adb_stress_test.sh

# Custom package and duration
./adb_stress_test.sh -p com.yourapp.harmony -t 600

# Specific device with verbose output
./adb_stress_test.sh -d emulator-5554 -v

# Full options
./adb_stress_test.sh -p com.yourapp.harmony -d emulator-5554 -t 300 -e 5000 -v
```

**Options:**
- `-p, --package`: App package name
- `-d, --device`: Specific device ID
- `-t, --time`: Test duration in seconds (default: 300)
- `-e, --events`: Number of monkey events (default: 10000)
- `-v, --verbose`: Enable verbose output
- `-h, --help`: Show help message

### Python Script (Advanced Analytics)

```bash
# Basic usage
python3 adb_stress_test.py

# Custom configuration
python3 adb_stress_test.py -p com.yourapp.harmony -t 600 -d emulator-5554

# With verbose output
python3 adb_stress_test.py -v
```

**Options:**
- `-p, --package`: App package name
- `-d, --device`: Device ID
- `-t, --time`: Test duration in seconds (default: 300)
- `-v, --verbose`: Enable verbose output

## 📊 Test Categories

### 1. Device and App Health Check
- ✅ Device connection verification
- ✅ App installation check
- ✅ Device information collection
- ✅ Initial memory and CPU baseline

### 2. Memory and Performance Monitoring
- 📈 Real-time memory usage tracking
- 📈 CPU utilization monitoring
- 📈 Battery drain analysis
- 🔍 Memory leak detection

### 3. UI Interaction Stress Testing
- 🐒 Monkey testing with configurable events
- 👆 Touch, motion, and navigation events
- 🔄 App switching and system interactions
- ⚡ High-frequency interaction simulation

### 4. Audio Playback Stress Testing
- ▶️ Play/pause rapid cycling
- ⏭️ Next/previous track testing
- 🔊 Volume control stress testing
- 🎵 Media key simulation

### 5. Background/Foreground Transition Testing
- 🏠 Home button press simulation
- 🔄 App restoration testing
- 📱 Multi-tasking scenario testing
- ⏱️ App lifecycle verification

### 6. Network and Storage Stress Testing
- 📶 WiFi/mobile data switching
- 🔌 Network disconnection scenarios
- 💾 Storage access patterns
- 🌐 Network condition variations

### 7. Battery and Power Management Testing
- 🔋 Battery drain monitoring
- 🌡️ Temperature tracking
- ⚡ Power state analysis

## 📁 Output Files

All test results are saved in the `adb_stress_logs/` directory:

### Bash Script Output:
- `stress_test_YYYYMMDD_HHMMSS.log` - Main test log
- `performance_YYYYMMDD_HHMMSS.log` - CPU performance data
- `memory_YYYYMMDD_HHMMSS.log` - Memory usage data
- `test_summary.txt` - Test summary and recommendations

### Python Script Output:
- `advanced_stress_test_YYYYMMDD_HHMMSS.json` - Raw data (JSON)
- `stress_report_YYYYMMDD_HHMMSS.html` - Comprehensive HTML report

## 🔍 Analyzing Results

### Memory Analysis
- **Average Memory Usage**: Should remain stable during testing
- **Memory Growth**: Look for continuous upward trends (potential leaks)
- **Peak Memory**: Ensure it stays within reasonable limits

### CPU Analysis
- **Average CPU**: Should be reasonable for audio apps (< 30% typically)
- **Peak CPU**: Brief spikes are normal, sustained high usage needs investigation
- **CPU Patterns**: Look for unusual spikes or continuous high usage

### Battery Analysis
- **Drain Rate**: Compare with other audio apps
- **Temperature**: Monitor for overheating
- **Power Efficiency**: Analyze power consumption patterns

### Crash Analysis
- **ANR Detection**: Application Not Responding events
- **Exception Logs**: Java/native crashes
- **System Errors**: Low-level system issues

## ⚠️ Troubleshooting

### Common Issues:

1. **"No devices connected"**
   ```bash
   # Check device connection
   adb devices
   
   # Restart ADB server
   adb kill-server && adb start-server
   ```

2. **"App not found"**
   ```bash
   # List installed packages
   adb shell pm list packages | grep -i harmony
   
   # Get exact package name
   adb shell pm list packages | grep audio
   ```

3. **Permission denied**
   ```bash
   # Check USB debugging is enabled
   # Check device authorization
   adb devices  # Should show 'device', not 'unauthorized'
   ```

4. **"ADB not found"**
   ```bash
   # Install Android SDK Platform Tools
   # Add to PATH environment variable
   export PATH=$PATH:/path/to/android-sdk/platform-tools
   ```

## 📈 Performance Benchmarks

### Typical Results for Music Apps:
- **Memory Usage**: 50-150MB for audio streaming apps
- **CPU Usage**: 5-25% during playback, spikes during track changes
- **Battery Drain**: 2-8% per hour depending on usage
- **Crash Rate**: < 1% for stable apps

### Red Flags:
- 🚨 Memory usage growing continuously (>50MB growth in 5 minutes)
- 🚨 CPU usage consistently > 80%
- 🚨 Battery drain > 15% per hour
- 🚨 Any crashes or ANRs during normal operation

## 🔧 Customization

### Adding Custom Tests:
1. **Modify the bash script**: Add new functions for specific test scenarios
2. **Extend the Python script**: Add new monitoring or analysis functions
3. **Configure test parameters**: Adjust timing, event counts, etc.

### Example Custom Test:
```bash
# Add to adb_stress_test.sh
custom_audio_test() {
    print_status "Running custom audio test..."
    
    # Your custom test logic here
    for i in {1..100}; do
        adb_exec "shell input keyevent KEYCODE_MEDIA_PLAY_PAUSE"
        sleep 0.5
    done
    
    print_success "Custom audio test completed"
}
```

## 📚 Additional Resources

- [Android Debug Bridge (ADB) Documentation](https://developer.android.com/studio/command-line/adb)
- [UI/Application Exerciser Monkey](https://developer.android.com/studio/test/monkey)
- [Android Performance Monitoring](https://developer.android.com/topic/performance)
- [Memory Management Best Practices](https://developer.android.com/topic/performance/memory)

## 🤝 Contributing

Feel free to extend these scripts with additional test scenarios:
- Custom gesture patterns
- Specific audio format testing
- Integration with CI/CD pipelines
- Performance regression testing

## 📄 License

This stress testing suite is part of the Harmony Music App project and follows the same license terms.

---

**Happy Testing! 🎵**

Remember: Stress testing helps identify issues before your users do. Run these tests regularly, especially before releases!