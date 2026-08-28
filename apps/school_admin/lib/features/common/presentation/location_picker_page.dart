import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Full-screen "tap the map to place a pin" picker. Returns the picked
/// [LatLng] via [Navigator.pop], or `null` if the user backs out.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initialPosition, required this.title});

  final LatLng? initialPosition;
  final String title;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  // Cairo, as a reasonable default center when nothing's been picked yet.
  static const _fallbackCenter = LatLng(30.0444, 31.2357);

  late LatLng? _picked = widget.initialPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
            child: const Text('Save'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition ?? _fallbackCenter,
              zoom: widget.initialPosition == null ? 11 : 16,
            ),
            onTap: (position) => setState(() => _picked = position),
            markers: {
              if (_picked != null)
                Marker(markerId: const MarkerId('picked'), position: _picked!),
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _picked == null
                      ? 'Tap anywhere on the map to drop a pin.'
                      : 'Lat ${_picked!.latitude.toStringAsFixed(5)}, '
                            'Lng ${_picked!.longitude.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
