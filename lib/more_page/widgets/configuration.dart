import 'package:flutter/material.dart';
import 'package:yen_pos/Global/Widget/custom_sized_box.dart';
import 'package:yen_pos/more_page/configurations/weigheing_scale_configration.dart';
import 'package:yen_pos/printer_screen/kotPrint.dart';
import 'package:yen_pos/printer_screen/printer_config.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  String configurationView = 'Printer Configuration';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomSizedBox(height: 12),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildConfigurationButton(
                icon: Icons.print,
                label: 'Printer Configuration',
                isSelected: configurationView == 'Printer Configuration',
                onPressed: () =>
                    setState(() => configurationView = 'Printer Configuration'),
              ),
              const SizedBox(width: 16),
              _buildConfigurationButton(
                icon: Icons.scale,
                label: 'Weight Scale Configuration',
                isSelected: configurationView == 'Weight Scale Configuration',
                onPressed: () => setState(
                  () => configurationView = 'Weight Scale Configuration',
                ),
              ),
              _buildConfigurationButton(
                icon: Icons.scale,
                label: 'KOT Printer Configuration',
                isSelected: configurationView == 'KOT Printer Configuration',
                onPressed: () => setState(
                  () => configurationView = 'KOT Printer Configuration',
                ),
              ),
            ],
          ),
        ),
        const Divider(thickness: 0.5),
        Expanded(
          child: Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (configurationView == 'Printer Configuration')
                  Expanded(child: PrinterSettingsScreen()),
                if (configurationView == 'Weight Scale Configuration')
                  const Expanded(child: ConnectWeighingScale()),
                if (configurationView == 'KOT Printer Configuration')
                  Expanded(child: KOTPrinterSettingsScreen()),
                // Expanded(child: ConnectWeighingScale()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isSelected,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isSelected ? Colors.blue[600] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
