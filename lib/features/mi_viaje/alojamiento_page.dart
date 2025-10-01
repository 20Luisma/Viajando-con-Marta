import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/palette.dart';

/* ========================= Firestore subcollections ========================= */
const String kHotelsSubcollection  = 'alojamiento_hotels';
const String kPhotosSubcollection  = 'alojamiento_gallery';

/* ========================= UI Const ========================= */
const double kGalleryCardHeight = 280;

/* ========================= MODELOS ========================= */

class HotelItem {
  final String id;
  final String title;
  final String subtitle;
  final String icon; // nombre del icono como string
  final int order;
  final bool visible;

  HotelItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.order,
    required this.visible,
  });

  factory HotelItem.fromMap(Map<String, dynamic> j, String fallbackId) {
    final id = (j['id'] ?? '').toString().trim();
    final title = (j['title'] ?? '').toString().trim();
    final subtitle = (j['subtitle'] ?? '').toString().trim();
    final icon = (j['icon'] ?? 'location_city').toString().trim();
    final order = (j['order'] is int)
        ? j['order'] as int
        : int.tryParse('${j['order']}') ?? 999;
    final visible = (j['visible'] is bool)
        ? j['visible'] as bool
        : (j['visible']?.toString().toLowerCase() == 'true');

    return HotelItem(
      id: id.isEmpty ? fallbackId : id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      order: order,
      visible: visible,
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

/* ========================= DATA Streams ========================= */

Stream<List<HotelItem>> _watchHotels({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection(kHotelsSubcollection)
      .orderBy('order');

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => HotelItem.fromMap(d.data(), d.id))
        .where((h) => h.visible)
        .toList();
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  });
}

Stream<List<PhotoItem>> _watchPhotos({required String tripId}) {
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
            : (int.tryParse('${j['order']}') ?? 999),
        visible: (j['visible'] is bool)
            ? j['visible'] as bool
            : (j['visible']?.toString().toLowerCase() == 'true'),
      );
    }).where((p) => p.url.trim().isNotEmpty && p.visible).toList();
    return items;
  });
}

/* ========================= ICONS ========================= */

IconData _iconFrom(String name) {
  switch (name) {
    case 'location_city':
      return Icons.location_city;
    case 'hotel':
      return Icons.hotel;
    case 'park_outlined':
      return Icons.park_outlined;
    case 'pets':
      return Icons.pets;
    case 'beach_access_outlined':
      return Icons.beach_access_outlined;
    case 'home':
      return Icons.home_outlined;
    default:
      return Icons.home_outlined;
  }
}

/* ========================= Expander reutilizable ========================= */

class _Expander extends StatefulWidget {
  final Widget leading;
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  const _Expander({
    required this.leading,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_Expander> createState() => _ExpanderState();
}

class _ExpanderState extends State<_Expander>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    widget.leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Palette.brown,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, color: Palette.brown),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 220),
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: widget.child,
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/* ========================= UI ========================= */

class AlojamientoPage extends StatelessWidget {
  const AlojamientoPage({super.key, required this.tripId});
  final String tripId;

  Widget _avatar(IconData icon) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Palette.mint.withOpacity(.15),
      foregroundColor: Palette.brown,
      child: Icon(icon, size: 20),
    );
  }

  TextStyle _p() => GoogleFonts.poppins(
    fontSize: 13.5,
    height: 1.45,
    color: const Color(0xFF2A2A2A),
  );

  Widget _hotelExpander(HotelItem h) {
    return _Expander(
      leading: _avatar(_iconFrom(h.icon)),
      title: h.title,
      initiallyExpanded: false,
      child: Text(h.subtitle, style: _p()),
    );
  }

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
          'Alojamiento',
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
                stream: _watchPhotos(tripId: tripId),
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

            // ---------- Lista de alojamientos (desplegables) ----------
            StreamBuilder<List<HotelItem>>(
              stream: _watchHotels(tripId: tripId),
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
                      child: Center(child: Text('Sin alojamientos')),
                    ),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _hotelExpander(items[i]),
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
