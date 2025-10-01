import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/palette.dart';

/// ----------------------------- MODELOS DINÁMICOS -----------------------------

class FlightBlock {
  final String title;
  final List<String> paragraphs;
  final int order;
  final bool visible;

  FlightBlock({
    required this.title,
    required this.paragraphs,
    this.order = 1,
    this.visible = true,
  });

  factory FlightBlock.fromJson(Map<String, dynamic> j) => FlightBlock(
    title: j['title'] ?? 'Vuelos',
    paragraphs: List<String>.from(j['paragraphs'] ?? const []),
    order: j['order'] ?? 1,
    visible: (j['visible'] ?? true) as bool,
  );

  factory FlightBlock.fromMap(Map<String, dynamic> j) =>
      FlightBlock.fromJson(j);

  Map<String, dynamic> toJson() => {
    'title': title,
    'paragraphs': paragraphs,
    'order': order,
    'visible': visible,
  };
}

class SimpleCardItem {
  final String id;
  final String icon;
  final String title;
  final String body;
  final int order;
  final bool visible;

  SimpleCardItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    this.order = 999,
    this.visible = true,
  });

  factory SimpleCardItem.fromJson(Map<String, dynamic> j) => SimpleCardItem(
    id: j['id'] ?? '',
    icon: j['icon'] ?? 'directions_car_filled',
    title: j['title'] ?? '',
    body: j['body'] ?? '',
    order: j['order'] ?? 999,
    visible: (j['visible'] ?? true) as bool,
  );

  factory SimpleCardItem.fromMap(Map<String, dynamic> j, String fallbackId) {
    final x = SimpleCardItem.fromJson(j);
    return SimpleCardItem(
      id: x.id.isEmpty ? fallbackId : x.id,
      icon: x.icon,
      title: x.title,
      body: x.body,
      order: x.order,
      visible: x.visible,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'icon': icon,
    'title': title,
    'body': body,
    'order': order,
    'visible': visible,
  };
}

class TransportData {
  final FlightBlock? flights;
  final List<SimpleCardItem> cards;

  TransportData({
    this.flights,
    this.cards = const [],
  });

  factory TransportData.fromJson(Map<String, dynamic> j) => TransportData(
    flights:
    j['flights'] != null ? FlightBlock.fromJson(j['flights']) : null,
    cards: (j['cards'] as List<dynamic>? ?? const [])
        .map((e) => SimpleCardItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'flights': flights?.toJson(),
    'cards': cards.map((e) => e.toJson()).toList(),
  };
}

/// --------------------------- FIRESTORE FETCH --------------------------------

const String kTransportGallerySubcollection = 'transporte_gallery';

Future<TransportData> fetchTransportDataFromFirestore({
  required String tripId,
}) async {
  final db = FirebaseFirestore.instance;

  // Vuelos (puede no existir)
  FlightBlock? flights;
  final flDoc = await db
      .collection('trips')
      .doc(tripId)
      .collection('transporte_flights')
      .doc('main')
      .get();

  if (flDoc.exists) {
    final data = flDoc.data();
    if (data != null) {
      final parsed = FlightBlock.fromMap(data);
      flights = parsed.visible ? parsed : null;
    }
  }

  // Secciones
  final q = await db
      .collection('trips')
      .doc(tripId)
      .collection('transporte_cards')
      .orderBy('order')
      .get();

  final cards = q.docs
      .map((d) => SimpleCardItem.fromMap(d.data(), d.id))
      .where((c) => c.visible)
      .toList();

  return TransportData(flights: flights, cards: cards);
}

/// --------------------------- GALERÍA TRANSPORTE ------------------------------

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

Stream<List<PhotoItem>> watchTransportPhotos(String tripId) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection(kTransportGallerySubcollection)
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

/// ------------------------------ ICON HELPERS --------------------------------
IconData _iconFrom(String name) {
  const map = <String, IconData>{
    // vehículos
    'scooter': Icons.electric_scooter,
    'pedal_bike': Icons.pedal_bike,
    'two_wheeler': Icons.two_wheeler,
    'directions_car_filled': Icons.directions_car_filled,
    'local_taxi': Icons.local_taxi,
    'directions_bus': Icons.directions_bus,
    'airport_shuttle': Icons.airport_shuttle,
    'train': Icons.train,
    'tram': Icons.tram,
    'subway': Icons.subway,
    'directions_boat': Icons.directions_boat,
    'sailing': Icons.sailing,
    'ferry': Icons.directions_boat,
    'airplanemode_active': Icons.airplanemode_active,
    'flight_takeoff': Icons.flight_takeoff,
    'flight_land': Icons.flight_land,
    'helicopter': Icons.flight, // fallback
    'local_shipping': Icons.local_shipping,
    'rv_hookup': Icons.rv_hookup,
    'tour': Icons.tour,

    // a pie / senderismo
    'directions_walk': Icons.directions_walk,
    'hiking': Icons.hiking,

    // animales
    'camel': Icons.pets,
    'donkey': Icons.pets,
    'horse': Icons.pets,
    'elephant': Icons.pets,
  };
  return map[name] ?? Icons.help_outline;
}

/// -------------------------- EXPANDER REUTILIZABLE ---------------------------

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

/// --------------------------- GALERÍA (UI) -----------------------------------

const double kGalleryCardHeight = 280;

Widget _emptyGalleryBox() {
  return Container(
    height: kGalleryCardHeight,
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

/// ------------------------------- UI WIDGETS ---------------------------------

class TransportePage extends StatelessWidget {
  const TransportePage({super.key, required this.tripId});
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
    fontSize: 14,
    height: 1.5,
    color: const Color(0xFF2A2A2A),
  );

  TextStyle _h() => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Palette.brown,
  );

  Widget _flightsExpander(FlightBlock flights) {
    return _Expander(
      leading: _avatar(Icons.airplanemode_active),
      title: flights.title,
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...flights.paragraphs.asMap().entries.map((e) {
            final idx = e.key;
            final text = e.value;
            final isHeadline = idx == 2;
            return Padding(
              padding: EdgeInsets.only(bottom: isHeadline ? 6 : 10),
              child: Text(text, style: isHeadline ? _h() : _p()),
            );
          }),
        ],
      ),
    );
  }

  Widget _simpleExpander(SimpleCardItem item) {
    return _Expander(
      leading: _avatar(_iconFrom(item.icon)),
      title: item.title,
      initiallyExpanded: false,
      child: Text(item.body, style: _p()),
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
          'Transporte',
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
            // ---------- Galería de Transporte arriba ----------
            SliverToBoxAdapter(
              child: StreamBuilder<List<PhotoItem>>(
                stream: watchTransportPhotos(tripId),
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

            // ---------- Bloques: vuelos + secciones ----------
            SliverToBoxAdapter(
              child: FutureBuilder<TransportData>(
                future: fetchTransportDataFromFirestore(tripId: tripId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(child: Text('Error: ${snap.error}')),
                    );
                  }

                  final data = snap.data ?? TransportData();
                  final flights = data.flights;
                  final cards =
                  (data.cards)..sort((a, b) => a.order.compareTo(b.order));

                  final children = <Widget>[
                    if (flights != null) _flightsExpander(flights),
                    ...cards.map(_simpleExpander),
                  ];

                  if (children.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final w in children) ...[
                          w,
                          const SizedBox(height: 12)
                        ],
                      ],
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
