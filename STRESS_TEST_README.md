# 🎵 Harmony Music App - Comprehensive Stress Test Suite

This stress test suite is designed to thoroughly test the Harmony Music app under extreme conditions, ensuring stability, performance, and reliability across all components.

## 🎯 Test Suite Overview

The stress test suite consists of four main test files and a comprehensive test runner:

### 1. **Main Stress Test Suite** (`test/stress_test_suite.dart`)
- **Audio Handler Stress Tests**: Rapid play/pause operations, queue management, seek operations
- **Key Detection Service Tests**: Mass key detection, memory leak detection
- **UI Controller Tests**: Player controller state management, settings rapid changes
- **Data Management Tests**: Concurrent database operations, serialization performance
- **Network Stress Tests**: Simulated concurrent requests
- **Edge Case Tests**: Invalid data handling, extreme queue sizes
- **Integration Tests**: Full app simulation with random operations

### 2. **Audio Performance Benchmark** (`test/audio_performance_benchmark.dart`)
- **Key Detection Performance**: Tests across different sample rates and audio types
- **AudioFlux vs Built-in Comparison**: Performance comparison between detection methods
- **Memory Usage Analysis**: Memory leak detection during audio processing
- **Concurrent Processing**: Multiple simultaneous key detection operations
- **Edge Case Performance**: Very short and very long audio processing

### 3. **UI Stress Test** (`test/ui_stress_test.dart`)
- **Player Interface**: Rapid button presses, slider operations, simultaneous gestures
- **Home Screen**: Tab switching, content scrolling under load
- **Settings Screen**: Rapid toggle operations
- **Memory/Performance**: Widget rebuild stress, animation stress
- **Error Recovery**: Exception handling during rapid operations

### 4. **Test Runner** (`test/stress_test_runner.dart`)
- Automated execution of all stress tests
- Performance monitoring and reporting
- HTML report generation with detailed metrics
- Command-line interface with various options

## 🚀 Quick Start

### Running All Stress Tests

```bash
# Run all stress tests with verbose output and generate HTML report
dart test/stress_test_runner.dart --verbose

# Run tests quietly (errors only)
dart test/stress_test_runner.dart

# Run without generating HTML report
dart test/stress_test_runner.dart --no-report
```

### Running Individual Test Suites

```bash
# Run specific test suite
dart test/stress_test_runner.dart stress_test_suite
dart test/stress_test_runner.dart audio_performance
dart test/stress_test_runner.dart ui_stress

# Run tests directly with Flutter
flutter test test/stress_test_suite.dart
flutter test test/audio_performance_benchmark.dart
flutter test test/ui_stress_test.dart
```

## 📊 Understanding Test Results

### Test Status Indicators
- ✅ **PASSED**: Test completed successfully within expected parameters
- ❌ **FAILED**: Test failed due to errors, timeouts, or performance issues
- ⚠️ **WARNING**: Test passed but with performance concerns

### Key Metrics to Monitor

#### Audio Performance Metrics
- **Average Processing Time**: Should be < 5000ms for key detection
- **Success Rate**: Should be > 80% for valid audio data
- **95th Percentile Time**: Should be < 10000ms
- **Memory Usage**: Should not increase > 50MB during processing

#### UI Performance Metrics
- **Response Time**: UI operations should complete < 100ms
- **Frame Rate**: Should maintain 60fps during stress operations
- **Memory Leaks**: No continuous memory growth during UI stress

#### Data Management Metrics
- **Database Operations**: Concurrent operations should complete < 1000ms
- **Serialization Speed**: Media item processing should handle 1000+ items/second
- **Cache Performance**: File operations should complete < 500ms

## 🔧 Configuration

### Stress Test Configuration
Edit the configuration constants in each test file:

```dart
// In stress_test_suite.dart
class StressTestConfig {
  static const int maxConcurrentOperations = 50;
  static const int maxQueueSize = 1000;
  static const int rapidActionCount = 100;
  static const int memoryLeakTestCycles = 50;
}

// In audio_performance_benchmark.dart
class AudioPerformanceBenchmark {
  static const int benchmarkRuns = 50;
  static const List<int> testSampleRates = [22050, 44100, 48000];
  static const List<int> testDurations = [30, 60, 120]; // seconds
}

// In ui_stress_test.dart
class UIStressTestConfig {
  static const int rapidTapCount = 200;
  static const int dragOperations = 50;
  static const Duration testTimeout = Duration(minutes: 5);
}
```

### AudioFlux Configuration
Ensure AudioFlux service is properly configured:

```dart
// The toggle should now show "Use Audio Flux Key Detection"
// This was updated in the localization files
```

## 📈 Performance Benchmarks

### Expected Performance Baselines

