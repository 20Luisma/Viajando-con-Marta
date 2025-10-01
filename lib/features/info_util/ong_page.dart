import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/palette.dart';

/// ---------------------- Modelo dinámico (ONG) ----------------------
class OngItem {
  final String id;
  final String title;
  final String body;
  final String? icon; // nombre del icono (string, controlado desde el panel)
  final int order;
  final bool visible;

  OngItem({
    required this.id,
    required this.title,
    required this.body,
    this.icon,
    this.order = 999,
    this.visible = true,
  });

  factory OngItem.fromJson(Map<String, dynamic> j, {required String fallbackId}) => OngItem(
    id: (j['id'] ?? fallbackId).toString(),
    title: (j['title'] ?? '').toString(),
    body: (j['body'] ?? '').toString(),
    icon: (j['icon']?.toString().isEmpty ?? true) ? null : j['icon'].toString(),
    order: (j['order'] is int) ? j['order'] as int : (int.tryParse('${j['order']}') ?? 999),
    visible: (j['visible'] is bool) ? j['visible'] as bool : (j['visible']?.toString().toLowerCase() == 'true'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'icon': icon,
    'order': order,
    'visible': visible,
  };
}

/// ---------------------- Modelo foto galería ----------------------
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

/// ------------------ Mapeo de iconos admitidos ---------------------
IconData _iconFrom(String? name) {
  const fallback = Icons.info_outline;
  const map = <String, IconData>{
    'volunteer_activism_outlined': Icons.volunteer_activism_outlined,
    'favorite_outline': Icons.favorite_outline,
    'handshake_outlined': Icons.handshake_outlined,
    'diversity_3_outlined': Icons.diversity_3_outlined,
    'health_and_safety_outlined': Icons.health_and_safety_outlined,
    'public': Icons.public,
    'redeem_outlined': Icons.redeem_outlined,
  };
  if (name == null || name.isEmpty) return fallback;
  return map[name] ?? fallback;
}

/// ----------------------- Streams Firestore -----------------------
Stream<List<OngItem>> _streamOngItems({required String tripId}) {
  final col = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('ong_items')
      .orderBy('order');

  return col.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => OngItem.fromJson(d.data(), fallbackId: d.id))
        .where((e) => e.visible)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> _watchOngPhotos({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('ong_gallery')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs.map((d) {
      final j = d.data();
      return PhotoItem(
        id: d.id,
        url: (j['url'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
        order: (j['order'] is int) ? j['order'] as int : (int.tryParse('${j['order']}') ?? 999),
        visible: (j['visible'] is bool) ? j['visible'] as bool : (j['visible']?.toString().toLowerCase() == 'true'),
      );
    }).where((p) => p.url.trim().isNotEmpty && p.visible).toList();
    return items;
  });
}

/// ---------------------- UI Const ----------------------
const double kGalleryCardHeight = 280;

/// ----------------------- Página ONG (dinámica) ---------------------
class OngPage extends StatelessWidget {
  const OngPage({super.key, required this.tripId});
  final String tripId;

  Widget _blockCard(OngItem item) {
    return Card(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.title.trim().isNotEmpty)
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Palette.mint.withOpacity(.15),
                    foregroundColor: Palette.brown,
                    child: Icon(_iconFrom(item.icon), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Palette.brown,
                      ),
                    ),
                  ),
                ],
              ),
            if (item.title.trim().isNotEmpty) const SizedBox(height: 8),
            Text(
              item.body,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: const Color(0xFF2A2A2A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'ONG',
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
                stream: _watchOngPhotos(tripId: tripId),
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

            // ===== Lista de bloques ONG =====
            StreamBuilder<List<OngItem>>(
              stream: _streamOngItems(tripId: tripId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snap.hasError) {
                  return SliverToBoxAdapter(child: Center(child: Text('Error: ${snap.error}')));
                }

                final items = snap.data ?? const <OngItem>[];
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Sin contenido disponible.')),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _blockCard(items[i]),
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
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: const Center(
        child: Text(
          'Sin imágenes en la galería',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
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
            BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 6)),
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
