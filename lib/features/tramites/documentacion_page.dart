import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../theme/palette.dart';

/// ===================== Modelos & Streams =====================
class _DocConfig {
  final String driveUrl;
  final String note;     // texto plano con bullets o párrafos
  final bool visible;
  const _DocConfig({this.driveUrl = '', this.note = '', this.visible = true});

  factory _DocConfig.from(Map<String, dynamic>? j) {
    final rawVisible = j == null ? null : j['visible'];
    final bool vis = rawVisible is bool
        ? rawVisible
        : (rawVisible?.toString().toLowerCase() == 'true');

    return _DocConfig(
      driveUrl: (j?['driveUrl'] ?? '').toString(),
      note: (j?['note'] ?? '').toString(),
      visible: vis,
    );
  }
}

class _PhotoItem {
  final String id;
  final String url;
  final String caption;
  final int order;
  final bool visible;
  const _PhotoItem({
    required this.id,
    required this.url,
    required this.caption,
    required this.order,
    required this.visible,
  });
}

Stream<_DocConfig> _watchConfig(String tripId) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('documentacion_config')
      .doc('app');
  return ref.snapshots().map((d) => _DocConfig.from(d.data()));
}

Stream<List<_PhotoItem>> _watchGallery(String tripId) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('documentacion_gallery')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs.map((d) {
      final j = d.data();
      final rawVisible = j['visible'];
      final bool vis = rawVisible is bool
          ? rawVisible
          : (rawVisible?.toString().toLowerCase() == 'true');

      final rawOrder = j['order'];
      final int ord = rawOrder is int ? rawOrder : (int.tryParse('$rawOrder') ?? 999);

      return _PhotoItem(
        id: d.id,
        url: (j['url'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
        order: ord,
        visible: vis,
      );
    }).where((p) => p.url.isNotEmpty && p.visible).toList();

    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

/// ===================== UI =====================
const double _kGalleryCardHeight = 280;

class DocumentacionPage extends StatelessWidget {
  const DocumentacionPage({super.key, required this.tripId});
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
          'Documentación',
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
            // ========== Galería arriba ==========
            SliverToBoxAdapter(
              child: StreamBuilder<List<_PhotoItem>>(
                stream: _watchGallery(tripId),
                builder: (context, snap) {
                  final photos = snap.data ?? const <_PhotoItem>[];
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

            // ========== Bloque de Nota + Botón Drive ==========
            SliverToBoxAdapter(
              child: StreamBuilder<_DocConfig>(
                stream: _watchConfig(tripId),
                builder: (context, snap) {
                  final cfg = snap.data ?? const _DocConfig();
                  if (!cfg.visible && (cfg.note.isEmpty && cfg.driveUrl.isEmpty)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cfg.note.trim().isNotEmpty)
                              Text(
                                cfg.note,
                                style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                              ),
                            if (cfg.driveUrl.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => launchUrlString(cfg.driveUrl),
                                icon: const Icon(Icons.folder_shared_outlined),
                                label: Text('Abrir carpeta común', style: GoogleFonts.poppins()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.brown,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
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

Widget _emptyGalleryBox() {
  return SizedBox(
    height: _kGalleryCardHeight,
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
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

class _PhotoFadeShow extends StatefulWidget {
  final List<_PhotoItem> photos;
  const _PhotoFadeShow({required this.photos});
  @override
  State<_PhotoFadeShow> createState() => _PhotoFadeShowState();
}

class _PhotoFadeShowState extends State<_PhotoFadeShow> {
  int _index = 0;
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
  }

  @override
  void didUpdateWidget(covariant _PhotoFadeShow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos.length != widget.photos.length) {
      _index = 0;
      _pc.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.photos;
    return SizedBox(
      height: _kGalleryCardHeight,
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
        child: PageView.builder(
          controller: _pc,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final p = items[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: p.url,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  placeholder: (_, __) => Container(
                    color: const Color(0xFFF4F4F4),
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, size: 36, color: Colors.black45)),
                ),
                if (p.caption.trim().isNotEmpty)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            );
          },
        ),
      ),
    );
  }
}
