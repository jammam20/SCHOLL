import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

/// A parent's own location picker for proposing a pickup/drop-off location
/// (Feature: Parent can add child location) — tap the map or use the
/// device's current location, then confirm. Deliberately simpler than the
/// admin app's picker (no address search): a parent's pick is only ever a
/// *proposal* the school still reviews, so the bar for getting it exactly
/// right on the first try is lower than for the location an admin sets
/// directly. Returns the picked [LatLng] via [Navigator.pop], or `null`.
class ChildLocationPickerPage extends StatefulWidget {
  const ChildLocationPickerPage({
    super.key,
    required this.studentName,
    this.initialPosition,
  });

  final String studentName;
  final LatLng? initialPosition;

  @override
  State<ChildLocationPickerPage> createState() =>
      _ChildLocationPickerPageState();
}

class _ChildLocationPickerPageState extends State<ChildLocationPickerPage> {
  static const _fallbackCenter = LatLng(30.0444, 31.2357);

  late LatLng? _picked = widget.initialPosition;
  GoogleMapController? _mapController;
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              const S(
                'Location permission is needed to use your current '
                    'location.',
                'محتاجين إذن الموقع عشان نستخدم موقعك الحالي.',
              ).of(context),
            ),
          ),
        );
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              const S(
                'Turn on location services and try again.',
                'شغّل خدمة الموقع وجرب تاني.',
              ).of(context),
            ),
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final here = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _picked = here);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(here, 16));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            const S(
              "Couldn't get your current location.",
              'معرفناش نجيب موقعك الحالي.',
            ).of(context),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          S(
            'New location for ${widget.studentName}',
            'موقع جديد لـ ${widget.studentName}',
          ).of(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
            child: Center(
              child: AppButton.primary(
                label: const S('Submit', 'إرسال').of(context),
                onPressed: _picked == null
                    ? null
                    : () => Navigator.pop(context, _picked),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
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
          PositionedDirectional(
            end: AppSpacing.lg,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'child-location-picker-my-location',
              tooltip: const S('My location', 'موقعي').of(context),
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          PositionedDirectional(
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.level1(colors.textPrimary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _picked == null ? Icons.touch_app_outlined : Icons.location_on,
                    size: 20,
                    color: _picked == null ? colors.textSecondary : colors.info,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      const S(
                        'Use your location or tap the map, then submit — '
                            'your school reviews it before it becomes '
                            'official.',
                        'استخدم موقعك أو دوس على الخريطة، بعدين ابعت — '
                            'مدرستك بتراجعها قبل ما تبقى رسمية.',
                      ).of(context),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
