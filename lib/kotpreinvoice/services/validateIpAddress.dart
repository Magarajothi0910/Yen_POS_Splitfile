// ignore: file_names
bool validateIpAddress(String ip) {
  final RegExp ipRegex = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$',
  );
  return ipRegex.hasMatch(ip);
}
