import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/palette.dart';
import 'widgets/practice_card.dart';

/// ===================== Modelo Buenas Prácticas =====================
class PracticeItem {
  final String id;
  final String title;
  final String icon; // Material icon key
  final List<String> bullets;
  final List<String> tags;
  final int order;
  final bool visible;

  PracticeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.bullets,
    required this.tags,
    this.order = 999,
    this.visible = true,
  });

  factory PracticeItem.fromJson(Map<String, dynamic> j, String fallbackId) {
    return PracticeItem(
      id: (j['id'] ?? fallbackId).toString(),
      title: (j['title'] ?? '').toString(),
      icon: (j['icon'] ?? 'info_outline').toString(),
      bullets: (j['bullets'] is List)
          ? List<String>.from(j['bullets'].map((e) => e.toString()))
          : const <String>[],
      tags: (j['tags'] is List)
          ? List<String>.from(j['tags'].map((e) => e.toString()))
          : const <String>[],
      order: (j['order'] is int)
          ? j['order'] as int
          : (int.tryParse('${j['order']}') ?? 999),
      visible: (j['visible'] is bool)
          ? j['visible'] as bool
          : (j['visible']?.toString().toLowerCase() == 'true'),
    );
  }
}

/// ===================== Stream Buenas Prácticas =====================
Stream<List<PracticeItem>> _watchPractices({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('buenas_practicas_items')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => PracticeItem.fromJson(d.data(), d.id))
        .where((p) => p.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

/// ===================== Galería: modelo + stream =====================
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

Stream<List<PhotoItem>> _watchGallery({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('buenas_practicas_gallery')
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

/* ------------------------------- Icon Helper ------------------------------- */
IconData _iconFrom(String? name) {
  const fallback = Icons.info_outline;
  const map = <String, IconData>{
    'people_alt_outlined': Icons.people_alt_outlined,
    'park_outlined': Icons.park_outlined,
    'volunteer_activism_outlined': Icons.volunteer_activism_outlined,
    'health_and_safety_outlined': Icons.health_and_safety_outlined,
    'sentiment_satisfied_alt_outlined': Icons.sentiment_satisfied_alt_outlined,
    'info_outline': Icons.info_outline,
  };
  return (name != null && name.isNotEmpty) ? (map[name] ?? fallback) : fallback;
}

/// ===================== Página dinámica (con galería arriba) =====================
const double kGalleryCardHeight = 280;

class GuiaBuenasPracticasPage extends StatelessWidget {
  const GuiaBuenasPracticasPage({super.key, required this.tripId});
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
          'Guía de buenas prácticas',
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

            // ===== Lista de prácticas =====
            SliverToBoxAdapter(
              child: StreamBuilder<List<PracticeItem>>(
                stream: _watchPractices(tripId: tripId),
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
                      child: Center(child: Text('Sin prácticas')),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return PracticeCard(
                        title: item.title,
                        icon: _iconFrom(item.icon),
                        bullets: item.bullets,
                        tags: item.tags,
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

/* ========================= Helpers Galería (UI) ========================= */
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
