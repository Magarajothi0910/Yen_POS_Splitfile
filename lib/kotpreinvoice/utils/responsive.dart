import 'package:flutter/material.dart';

enum DeviceType { phone, tablet, desktop }

class Responsive {
  // Breakpoints for device classification
  static const double phoneBreakpoint = 600.0;
  static const double tabletBreakpoint = 900.0;

  // Determine the device type based on screen width
  static DeviceType getDeviceType(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < phoneBreakpoint) {
      return DeviceType.phone;
    } else if (screenWidth < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  // Return adaptive padding based on device type
  static EdgeInsets getPadding(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0);
      case DeviceType.tablet:
        return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
      case DeviceType.desktop:
        return const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
    }
  }

  // Return adaptive font size based on device type
  static double getFontSize(BuildContext context, {required double baseSize}) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return baseSize * 0.9;
      case DeviceType.tablet:
        return baseSize; // no scaling
      case DeviceType.desktop:
        return baseSize * 1.2;
    }
  }

  // Return adaptive scale factor for widgets based on device type
  static double getScaleFactor(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return 0.8;
      case DeviceType.tablet:
        return 1.0;
      case DeviceType.desktop:
        return 1.2;
    }
  }

  // Return adaptive dialog width based on device type
  static double getDialogWidth(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    switch (getDeviceType(context)) {
      case DeviceType.phone:
        return screenWidth * 0.9;
      case DeviceType.tablet:
        return 600.0;
      case DeviceType.desktop:
        return 800.0;
    }
  }
}