#### Audio Processing
| Test Type | Sample Rate | Duration | Expected Avg Time | Max Acceptable |
|-----------|-------------|----------|-------------------|----------------|
| Key Detection | 44.1kHz | 60s | < 2000ms | < 5000ms |
| Key Detection | 48kHz | 120s | < 3000ms | < 8000ms |
| AudioFlux Processing | 44.1kHz | 60s | < 1500ms | < 4000ms |

#### UI Responsiveness
| Operation | Target | Max Acceptable |
|-----------|--------|----------------|
| Button Tap Response | < 50ms | < 100ms |
| Slider Drag | < 30ms | < 80ms |
| Tab Switch | < 100ms | < 200ms |
| Settings Toggle | < 20ms | < 50ms |

#### Memory Usage
| Component | Baseline | Max Increase | Action Threshold |
|-----------|----------|--------------|------------------|
| Key Detection | 10MB | +20MB | +50MB |
| UI Operations | 15MB | +10MB | +30MB |
| Audio Playback | 25MB | +15MB | +40MB |

## 🐛 Troubleshooting

### Common Issues

#### 1. AudioFlux Library Not Found
```
Error: AudioFlux library not available
```
**Solution**: Ensure the AudioFlux native library is properly built and placed in the correct directory.

#### 2. Hive Database Errors
```
Error: Box is already open
```
**Solution**: Make sure previous test runs have properly closed all Hive boxes.

#### 3. Memory Errors During Testing
```
Error: Out of memory
```
**Solution**: Reduce test parameters in configuration files or run tests individually.

#### 4. UI Test Failures
```
Error: Widget not found
```
**Solution**: Ensure the app's UI structure matches the test expectations.

### Debug Mode
Enable debug output for detailed test information:

```bash
# Run with maximum verbosity
dart test/stress_test_runner.dart --verbose

# Run individual tests with detailed output
flutter test test/stress_test_suite.dart --reporter=expanded
```

## 📝 Interpreting HTML Reports

The generated HTML report (`stress_test_report.html`) includes:

### Summary Section
- **Total Tests**: Number of test cases executed
- **Pass/Fail Counts**: Success rate overview
- **Total Time**: Complete test suite execution time

### Performance Analysis
- **Average Duration**: Mean execution time across all tests
- **Performance Distribution**: Min, max, median, and percentile data
- **Slowest/Fastest Tests**: Performance outliers

### Detailed Results
- Individual test results with timing information
- Error details for failed tests
- Performance trends and recommendations

## 🔄 Continuous Integration

### Adding to CI/CD Pipeline

```yaml
# .github/workflows/stress-tests.yml
name: Stress Tests
on: [push, pull_request]

jobs:
  stress-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart test/stress_test_runner.dart --no-report
      - uses: actions/upload-artifact@v2
        if: failure()
        with:
          name: test-results
          path: stress_test_report.html
```

### Performance Regression Detection
Set up automated alerts when performance degrades beyond acceptable thresholds:

```bash
# Example: Check if average key detection time exceeds 3 seconds
if [ "$(grep 'avgTime.*ms' stress_test_report.html | sed 's/.*>\([0-9]*\).*/\1/')" -gt 3000 ]; then
  echo "Performance regression detected!"
  exit 1
fi
```

## 🎯 Best Practices

### Before Running Stress Tests
1. **Close Other Apps**: Ensure system resources are available
2. **Use Release Mode**: Test performance in release builds when possible
3. **Stable Environment**: Run tests in consistent hardware/software environment
4. **Baseline Measurements**: Establish performance baselines for comparison

### During Development
1. **Regular Testing**: Run stress tests after major changes
2. **Performance Monitoring**: Watch for gradual performance degradation
3. **Memory Profiling**: Use additional tools for detailed memory analysis
4. **Error Analysis**: Investigate all test failures thoroughly

### Test Maintenance
1. **Update Baselines**: Adjust expected performance as the app evolves
2. **Add New Tests**: Cover new features with appropriate stress tests
3. **Review Configuration**: Periodically review test parameters for relevance
4. **Documentation**: Keep test documentation updated with app changes

## 🤝 Contributing

### Adding New Stress Tests
1. Create test file in `test/` directory
2. Follow existing naming convention: `*_stress_test.dart`
3. Add file to `_testFiles` list in `stress_test_runner.dart`
4. Update this README with new test descriptions

### Reporting Issues
When reporting stress test failures:
1. Include the full HTML report
2. Specify the exact environment (OS, Flutter version, device)
3. Provide steps to reproduce the issue
4. Include any relevant logs or error messages

---

## 📚 Additional Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Dart Testing Best Practices](https://dart.dev/guides/testing)
- [AudioFlux Documentation](https://github.com/libAudioFlux/audioFlux)
- [Performance Profiling Guide](https://flutter.dev/docs/perf/rendering/ui-performance)

---

**Happy Stress Testing! 🎵**