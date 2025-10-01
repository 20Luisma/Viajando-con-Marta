import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../theme/palette.dart';

/// =============== Modelos ===============
class VisadoLink {
  final String label;
  final String url;
  final String kind; // 'web' | 'video' | 'file'
  final int order;
  final bool visible;

  VisadoLink({
    required this.label,
    required this.url,
    this.kind = 'web',
    this.order = 999,
    this.visible = true,
  });

  factory VisadoLink.fromJson(Map<String, dynamic> j) => VisadoLink(
    label: (j['label'] ?? '').toString(),
    url: (j['url'] ?? '').toString(),
    kind: (j['kind'] ?? 'web').toString(),
    order: (j['order'] is int)
        ? j['order'] as int
        : (int.tryParse('${j['order']}') ?? 999),
    visible: (j['visible'] is bool)
        ? j['visible'] as bool
        : (j['visible']?.toString().toLowerCase() == 'true'),
  );
}

class VisadoItem {
  final String id;
  final String body;
  final List<VisadoLink> links; // múltiples enlaces por bloque
  final int order;
  final bool visible;

  VisadoItem({
    required this.id,
    required this.body,
    required this.links,
    this.order = 999,
    this.visible = true,
  });

  /// Compatibilidad: si existen linkUrl/linkLabel/linkKind, se convierten a links[]
  factory VisadoItem.fromJson(Map<String, dynamic> j, String fallbackId) {
    List<VisadoLink> parsed = [];
    if (j['links'] is List) {
      parsed = List<Map<String, dynamic>>.from(j['links'])
          .map(VisadoLink.fromJson)
          .where((l) => l.url.trim().isNotEmpty && l.visible)
          .toList();
    } else {
      final legacyUrl = (j['linkUrl'] ?? '').toString();
      if (legacyUrl.trim().isNotEmpty) {
        parsed = [
          VisadoLink(
            label: (j['linkLabel'] ?? 'Abrir enlace').toString(),
            url: legacyUrl,
            kind: (j['linkKind'] ?? 'web').toString(),
            order: (j['order'] is int)
                ? j['order'] as int
                : (int.tryParse('${j['order']}') ?? 999),
            visible: (j['visible'] is bool)
                ? j['visible'] as bool
                : (j['visible']?.toString().toLowerCase() == 'true'),
          ),
        ];
      }
    }
    parsed.sort((a, b) => a.order.compareTo(b.order));

    return VisadoItem(
      id: (j['id'] ?? fallbackId).toString(),
      body: (j['body'] ?? '').toString(),
      links: parsed,
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

class VisadoResource {
  final String id;
  final String title;
  final String url;
  final String kind; // 'web' | 'video' | 'file'
  final int order;
  final bool visible;

  VisadoResource({
    required this.id,
    required this.title,
    required this.url,
    required this.kind,
    required this.order,
    required this.visible,
  });

  factory VisadoResource.fromJson(Map<String, dynamic> j, String id) {
    return VisadoResource(
      id: id,
      title: (j['title'] ?? '').toString(),
      url: (j['url'] ?? '').toString(),
      kind: (j['kind'] ?? 'web').toString(),
      order: (j['order'] is int)
          ? j['order'] as int
          : (int.tryParse('${j['order']}') ?? 999),
      visible: (j['visible'] is bool)
          ? j['visible'] as bool
          : (j['visible']?.toString().toLowerCase() == 'true'),
    );
  }
}

/// =============== Streams Firestore ===============
Stream<List<VisadoItem>> _watchItems({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('visado_items')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => VisadoItem.fromJson(d.data(), d.id))
        .where((x) => x.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> _watchGallery({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('visado_gallery')
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

Stream<List<VisadoResource>> _watchResources({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('visado_resources')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => VisadoResource.fromJson(d.data(), d.id))
        .where((x) => x.visible && x.url.trim().isNotEmpty)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

/// =============== Helpers UI ===============
IconData _resIcon(String kind) {
  switch (kind) {
    case 'video':
      return Icons.ondemand_video_outlined;
    case 'file':
      return Icons.download_outlined;
    default:
      return Icons.open_in_new;
  }
}

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

/// =============== Página Visado ===============
class VisadoPage extends StatelessWidget {
  const VisadoPage({super.key, required this.tripId});
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
          'Visado',
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
            // Galería arriba
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

            // Bloques de información
            SliverToBoxAdapter(
              child: StreamBuilder<List<VisadoItem>>(
                stream: _watchItems(tripId: tripId),
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
                      child: Center(child: Text('Sin contenido de visado')),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                              Text(
                                x.body,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              if (x.links.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: x.links
                                      .where((l) =>
                                  l.visible && l.url.trim().isNotEmpty)
                                      .toList()
                                      .map((l) => OutlinedButton.icon(
                                    onPressed: () =>
                                        launchUrlString(l.url),
                                    icon: Icon(_resIcon(l.kind)),
                                    label: Text(
                                      l.label.isEmpty
                                          ? 'Abrir enlace'
                                          : l.label,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ))
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

            // Recursos globales
            SliverToBoxAdapter(
              child: StreamBuilder<List<VisadoResource>>(
                stream: _watchResources(tripId: tripId),
                builder: (context, snap) {
                  if (!snap.hasData || (snap.data?.isEmpty ?? true)) {
                    return const SizedBox.shrink();
                  }
                  final res = snap.data!;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recursos',
                                style: GoogleFonts.lora(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Palette.brown,
                                )),
                            const SizedBox(height: 8),
                            ...res.map((r) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0),
                              leading: Icon(_resIcon(r.kind)),
                              title: Text(r.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                r.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => launchUrlString(r.url),
                            )),
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
