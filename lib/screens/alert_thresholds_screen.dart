import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/threshold_provider.dart'; // Corrected import path
import '../widgets/common_background.dart'; // Import

class AlertThresholdScreen extends StatefulWidget {
  const AlertThresholdScreen({super.key});

  @override
  State<AlertThresholdScreen> createState() => _AlertThresholdScreenState();
}

class _AlertThresholdScreenState extends State<AlertThresholdScreen> {
  final _formKey = GlobalKey<FormState>();

  // Normal threshold controllers
  final _gasController = TextEditingController();
  final _tempController = TextEditingController();
  final _soundController = TextEditingController();

  // Warning threshold controllers
  final _gasWarningController = TextEditingController();
  final _tempWarningController = TextEditingController();
  final _soundWarningController = TextEditingController();

  // Danger threshold controllers
  final _gasDangerController = TextEditingController();
  final _tempDangerController = TextEditingController();
  final _soundDangerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load thresholds when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ThresholdProvider>(context, listen: false).loadThresholds();
    });
  }

  @override
  void dispose() {
    // Dispose normal controllers
    _gasController.dispose();
    _tempController.dispose();
    _soundController.dispose();

    // Dispose warning controllers
    _gasWarningController.dispose();
    _tempWarningController.dispose();
    _soundWarningController.dispose();

    // Dispose danger controllers
    _gasDangerController.dispose();
    _tempDangerController.dispose();
    _soundDangerController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get provider instance here to use in actions
    final thresholdProvider =
        Provider.of<ThresholdProvider>(context, listen: false);

    return Scaffold(
      body: CommonBackground(
        child: Column(
          children: [
            // Header Replacement with Refresh Action
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Stack(
                  // Use Stack to overlay IconButton
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 0,
                      left: 0,
                      child: SafeArea(
                        child: BackButton(color: Color(0xFFE07A5F)),
                      ),
                    ),
                    // Centered Title
                    const Center(
                      child: Text(
                        'Alert Thresholds',
                        style: TextStyle(
                            color: Color(0xFFE07A5F),
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Refresh Button
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon:
                            const Icon(Icons.refresh, color: Color(0xFFE07A5F)),
                        onPressed: () => thresholdProvider.loadThresholds(),
                        tooltip: 'Refresh Thresholds',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Consumer<ThresholdProvider>(
                builder: (context, provider, child) {
                  // Update text controllers when thresholds are loaded
                  if (!provider.isLoading && provider.error == null) {
                    // Update normal controllers
                    _gasController.text = provider.gasThreshold.toString();
                    _tempController.text = provider.tempThreshold.toString();
                    _soundController.text = provider.soundThreshold.toString();

                    // Update warning controllers
                    _gasWarningController.text =
                        provider.gasWarningThreshold.toString();
                    _tempWarningController.text =
                        provider.tempWarningThreshold.toString();
                    _soundWarningController.text =
                        provider.soundWarningThreshold.toString();

                    // Update danger controllers
                    _gasDangerController.text =
                        provider.gasDangerThreshold.toString();
                    _tempDangerController.text =
                        provider.tempDangerThreshold.toString();
                    _soundDangerController.text =
                        provider.soundDangerThreshold.toString();
                  }

                  if (provider.isLoading && _gasController.text.isEmpty) {
                    // Show indicator only on initial load
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            provider.error!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () => provider.loadThresholds(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configure Alert Thresholds',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set threshold values for normal, warning, and danger levels',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Gas thresholds section
                            _buildThresholdSection(
                              title: 'Gas Thresholds (MQ-7)',
                              normalController: _gasController,
                              warningController: _gasWarningController,
                              dangerController: _gasDangerController,
                            ),

                            const SizedBox(height: 16),

                            // Temperature thresholds section
                            _buildThresholdSection(
                              title: 'Temperature Thresholds (°C)',
                              normalController: _tempController,
                              warningController: _tempWarningController,
                              dangerController: _tempDangerController,
                            ),

                            const SizedBox(height: 16),

                            // Sound thresholds section
                            _buildThresholdSection(
                              title: 'Sound Thresholds (dB)',
                              normalController: _soundController,
                              warningController: _soundWarningController,
                              dangerController: _soundDangerController,
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed:
                                    provider.isLoading ? null : _saveThresholds,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9800),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: provider.isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'Save Thresholds',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build threshold sections
  Widget _buildThresholdSection({
    required String title,
    required TextEditingController normalController,
    required TextEditingController warningController,
    required TextEditingController dangerController,
  }) {
    return Card(
      color: const Color(0xFF1565C0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Normal threshold
            _buildInputField(
              controller: normalController,
              label: 'Normal Threshold',
              color: Colors.green,
              hint: 'Enter normal threshold value',
            ),
            const SizedBox(height: 12),

            // Warning threshold
            _buildInputField(
              controller: warningController,
              label: 'Warning Threshold',
              color: Colors.orange,
              hint: 'Enter warning threshold value',
            ),
            const SizedBox(height: 12),

            // Danger threshold
            _buildInputField(
              controller: dangerController,
              label: 'Danger Threshold',
              color: Colors.red,
              hint: 'Enter danger threshold value',
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build input fields
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required Color color,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 12, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withAlpha(26),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withAlpha(128)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a value';
            }
            if (double.tryParse(value) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
        ),
      ],
    );
  }

  void _saveThresholds() {
    if (_formKey.currentState!.validate()) {
      // Parse all values for validation
      final double gasNormal = double.parse(_gasController.text);
      final double gasWarning = double.parse(_gasWarningController.text);
      final double gasDanger = double.parse(_gasDangerController.text);

      final double tempNormal = double.parse(_tempController.text);
      final double tempWarning = double.parse(_tempWarningController.text);
      final double tempDanger = double.parse(_tempDangerController.text);

      final double soundNormal = double.parse(_soundController.text);
      final double soundWarning = double.parse(_soundWarningController.text);
      final double soundDanger = double.parse(_soundDangerController.text);

      // Validate threshold relationships (normal < warning < dangerous)
      String? validationError;

      if (gasNormal >= gasWarning || gasWarning >= gasDanger) {
        validationError =
            'Gas thresholds must follow: normal < warning < dangerous';
      } else if (tempNormal >= tempWarning || tempWarning >= tempDanger) {
        validationError =
            'Temperature thresholds must follow: normal < warning < dangerous';
      } else if (soundNormal >= soundWarning || soundWarning >= soundDanger) {
        validationError =
            'Sound thresholds must follow: normal < warning < dangerous';
      }

      // If validation error, show it and stop
      if (validationError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final provider = Provider.of<ThresholdProvider>(context, listen: false);
      // Store the context in a local variable to avoid using context across async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      provider
          .saveThresholds(
        // Normal thresholds
        gasThreshold: gasNormal,
        tempThreshold: tempNormal,
        soundThreshold: soundNormal,
        // Warning thresholds
        gasWarningThreshold: gasWarning,
        tempWarningThreshold: tempWarning,
        soundWarningThreshold: soundWarning,
        // Danger thresholds
        gasDangerThreshold: gasDanger,
        tempDangerThreshold: tempDanger,
        soundDangerThreshold: soundDanger,
      )
          .then((_) {
        if (provider.error == null) {
          // Show different messages based on verification status
          if (provider.verified) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Thresholds updated and verified successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            // Show warning if thresholds were saved but verification failed
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text(
                    'Thresholds updated but verification failed - please refresh'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          // Show error message
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error: ${provider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }
}
