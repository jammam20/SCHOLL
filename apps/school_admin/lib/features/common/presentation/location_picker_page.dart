import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:school_shared/school_shared.dart';

import '../data/map_geocoding_service.dart';

/// Full-screen "pick a location" picker (Feature: Map Search) — tap the map
/// directly, search an address, or use the device's current location; every
/// path ends the same way: a pin on the map the user can still drag/re-tap
/// before confirming. Returns the picked [LatLng] via [Navigator.pop], or
/// `null` if the user backs out.
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
  GoogleMapController? _mapController;

  final _searchController = TextEditingController();
  List<GeoSearchResult> _results = const [];
  bool _searching = false;
  bool _locating = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await MapGeocodingService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } on GeocodingUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
        _searchError = const S(
          "Couldn't search for that location right now.",
          'معرفناش ندور على الموقع ده دلوقتي.',
          fr: 'Impossible de rechercher ce lieu pour le moment.',
          es: 'No se pudo buscar esa ubicación en este momento.',
        ).of(context);
      });
    }
  }

  void _selectResult(GeoSearchResult result) {
    setState(() {
      _picked = result.position;
      _results = const [];
      _searchController.clear();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(result.position, 16));
  }

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
                fr: "L'autorisation de localisation est nécessaire pour "
                    'utiliser votre position actuelle.',
                es: 'Se necesita el permiso de ubicación para usar tu '
                    'ubicación actual.',
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
                fr: 'Activez les services de localisation et réessayez.',
                es: 'Activa los servicios de ubicación e inténtalo de nuevo.',
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
              fr: "Impossible d'obtenir votre position actuelle.",
              es: 'No se pudo obtener tu ubicación actual.',
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.lg),
            child: Center(
              child: AppButton.primary(
                label: const S(
                  'Save',
                  'حفظ',
                  fr: 'Enregistrer',
                  es: 'Guardar',
                ).of(context),
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
            onTap: (position) => setState(() {
              _picked = position;
              _results = const [];
            }),
            markers: {
              if (_picked != null)
                Marker(markerId: const MarkerId('picked'), position: _picked!),
            },
          ),
          // Feature: Map Search — an address search box that overlays the
          // map, with its results dropped directly beneath it.
          PositionedDirectional(
            start: AppSpacing.lg,
            end: AppSpacing.lg,
            top: AppSpacing.lg,
            child: Column(
              children: [
                Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  color: colors.surface,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _search,
                    decoration: InputDecoration(
                      hintText: const S(
                        'Search for a location',
                        'دور على موقع',
                        fr: 'Rechercher un lieu',
                        es: 'Buscar una ubicación',
                      ).of(context),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _results = const []);
                              },
                            ),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_searchError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.level1(colors.textPrimary),
                    ),
                    child: Text(
                      _searchError!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.textMuted),
                    ),
                  )
                else if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: AppSpacing.xs),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.level1(colors.textPrimary),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final result = _results[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            result.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          PositionedDirectional(
            end: AppSpacing.lg,
            bottom: 96,
            child: FloatingActionButton.small(
              heroTag: 'location-picker-my-location',
              tooltip: const S(
                'My location',
                'موقعي',
                fr: 'Ma position',
                es: 'Mi ubicación',
              ).of(context),
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
                    child: _picked == null
                        ? Text(
                            const S(
                              'Search, use your location, or tap the map to '
                                  'drop a pin.',
                              'دور، استخدم موقعك، أو دوس على الخريطة عشان '
                                  'تحط دبوس.',
                              fr: 'Recherchez, utilisez votre position, ou '
                                  'touchez la carte pour placer un repère.',
                              es: 'Busca, usa tu ubicación o toca el mapa '
                                  'para colocar un marcador.',
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
