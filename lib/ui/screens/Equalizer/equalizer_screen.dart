import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/media_kit_equalizer.dart';
import '../../../models/equalizer.dart';
import '../../widgets/cust_switch.dart';
import '../../../services/equalizer.dart';

class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final equalizer = Get.find<MediaKitEqualizer>();

    return Scaffold(
      appBar: AppBar(
        title: Text('builtInEqualizer'.tr),
        centerTitle: true,
        actions: [
          // System equalizer fallback button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'systemEqualizer'.tr,
            onPressed: () async {
              try {
                // Try to open system equalizer
                final success = EqualizerService.openSystemEqualizer(0);
                if (!success) {
                  Get.snackbar(
                    'error'.tr,
                    'systemEqualizerNotAvailable'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              } catch (e) {
                Get.snackbar(
                  'error'.tr,
                  'failedToOpenSystemEqualizer'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() => _buildEqualizerBody(context, equalizer)),
    );
  }

  Widget _buildEqualizerBody(
      BuildContext context, MediaKitEqualizer equalizer) {
    return Column(
      children: [
        // Equalizer enable/disable switch
        _buildEqualizerToggle(context, equalizer),

        // Preset selection
        _buildPresetSelection(context, equalizer),

        // Frequency bands
        Expanded(
          child: _buildFrequencyBands(context, equalizer),
        ),

        // Control buttons
        _buildControlButtons(context, equalizer),
      ],
    );
  }

  Widget _buildEqualizerToggle(
      BuildContext context, MediaKitEqualizer equalizer) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Icon(
            equalizer.enabled ? Icons.equalizer : Icons.equalizer_outlined,
            color: equalizer.enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'equalizer'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'equalizerDescription'.tr,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          CustSwitch(
            value: equalizer.enabled,
            onChanged: equalizer.setEnabled,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelection(
      BuildContext context, MediaKitEqualizer equalizer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'presets'.tr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: equalizer.presets.length,
              itemBuilder: (context, index) {
                final preset = equalizer.presets[index];
                final isSelected = preset.name == equalizer.currentPreset;

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(preset.name),
                    selected: isSelected,
                    onSelected: equalizer.enabled
                        ? (_) => equalizer.applyPreset(preset.name)
                        : null,
                    deleteIcon: preset.isCustom
                        ? const Icon(Icons.close, size: 16)
                        : null,
                    onDeleted: preset.isCustom
                        ? () => _showDeletePresetDialog(
                            context, equalizer, preset.name)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyBands(
      BuildContext context, MediaKitEqualizer equalizer) {
    if (equalizer.currentBands.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'frequencyBands'.tr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: equalizer.currentBands.asMap().entries.map((entry) {
                final index = entry.key;
                final band = entry.value;

                return _buildFrequencySlider(context, equalizer, index, band);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencySlider(BuildContext context,
      MediaKitEqualizer equalizer, int index, EqualizerBand band) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Gain value display
          Container(
            height: 32,
            alignment: Alignment.center,
            child: Text(
              '${band.gain.toStringAsFixed(1)} dB',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: band.gain != 0
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
            ),
          ),
          // Vertical slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Slider(
                value: band.gain,
                min: -15.0,
                max: 15.0,
                divisions: 30,
                onChanged: equalizer.enabled
                    ? (value) => equalizer.updateBand(index, value)
                    : null,
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
            ),
          ),
          // Frequency label
          Container(
            height: 40,
            alignment: Alignment.center,
            child: Text(
              band.label,
              style: Theme.of(context).textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(
      BuildContext context, MediaKitEqualizer equalizer) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Reset button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: equalizer.enabled ? equalizer.resetToFlat : null,
              icon: const Icon(Icons.refresh),
              label: Text('reset'.tr),
            ),
          ),
          const SizedBox(width: 12),
          // Save preset button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: equalizer.enabled
                  ? () => _showSavePresetDialog(context, equalizer)
                  : null,
              icon: const Icon(Icons.save),
              label: Text('savePreset'.tr),
            ),
          ),
        ],
      ),
    );
  }

  void _showSavePresetDialog(
      BuildContext context, MediaKitEqualizer equalizer) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('savePreset'.tr),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'presetName'.tr,
            hintText: 'enterPresetName'.tr,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                equalizer.saveAsPreset(name);
                Navigator.pop(context);
                Get.snackbar(
                  'success'.tr,
                  'presetSaved'.tr.replaceAll('%s', name),
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(
      BuildContext context, MediaKitEqualizer equalizer, String presetName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('deletePreset'.tr),
        content: Text('deletePresetConfirm'.tr.replaceAll('%s', presetName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              equalizer.deletePreset(presetName);
              Navigator.pop(context);
              Get.snackbar(
                'success'.tr,
                'presetDeleted'.tr.replaceAll('%s', presetName),
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}
