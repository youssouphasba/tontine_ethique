import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class AuditLog {
  final String id;
  final String actionType;
  final String userId;
  final DateTime timestamp;
  final String details;
  final String ipAddress;
  final String signatureHash; // Hash of the signature points

  AuditLog({
    required this.id,
    required this.actionType,
    required this.userId,
    required this.timestamp,
    required this.details,
    required this.ipAddress,
    required this.signatureHash,
  });
}

class AuditService {
  static final List<AuditLog> _logs = [];

  static Future<void> logAction({
    required String actionType,
    required String userId,
    required String details,
    String signatureHash = '',
  }) async {
    // 1. Capture Real IP via public API
    String ip = 'Unknown';
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        ip = response.body;
      }
    } catch (e) {
      ip = 'IP_ERROR_${e.toString()}';
    }

    // 2. Capture Device Info
    String deviceInfo = 'Unknown Device';
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
         final web = await deviceInfoPlugin.webBrowserInfo;
         deviceInfo = '${web.browserName} ${web.appVersion}';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfoPlugin.androidInfo;
        deviceInfo = '${android.brand} ${android.model} (SDK ${android.version.sdkInt})';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfoPlugin.iosInfo;
        deviceInfo = '${ios.name} ${ios.systemName} ${ios.systemVersion}';
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final windows = await deviceInfoPlugin.windowsInfo;
        deviceInfo = 'Windows ${windows.computerName}';
      }
    } catch (e) {
      deviceInfo = 'DEVICE_ERROR';
    }
    
    final fullDetails = "$details | Device: $deviceInfo";
    
    final log = AuditLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      actionType: actionType,
      userId: userId,
      timestamp: DateTime.now(),
      details: fullDetails,
      ipAddress: ip,
      signatureHash: signatureHash,
    );

    _logs.add(log);
    
    if (kDebugMode) {
      debugPrint('🔒 AUDIT LOG [${log.actionType}]: User $userId (IP: ${log.ipAddress}) - ${log.details}');
    }
  }

  static List<AuditLog> getLogs() => List.unmodifiable(_logs);
}
