import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/palette.dart';
import '../../shared/widgets/chips.dart';

/// ======================= Const UI =======================
const double kGalleryCardHeight = 280;

/// ======================= Modelos =======================
class PhraseItem {
  final String id;
  final String swahili; // texto en el idioma local
  final String esp;     // traducción al español
  final List<String> tips;
  final int order;
  final bool visible;

  PhraseItem({
    required this.id,
    required this.swahili,
    required this.esp,
    this.tips = const [],
    this.order = 999,
    this.visible = true,
  });

  factory PhraseItem.fromMap(Map<String, dynamic> j, String fallbackId) {
    return PhraseItem(
      id: (j['id'] ?? fallbackId).toString(),
      swahili: (j['swahili'] ?? '').toString(),
      esp: (j['esp'] ?? '').toString(),
      tips: (j['tips'] is List)
          ? List<String>.from(j['tips'].map((e) => e.toString()))
          : const <String>[],
      order: (j['order'] is int)
          ? j['order'] as int
          : int.tryParse('${j['order']}') ?? 999,
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

/// ======================= Streams =======================
Stream<List<PhraseItem>> _watchPhrases({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('idioma_phrases')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => PhraseItem.fromMap(d.data(), d.id))
        .where((p) => p.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> _watchPhotos({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('idioma_gallery')
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

/// ======================= Página =======================
class IdiomaPage extends StatelessWidget {
  const IdiomaPage({super.key, required this.tripId, this.title});
  final String tripId;
  /// Título opcional; si no se pasa, se usa "Idioma"
  final String? title;

  Widget _phrase(PhraseItem item) {
    if (item.swahili.trim().isEmpty && item.esp.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.swahili,
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Palette.brown,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.esp,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: const Color(0xFF2A2A2A),
              ),
            ),
            if (item.tips.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: item.tips.map((t) => ChipTag(text: t)).toList(),
              ),
            ],
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
          title?.trim().isNotEmpty == true ? title!.trim() : 'Idioma',
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
            // --------- Galería arriba ---------
            SliverToBoxAdapter(
              child: StreamBuilder<List<PhotoItem>>(
                stream: _watchPhotos(tripId: tripId),
                builder: (context, snap) {
                  final photos = snap.data ?? const <PhotoItem>[];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: photos.isEmpty
                        ? _emptyGalleryBox()
                        : _PhotoFadeShow(photos: photos),
                  );
                },
              ),
            ),

            // --------- Lista de frases ---------
            StreamBuilder<List<PhraseItem>>(
              stream: _watchPhrases(tripId: tripId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Error: ${snap.error}')),
                    ),
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
                      child: Center(child: Text('Sin frases todavía')),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _phrase(items[i]),
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

/// ===================== Helpers Galería =====================
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

/// ===================== Fade Slideshow =====================
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
