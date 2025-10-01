import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/palette.dart';

/// --------- Modelo dinámico ----------
class InfoItem {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String? icon; // nombre del icono (string)
  final int order;
  final bool visible;

  InfoItem({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.icon,
    required this.order,
    required this.visible,
  });

  factory InfoItem.fromDoc(Map<String, dynamic> j, String fallbackId) {
    int parseInt(dynamic v, {int d = 999}) {
      if (v is int) return v;
      return int.tryParse('$v') ?? d;
    }

    bool parseBool(dynamic v, {bool d = true}) {
      if (v is bool) return v;
      final s = v?.toString().toLowerCase();
      return s == 'true' ? true : s == 'false' ? false : d;
    }

    return InfoItem(
      id: (j['id'] ?? fallbackId).toString(),
      title: (j['title'] ?? '').toString(),
      content: (j['content'] ?? '').toString(),
      imageUrl: (j['imageUrl'] ?? '').toString().trim().isEmpty ? null : (j['imageUrl'] as String),
      icon: (j['icon'] ?? '').toString().trim().isEmpty ? null : (j['icon'] as String),
      order: parseInt(j['order']),
      visible: parseBool(j['visible']),
    );
  }
}

/// --------- Stream Firestore ----------
Stream<List<InfoItem>> watchEquipajeItems({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('equipaje_items')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => InfoItem.fromDoc(d.data(), d.id))
        .where((e) => e.visible && e.title.trim().isNotEmpty)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

/// --------- Galería: modelo + stream ----------
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

Stream<List<PhotoItem>> watchEquipajePhotos({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('equipaje_gallery')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs.map((d) {
      final j = d.data();
      return PhotoItem(
        id: d.id,
        url: (j['url'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
        order: (j['order'] is int) ? j['order'] as int : (int.tryParse('${j['order']}') ?? 999),
        visible: (j['visible'] is bool)
            ? j['visible'] as bool
            : (j['visible']?.toString().toLowerCase() == 'true'),
      );
    }).where((p) => p.url.trim().isNotEmpty && p.visible).toList();
    return items;
  });
}

/// --------- Mapeo de iconos ----------
IconData _iconFrom(String? name) {
  const fallback = Icons.folder_open;
  const map = <String, IconData>{
    'description': Icons.description,
    'checkroom': Icons.checkroom,
    'directions_walk': Icons.directions_walk,
    'soap': Icons.soap,
    'devices': Icons.devices,
    'medical_services': Icons.medical_services,
  };
  return name != null && name.isNotEmpty ? (map[name] ?? fallback) : fallback;
}

/// ========================= PAGE =========================
const double kGalleryCardHeight = 280;

class EquipajePage extends StatelessWidget {
  final String tripId;
  const EquipajePage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Equipaje',
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
            // ===== Galería arriba =====
            SliverToBoxAdapter(
              child: StreamBuilder<List<PhotoItem>>(
                stream: watchEquipajePhotos(tripId: tripId),
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

            // ===== Contenido de equipaje (acordeones) =====
            SliverToBoxAdapter(
              child: StreamBuilder<List<InfoItem>>(
                stream: watchEquipajeItems(tripId: tripId),
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
                      child: Center(child: Text('Sin contenidos de equipaje')),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: items.map((it) {
                            return _Accordion(
                              title: it.title,
                              body: it.content,
                              icon: _iconFrom(it.icon),
                              imageUrl: it.imageUrl,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
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

/// ===================== UI Helpers (look consistente) =====================
class _Accordion extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final String? imageUrl;

  const _Accordion({
    required this.title,
    required this.body,
    required this.icon,
    this.imageUrl,
  });

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(widget.icon, color: Palette.brown),
            title: Text(
              widget.title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Palette.brown,
              ),
            ),
            trailing: Icon(
              _open ? Icons.expand_less : Icons.expand_more,
              color: Palette.brown,
            ),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: const Color(0xFFF4F4F4),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, color: Colors.black45),
                          ),
                        ),
                      ),
                    ),
                  Text(
                    widget.body,
                    style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ========================= Helpers Galería ========================= */
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
