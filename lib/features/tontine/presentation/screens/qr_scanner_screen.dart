import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tontetic/core/theme/app_theme.dart';

/// V10.1 - QR Code Scanner Screen
/// Scans QR codes to join circles instantly

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  
  bool _isTorchOn = false;
  bool _hasScanned = false;
  String? _scannedCircleId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Torch Toggle (Visual only for now, controller.toggleTorch handles the logic)
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? AppTheme.gold : Colors.white,
            ),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          // Camera Switch
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          
          // Overlay with Scanner Frame
          _buildScannerOverlay(),
          
          // Bottom Instructions
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: AppTheme.gold, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _hasScanned 
                            ? 'Cercle trouvé ! 🎉'
                            : 'Placez le QR Code dans le cadre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_scannedCircleId != null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => _joinCircle(_scannedCircleId!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.marineBlue,
                          ),
                          child: const Text('REJOINDRE CE CERCLE'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return CustomPaint(
      painter: ScannerOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return; // Prevent multiple scans
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? value = barcode.rawValue;
      if (value != null && value.contains('tontetic-app.web.app/join/')) {
        // Extract circle ID from URL
        final circleId = value.split('/').last;
        setState(() {
          _hasScanned = true;
          _scannedCircleId = circleId;
        });
        
        // Haptic feedback
        // HapticFeedback.mediumImpact();
        
        break;
      }
    }
  }

  void _joinCircle(String circleId) {
    // In production: Navigate to circle preview/join confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Demande d\'adhésion envoyée pour le cercle $circleId ! ✅'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, circleId);
  }
}

/// Custom painter for scanner overlay with rounded corners
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2.5;
    
    // Dark overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
        const Radius.circular(24),
      ))
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    
    // Corner accents
    final cornerPaint = Paint()
      ..color = AppTheme.gold
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    const cornerLength = 30.0;
    const radius = 24.0;
    
    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top + radius)
        ..arcToPoint(Offset(left + radius, top), radius: const Radius.circular(radius))
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );
    
    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top)
        ..lineTo(left + scanAreaSize - radius, top)
        ..arcToPoint(Offset(left + scanAreaSize, top + radius), radius: const Radius.circular(radius))
        ..lineTo(left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );
    
    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + scanAreaSize - cornerLength)
        ..lineTo(left, top + scanAreaSize - radius)
        ..arcToPoint(Offset(left + radius, top + scanAreaSize), radius: const Radius.circular(radius))
        ..lineTo(left + cornerLength, top + scanAreaSize),
      cornerPaint,
    );
    
    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top + scanAreaSize)
        ..lineTo(left + scanAreaSize - radius, top + scanAreaSize)
        ..arcToPoint(Offset(left + scanAreaSize, top + scanAreaSize - radius), radius: const Radius.circular(radius))
        ..lineTo(left + scanAreaSize, top + scanAreaSize - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
