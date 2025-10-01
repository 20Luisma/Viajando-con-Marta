import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../theme/palette.dart';

/* ========================= Const UI ========================= */
const double kGalleryCardHeight = 280;

/* ========================= Firestore subcollections ========================= */
// trips/{tripId}/datos_practicos_items
// trips/{tripId}/datos_practicos_gallery

/* ========================= Modelo ========================= */
class DatoPracticoItem {
  final String id;
  final String title;
  final String body;
  final String? icon;
  final int order;
  final bool visible;

  DatoPracticoItem({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.order,
    required this.visible,
  });

  factory DatoPracticoItem.fromDoc(Map<String, dynamic> j, String fallbackId) {
    int parseInt(dynamic v, {int d = 999}) {
      if (v is int) return v;
      return int.tryParse('$v') ?? d;
    }

    bool parseBool(dynamic v, {bool d = true}) {
      if (v is bool) return v;
      final s = v?.toString().toLowerCase();
      return s == 'true' ? true : s == 'false' ? false : d;
    }

    return DatoPracticoItem(
      id: (j['id'] ?? fallbackId).toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      icon: (j['icon'] == null || j['icon'].toString().isEmpty) ? null : j['icon'].toString(),
      order: parseInt(j['order']),
      visible: parseBool(j['visible']),
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

/* ========================= Streams ========================= */
Stream<List<DatoPracticoItem>> watchDatosPracticosItems({
  required String tripId,
}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('datos_practicos_items')
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs.map((d) {
      return DatoPracticoItem.fromDoc(d.data(), d.id);
    }).where((e) => e.visible && e.title.trim().isNotEmpty).toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> _watchPhotos({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('datos_practicos_gallery')
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
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

/* ========================= Iconos ========================= */
IconData _iconFrom(String? name) {
  const fallback = Icons.info_outline;
  const map = <String, IconData>{
    'badge_outlined': Icons.badge_outlined,
    'vaccines_outlined': Icons.vaccines_outlined,
    'thermostat_auto_outlined': Icons.thermostat_auto_outlined,
    'power_outlined': Icons.power_outlined,
    'language': Icons.language,
    'payments_outlined': Icons.payments_outlined,
    'schedule_outlined': Icons.schedule_outlined,
    'wifi_outlined': Icons.wifi_outlined,
    'info_outline': Icons.info_outline,
  };
  return map[name] ?? fallback;
}

/* ========================= Página ========================= */
class DatosPracticosPage extends StatelessWidget {
  final String tripId;
  const DatosPracticosPage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Datos prácticos',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Palette.brown,
          ),
        ),
      ),
      body: StreamBuilder<List<DatoPracticoItem>>(
        stream: watchDatosPracticosItems(tripId: tripId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snap.error}'),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // -------- Galería arriba --------
              StreamBuilder<List<PhotoItem>>(
                stream: _watchPhotos(tripId: tripId),
                builder: (context, psnap) {
                  final photos = psnap.data ?? const <PhotoItem>[];
                  if (photos.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: kGalleryCardHeight,
                        child: _emptyGalleryBox(),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PhotoFadeShow(photos: photos),
                  );
                },
              ),

              // -------- Contenido (acordeones dentro de una card) --------
              if (items.isEmpty)
                const Center(child: Text('Sin datos prácticos'))
              else
                Card(
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
                          body: it.body,
                          icon: _iconFrom(it.icon),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/* ========================= Acordeón ========================= */
class _Accordion extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;

  const _Accordion({
    required this.title,
    required this.body,
    required this.icon,
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
              child: _LinkText(
                widget.body,
                textStyle: GoogleFonts.poppins(
                    fontSize: 14, height: 1.5, color: const Color(0xFF2A2A2A)),
                linkStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  height: 1.5,
                  color: Palette.brown,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* ========================= Linkify “lite” ========================= */
class _LinkText extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final TextStyle? linkStyle;

  const _LinkText(
      this.text, {
        this.textStyle,
        this.linkStyle,
      });

  static final _urlRegex = RegExp(
    r'((https?:\/\/|www\.)[^\s<>"\)]+)',
    caseSensitive: false,
  );

  Future<void> _launch(String url) async {
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    int last = 0;

    for (final m in _urlRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: textStyle));
      }
      final url = m.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle ?? const TextStyle(decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()..onTap = () => _launch(url),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: textStyle));
    }

    return RichText(text: TextSpan(children: spans, style: textStyle));
  }
}

/* ========================= Galería (UI helpers) ========================= */
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
