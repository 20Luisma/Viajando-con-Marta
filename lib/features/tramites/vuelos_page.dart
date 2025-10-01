import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../theme/palette.dart';

/// ======== Modelos ========
class FlightLink {
  final String label;
  final String url;
  final int order;
  final bool visible;

  const FlightLink({
    required this.label,
    required this.url,
    this.order = 999,
    this.visible = true,
  });

  factory FlightLink.fromJson(Map<String, dynamic> j) => FlightLink(
    label: (j['label'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
    order: (j['order'] is int)
        ? j['order'] as int
        : (int.tryParse('${j['order']}') ?? 999),
    visible: (j['visible'] is bool)
        ? j['visible'] as bool
        : (j['visible']?.toString().toLowerCase() == 'true'),
  );
}

class FlightItem {
  final String id;
  final String title;
  final String subtitle; // opcional
  final String body; // descripción
  final String price; // libre (ej: "520 €")
  final List<String> tags;
  final List<FlightLink> links;
  final int order;
  final bool visible;

  FlightItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.price,
    required this.tags,
    required this.links,
    this.order = 999,
    this.visible = true,
  });

  factory FlightItem.fromJson(Map<String, dynamic> j, String fallbackId) {
    final tags = (j['tags'] is List)
        ? List<String>.from(
      (j['tags'] as List).map((e) => e.toString().trim()).where((e) => e.isNotEmpty),
    )
        : const <String>[];

    List<FlightLink> links = [];
    if (j['links'] is List) {
      links = List<Map<String, dynamic>>.from(j['links'])
          .map(FlightLink.fromJson)
          .where((l) => l.url.trim().isNotEmpty && l.visible)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } else {
      // Compatibilidad por si guardas solo un enlace simple en el futuro
      final u = (j['link'] ?? '').toString();
      if (u.isNotEmpty) {
        links = [FlightLink(label: 'Ver vuelo', url: u, order: 1, visible: true)];
      }
    }

    return FlightItem(
      id: (j['id'] ?? fallbackId).toString(),
      title: (j['title'] ?? '').toString(),
      subtitle: (j['subtitle'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      price: (j['price'] ?? '').toString(),
      tags: tags,
      links: links,
      order: (j['order'] is int)
          ? j['order'] as int
          : (int.tryParse('${j['order']}') ?? 999),
      visible: (j['visible'] is bool)
          ? j['visible'] as bool
          : (j['visible']?.toString().toLowerCase() == 'true'),
    );
  }
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

/// ======== Streams Firestore ========
Stream<List<PhotoItem>> _watchGallery({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('vuelos_gallery')
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
            : (int.tryParse('${j['order']}') ?? 999),
        visible: (j['visible'] is bool)
            ? j['visible'] as bool
            : (j['visible']?.toString().toLowerCase() == 'true'),
      );
    }).where((p) => p.url.trim().isNotEmpty && p.visible).toList();
    return items;
  });
}

Stream<List<FlightItem>> _watchFlights({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('vuelos_items')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => FlightItem.fromJson(d.data(), d.id))
        .where((x) => x.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

/// ======== UI Helpers (galería) ========
const double kGalleryCardHeight = 280;

Widget _emptyGalleryBox() {
  return SizedBox(
    height: kGalleryCardHeight,
    child: Container(
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
    ),
  );
}

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
      setState(() => _index = (_index + 1) % widget.photos.length);
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

/// ======== Página Vuelos ========
class VuelosPage extends StatelessWidget {
  const VuelosPage({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Vuelos',
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
            // Galería superior
            SliverToBoxAdapter(
              child: StreamBuilder<List<PhotoItem>>(
                stream: _watchGallery(tripId: tripId),
                builder: (context, snap) {
                  final photos = snap.data ?? const <PhotoItem>[];
                  if (photos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: _emptyGalleryBox(),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: _PhotoFadeShow(photos: photos),
                  );
                },
              ),
            ),

            // Lista de vuelos
            SliverToBoxAdapter(
              child: StreamBuilder<List<FlightItem>>(
                stream: _watchFlights(tripId: tripId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snap.error}'),
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Sin vuelos disponibles')),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final x = items[i];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título y precio (si existe)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      x.title,
                                      style: GoogleFonts.lora(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Palette.brown,
                                      ),
                                    ),
                                  ),
                                  if (x.price.trim().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(.05),
                                        borderRadius:
                                        BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        x.price,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (x.subtitle.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  x.subtitle,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 13.5),
                                ),
                              ],
                              if (x.body.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  x.body,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                              if (x.tags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: x.tags
                                      .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withOpacity(.06),
                                      borderRadius:
                                      BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ))
                                      .toList(),
                                ),
                              ],
                              if (x.links.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: x.links
                                      .where((l) =>
                                  l.visible && l.url.trim().isNotEmpty)
                                      .toList()
                                      .map(
                                        (l) => OutlinedButton.icon(
                                      onPressed: () =>
                                          launchUrlString(l.url),
                                      icon: const Icon(
                                          Icons.open_in_new_rounded),
                                      label: Text(
                                        l.label.isEmpty
                                            ? 'Ver vuelo'
                                            : l.label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
