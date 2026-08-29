import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

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
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
            child: Center(
              child: AppButton.primary(
                label: const S('Save', 'حفظ').of(context),
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
                    child: _picked == null
                        ? Text(
                            const S(
                              'Tap anywhere on the map to drop a pin.',
                              'دوس في أي مكان على الخريطة عشان تحط دبوس.',
                            ).of(context),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                            ),
                          )
                        : Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              'Lat ${_picked!.latitude.toStringAsFixed(5)}, '
                                  'Lng ${_picked!.longitude.toStringAsFixed(5)}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.textPrimary,
                              ),
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
