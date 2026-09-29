import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/location.dart';
import '../../ui/widgets.dart';
import '../place/place_detail.dart';
import 'report_shop_sheet.dart';

/// OSM tiles by default. For production traffic point this at your own tile
/// server or a provider: `--dart-define=TILE_URL=https://…/{z}/{x}/{y}.png`.
const tileUrl = String.fromEnvironment('TILE_URL', defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

/// Above this span the viewport would be dot-soup; we don't load places.
const _maxFetchSpanDeg = 0.5;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();
  Timer? _debounce;
  LatLngBounds? _loadedBounds;
  bool _loading = false;
  String? _error;
  bool _favoritesOnly = false;
  bool _centeredOnUser = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onCameraChanged(MapCamera camera) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _load(camera.visibleBounds));
  }

  Future<void> _load(LatLngBounds bounds, {bool force = false}) async {
    if (bounds.north - bounds.south > _maxFetchSpanDeg || bounds.east - bounds.west > _maxFetchSpanDeg) return;
    final loaded = _loadedBounds;
    if (!force && loaded != null && loaded.containsBounds(bounds)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppData>().loadArea(south: bounds.south, west: bounds.west, north: bounds.north, east: bounds.east);
      _loadedBounds = bounds;
    } on OfflineException catch (e) {
      _error = e.toString();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final location = context.watch<LocationService>();
    final userPosition = location.position;

    if (userPosition != null && !_centeredOnUser) {
      _centeredOnUser = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.move(userPosition, 15));
    }

    final visitCounts = <String, int>{};
    for (final v in data.visits) {
      visitCounts[v.dto.placeId] = (visitCounts[v.dto.placeId] ?? 0) + 1;
    }
    final places = data.places.values.where((p) => !_favoritesOnly || data.favorites.contains(p.placeId)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Döner Karte'),
        leading: IconButton(
          tooltip: 'Fehlenden Laden melden',
          icon: const Icon(Icons.add_location_alt_outlined),
          onPressed: () => showAppSheet(context, (_) => ReportShopSheet(position: _controller.camera.center)),
        ),
        actions: [
          IconButton(
            tooltip: 'Nur Favoriten',
            icon: Icon(_favoritesOnly ? Icons.favorite : Icons.favorite_border, color: _favoritesOnly ? Colors.pink : null),
            onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: userPosition ?? fallbackLocation,
              initialZoom: 14,
              onMapReady: () => _load(_controller.camera.visibleBounds),
              onPositionChanged: (camera, _) => _onCameraChanged(camera),
            ),
            children: [
              TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.robinchoice.doener'),
              MarkerLayer(
                markers: [
                  if (userPosition != null)
                    Marker(point: userPosition, width: 20, height: 20, child: const _UserDot()),
                  for (final place in places)
                    Marker(
                      point: LatLng(place.latitude, place.longitude),
                      width: 40,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => showPlaceDetail(context, place),
                        child: _DoenerPin(
                          favorite: data.favorites.contains(place.placeId),
                          visits: visitCounts[place.placeId] ?? 0,
                        ),
                      ),
                    ),
                ],
              ),
              // Bottom-left so the location button doesn't cover the required OSM credit.
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution('OpenStreetMap-Mitwirkende')],
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: places.isEmpty
                  ? const SizedBox.shrink()
                  : Pill(child: Text('${places.length} Döner in der Nähe', style: const TextStyle(fontWeight: FontWeight.w600))),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 80,
            child: Center(
              child: _loading
                  ? const Pill(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Lade Döner-Läden…'),
                      ]),
                    )
                  : _error != null
                      ? Pill(
                          onTap: () => _load(_controller.camera.visibleBounds, force: true),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                            const SizedBox(width: 6),
                            Flexible(child: Text(_error!, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            const Icon(Icons.refresh, size: 18, color: doenerOrange),
                          ]),
                        )
                      : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Mein Standort',
        onPressed: () async {
          final location = context.read<LocationService>();
          await location.request();
          final position = location.position;
          if (position != null) {
            _controller.move(position, 15);
          } else if (context.mounted) {
            showMessage(context, 'Standort nicht verfügbar');
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
      );
}

class _DoenerPin extends StatelessWidget {
  final bool favorite;
  final int visits;
  const _DoenerPin({required this.favorite, required this.visits});

  @override
  Widget build(BuildContext context) {
    final color = favorite ? Colors.pink : (visits > 0 ? Colors.green : doenerOrange);
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: const [BoxShadow(blurRadius: 3, offset: Offset(0, 2), color: Colors.black26)],
          ),
          alignment: Alignment.center,
          child: favorite
              ? Icon(Icons.favorite, size: 16, color: color)
              : visits > 0
                  ? Text('$visits', style: TextStyle(fontWeight: FontWeight.bold, color: color))
                  : Icon(Icons.restaurant, size: 16, color: color),
        ),
        CustomPaint(size: const Size(10, 6), painter: _TailPainter(color)),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  _TailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}
