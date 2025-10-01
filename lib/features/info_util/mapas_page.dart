import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/palette.dart';

/* ===================== Modelo MapLink ===================== */
class MapLinkItem {
  final String id;
  final String title;
  final String subtitle;
  final double? lat;
  final double? lng;
  final int zoom;
  final String? url;
  final String? offlineTip;
  final int order;
  final bool visible;
  final String? icon;

  MapLinkItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.url,
    required this.offlineTip,
    required this.order,
    required this.visible,
    required this.icon,
  });

  factory MapLinkItem.fromDoc(Map<String, dynamic> j, {required String fallbackId}) {
    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    return MapLinkItem(
      id: (j['id'] ?? fallbackId).toString(),
      title: (j['title'] ?? '').toString(),
      subtitle: (j['subtitle'] ?? '').toString(),
      lat: _toDouble(j['lat']),
      lng: _toDouble(j['lng']),
      zoom: (j['zoom'] is int) ? j['zoom'] as int : (int.tryParse('${j['zoom']}') ?? 14),
      url: (j['url']?.toString().trim().isEmpty ?? true) ? null : j['url'].toString(),
      offlineTip: (j['offlineTip']?.toString().trim().isEmpty ?? true) ? null : j['offlineTip'].toString(),
      order: (j['order'] is int) ? j['order'] as int : (int.tryParse('${j['order']}') ?? 999),
      visible: (j['visible'] is bool) ? j['visible'] as bool : (j['visible']?.toString().toLowerCase() == 'true'),
      icon: (j['icon']?.toString().isEmpty ?? true) ? null : j['icon'].toString(),
    );
  }
}

/* ===================== Modelo Foto Galería ===================== */
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

/* ===================== Streams Firestore ===================== */
Stream<List<MapLinkItem>> watchMapLinks({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('mapas_links')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs.map((d) {
      final m = d.data();
      return MapLinkItem.fromDoc(m, fallbackId: d.id);
    }).where((e) {
      final okTitle = e.title.trim().isNotEmpty;
      final okCoords = (e.url != null && e.url!.trim().isNotEmpty) || (e.lat != null && e.lng != null);
      return e.visible && okTitle && okCoords;
    }).toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> watchMapPhotos({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('mapas_gallery')
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

/* ===================== Const UI ===================== */
const double kGalleryCardHeight = 280;

/* ===================== Página ===================== */
class MapasPage extends StatelessWidget {
  final String tripId;
  const MapasPage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Mapas',
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
            // ====== Galería arriba (mismo tamaño/estilo que Alojamiento) ======
            SliverToBoxAdapter(
              child: StreamBuilder<List<PhotoItem>>(
                stream: watchMapPhotos(tripId: tripId),
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

            // ====== Lista de mapas (lo tuyo) ======
            StreamBuilder<List<MapLinkItem>>(
              stream: watchMapLinks(tripId: tripId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Sin mapas todavía')),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _MapCard(item: items[i]),
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

/* ===================== Galería Helpers ===================== */
Widget _emptyGalleryBox() {
  return SizedBox(
    height: kGalleryCardHeight,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6))],
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 6))],
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
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF4F4F4),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 36, color: Colors.black45),
                    ),
                  ),
                  if (p.caption.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(.45), borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          p.caption,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
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

/* ===================== Tarjeta de mapa (tu código) ===================== */
class _MapCard extends StatelessWidget {
  final MapLinkItem item;
  const _MapCard({required this.item});

  IconData _iconFrom(String? name) {
    const fallback = Icons.map_outlined;
    const map = <String, IconData>{
      'map': Icons.map,
      'map_outlined': Icons.map_outlined,
      'place_outlined': Icons.place_outlined,
      'place': Icons.place,
      'route': Icons.route,
      'hiking': Icons.hiking,
      'flag_outlined': Icons.flag_outlined,
      'pin_drop_outlined': Icons.pin_drop_outlined,
      'pin_drop': Icons.pin_drop,
      'directions': Icons.directions,
      'layers_outlined': Icons.layers_outlined,
    };
    return map[name] ?? fallback;
  }

  String _coordsText() {
    if (item.lat == null || item.lng == null) return '—';
    return '${item.lat!.toStringAsFixed(6)}, ${item.lng!.toStringAsFixed(6)}';
  }

  Future<void> _openMap() async {
    if (item.url != null && item.url!.trim().isNotEmpty) {
      final uri = Uri.parse(item.url!.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (item.lat != null && item.lng != null) {
      final lat = item.lat!;
      final lng = item.lng!;
      final z = item.zoom.clamp(3, 21);

      final googleApp = Uri.parse('comgooglemaps://?q=$lat,$lng&zoom=$z');
      final googleWeb = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng&zoom=$z');
      final apple     = Uri.parse('http://maps.apple.com/?ll=$lat,$lng&z=$z&q=$lat,$lng');

      if (Platform.isIOS) {
        if (await canLaunchUrl(apple)) { await launchUrl(apple, mode: LaunchMode.externalApplication); return; }
        if (await canLaunchUrl(googleApp)) { await launchUrl(googleApp, mode: LaunchMode.externalApplication); return; }
        await launchUrl(googleWeb, mode: LaunchMode.externalApplication); return;
      }
      if (await canLaunchUrl(googleApp)) { await launchUrl(googleApp, mode: LaunchMode.externalApplication); return; }
      await launchUrl(googleWeb, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyCoords(BuildContext context) async {
    final text = (item.lat != null && item.lng != null) ? '${item.lat},${item.lng}' : (item.url ?? '');
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text.trim()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copiado al portapapeles')));
  }

  void _showOfflineTips(BuildContext context) {
    final tip = (item.offlineTip?.trim().isNotEmpty ?? false)
        ? item.offlineTip!.trim()
        : '''
1) Abre Google Maps > Tu foto > Mapas sin conexión.
2) Toca "Seleccionar tu propio mapa", ajusta el rectángulo y pulsa "Descargar".
3) Repite para cubrir todo el recorrido.
4) En Ajustes de mapas sin conexión: activa "Actualizar automáticamente".
5) Activa "Solo Wi-Fi" para no gastar datos.

Sugerencia: crea también un marcador en "Tus sitios > Guardados".
''';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(tip, style: GoogleFonts.poppins(fontSize: 14, height: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoords = (item.lat != null && item.lng != null);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Palette.brown, fontSize: 16),
                  ),
                ),
              ],
            ),
            if (item.subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.subtitle, style: GoogleFonts.poppins(fontSize: 13.5, height: 1.5)),
            ],
            if (hasCoords) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.my_location, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text(_coordsText(), style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black54)),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(onPressed: _openMap, icon: const Icon(Icons.place_outlined), label: const Text('Abrir mapa')),
                OutlinedButton.icon(onPressed: () => _copyCoords(context), icon: const Icon(Icons.copy_all_outlined), label: Text(hasCoords ? 'Copiar coords' : 'Copiar enlace')),
                OutlinedButton.icon(onPressed: () => _showOfflineTips(context), icon: const Icon(Icons.download_for_offline_outlined), label: const Text('Cómo descargar offline')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
