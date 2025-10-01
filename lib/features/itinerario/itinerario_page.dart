import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/palette.dart';
import 'day_card.dart';

/* ========================= Firestore paths ========================= */
const String kDefaultTripId = 'kenia_oct25';
const String kDaysSubcollection   = 'itinerario_days';
const String kPhotosSubcollection = 'gallery';

/* ========================= UI Const ========================= */
const double kGalleryCardHeight = 280;

/* ========================= MODELOS ========================= */

class DayItem {
  final String id;
  final String dayLabel;
  final String date;
  final String place;
  final List<String> bullets;
  final List<String> tags;
  final String icon;
  final int order;
  final bool visible;

  DayItem({
    required this.id,
    required this.dayLabel,
    required this.date,
    required this.place,
    required this.bullets,
    required this.tags,
    required this.icon,
    required this.order,
    required this.visible,
  });

  factory DayItem.fromJson(Map<String, dynamic> j, String id) {
    final dayLabelNew = (j['dayLabel'] ?? '').toString().trim();
    final dateNew     = (j['date'] ?? '').toString().trim();
    final placeNew    = (j['place'] ?? '').toString().trim();
    final bulletsNew  = ((j['bullets'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final tagsNew     = ((j['tags'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final iconNew     = (j['icon'] ?? '').toString().trim();
    final orderNew    = (j['order'] is int)
        ? j['order'] as int
        : int.tryParse('${j['order']}');
    final visibleNew  = (j['visible'] is bool)
        ? j['visible'] as bool
        : (j['visible']?.toString().toLowerCase().trim() == 'true');

    // compat con esquema viejo
    final titleOld      = (j['title'] ?? '').toString().trim();
    final descOld       = (j['desc'] ?? '').toString().trim();
    final dayNumberOld  = (j['dayNumber'] is int)
        ? j['dayNumber'] as int
        : int.tryParse('${j['dayNumber']}') ?? _extractDayNumberFromId(id);

    final int  orderFinal   = orderNew ?? (dayNumberOld > 0 ? dayNumberOld : 999);
    final bool visibleFinal = visibleNew ?? true;

    String dayLabelFinal = dayLabelNew;
    if (dayLabelFinal.isEmpty) {
      final reg = RegExp(r'D[ií]a\s+(\d{1,2})', caseSensitive: false);
      if (reg.hasMatch(titleOld)) {
        dayLabelFinal = 'Día ${reg.firstMatch(titleOld)!.group(1)}';
      } else if (dayNumberOld > 0) {
        dayLabelFinal = 'Día $dayNumberOld';
      } else {
        dayLabelFinal = 'Día';
      }
    }

    List<String> bulletsFinal = bulletsNew;
    if (bulletsFinal.isEmpty && descOld.isNotEmpty) {
      final parts = descOld
          .split(RegExp(r'[.\n]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      bulletsFinal = parts.isEmpty ? [descOld] : parts;
    }
    if (bulletsFinal.isEmpty) bulletsFinal = const [''];

    String placeFinal = placeNew;
    if (placeFinal.isEmpty && titleOld.contains(':')) {
      final idx = titleOld.indexOf(':');
      placeFinal = titleOld.substring(idx + 1).trim();
    }

    final iconFinal = _normalizeIconName(iconNew, titleOld, placeFinal);

    return DayItem(
      id: id,
      dayLabel: dayLabelFinal,
      date: dateNew,
      place: placeFinal,
      bullets: bulletsFinal,
      tags: tagsNew,
      icon: iconFinal,
      order: orderFinal,
      visible: visibleFinal,
    );
  }
}

int _extractDayNumberFromId(String id) {
  final m = RegExp(r'(\d{1,2})').firstMatch(id);
  return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
}

class PhotoItem {
  final String id;
  final String url;
  final String caption;
  final int order;
  final bool visible;

  const PhotoItem({
    required this.id,
    required this.url,
    required this.caption,
    required this.order,
    required this.visible,
  });
}

/* ========================= DATA Streams (con tripId) ========================= */

Stream<List<DayItem>> _watchDays(String tripId) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection(kDaysSubcollection);

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => DayItem.fromJson(d.data(), d.id))
        .where((e) => e.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> _watchPhotos(String tripId) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection(kPhotosSubcollection)
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs.map((d) {
      final j = d.data();
      return PhotoItem(
        id: d.id,
        url: (j['url'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
        order: (j['order'] is int)
            ? j['order'] as int
            : int.tryParse('${j['order']}') ?? 999,
        visible: (j['visible'] is bool)
            ? j['visible'] as bool
            : (j['visible']?.toString().toLowerCase() == 'true'),
      );
    }).where((p) => p.url.trim().isNotEmpty && p.visible).toList();
    return items;
  });
}

/* ========================= ICONS ========================= */

String _normalizeIconName(String raw, String titleOld, String place) {
  String n = raw.trim().toLowerCase().replaceAll(' ', '_');

  if (n.isEmpty) {
    final t = (titleOld + ' ' + place).toLowerCase();
    if (t.contains('vuelo') || t.contains('llegada')) return 'flight_takeoff';
    if (t.contains('safari')) return 'pets';
    if (t.contains('traslado') || t.contains('ruta') || t.contains('carretera')) {
      return 'directions_bus';
    }
    return 'help_outline';
  }

  const aliases = {
    'avion': 'flight_takeoff',
    'plane': 'flight_takeoff',
    'flight': 'flight_takeoff',
    'airport': 'local_airport',
    'aeropuerto': 'local_airport',
    'bus': 'directions_bus',
    'autobus': 'directions_bus',
    'car': 'directions_car',
    'coche': 'directions_car',
    'mapa': 'map',
    'ciudad': 'location_city',
    'hotelito': 'hotel',
    'comida': 'restaurant',
    'restaurante': 'restaurant',
    'senderismo': 'hiking',
    'playa': 'beach_access',
    'evento': 'event',
    'safari': 'pets',
    'fauna': 'pets',
    'kilimanjaro': 'hiking',
    'tren': 'train',
    'barco': 'directions_boat',
    'ferry': 'directions_boat',
  };

  return aliases[n] ?? n;
}

IconData _iconFrom(String name) {
  switch (name) {
    case 'flight_takeoff':   return Icons.flight_takeoff;
    case 'local_airport':    return Icons.local_airport;
    case 'directions_bus':   return Icons.directions_bus;
    case 'directions_car':   return Icons.directions_car;
    case 'directions_boat':  return Icons.directions_boat;
    case 'pets':             return Icons.pets;
    case 'hiking':           return Icons.hiking;
    case 'map':              return Icons.map;
    case 'location_city':    return Icons.location_city;
    case 'hotel':            return Icons.hotel;
    case 'restaurant':       return Icons.restaurant;
    case 'beach_access':     return Icons.beach_access;
    case 'event':            return Icons.event;
    default:                 return Icons.help_outline;
  }
}

/* ========================= UI ========================= */

class ItinerarioPage extends StatelessWidget {
  const ItinerarioPage({super.key, this.tripId = kDefaultTripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Itinerario',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Palette.brown,
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ---------- Galería arriba ----------
            SliverToBoxAdapter(
              child: StreamBuilder<List<PhotoItem>>(
                stream: _watchPhotos(tripId),
                builder: (context, snap) {
                  final photos = snap.data ?? const <PhotoItem>[];
                  if (photos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: SizedBox(
                        height: kGalleryCardHeight,
                        child: _emptyGalleryBox(),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: _PhotoFadeShow(photos: photos),
                  );
                },
              ),
            ),

            // ---------- Lista de días ----------
            StreamBuilder<List<DayItem>>(
              stream: _watchDays(tripId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(child: Text('Error: ${snap.error}')),
                  );
                }
                if (!snap.hasData) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                final items = snap.data!;
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: Text('Sin días para mostrar')),
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final d = items[i];
                      return DayCard(
                        dayLabel: d.dayLabel,
                        date: d.date,
                        place: d.place,
                        bullets: d.bullets,
                        tags: d.tags,
                        icon: _iconFrom(d.icon),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/* ========================= Helpers UI ========================= */

Widget _emptyGalleryBox() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.black12, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: const Center(
      child: Text(
        'Sin imágenes en la galería',
        style: TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/* ========================= Fade Slideshow ========================= */

class _PhotoFadeShow extends StatefulWidget {
  final List<PhotoItem> photos;
  const _PhotoFadeShow({required this.photos});

  @override
  State<_PhotoFadeShow> createState() => _PhotoFadeShowState();
}

class _PhotoFadeShowState extends State<_PhotoFadeShow> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  @override
  void didUpdateWidget(covariant _PhotoFadeShow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos.length != widget.photos.length) {
      _index = 0;
      _startAutoplay();
    }
  }

  void _startAutoplay() {
    _timer?.cancel();
    if (widget.photos.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % widget.photos.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.photos;

    return SizedBox(
      height: kGalleryCardHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: List.generate(items.length, (i) {
            final p = items[i];
            return AnimatedOpacity(
              opacity: i == _index ? 1.0 : 0.0,
              duration: const Duration(seconds: 1),
              curve: Curves.easeInOut,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: p.url,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFFF4F4F4),
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF4F4F4),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image,
                          size: 36, color: Colors.black45),
                    ),
                  ),
                  if (p.caption.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          p.caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
