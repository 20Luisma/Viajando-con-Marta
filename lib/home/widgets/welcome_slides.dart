import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/palette.dart';

class WelcomeSlides extends StatefulWidget {
  const WelcomeSlides({super.key, required this.tripId});
  final String tripId;

  @override
  State<WelcomeSlides> createState() => _WelcomeSlidesState();
}

class _WelcomeSlidesState extends State<WelcomeSlides> {
  static const _slidesCount = 3;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoplay();
  }

  void _startAutoplay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      // Avanza y se detiene en el último slide (no loop).
      if (_index < _slidesCount - 1) {
        setState(() => _index += 1);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadTrip() async {
    final snap = await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .get();
    return snap.data();
  }

  // Intenta varias claves posibles para mostrar el destino
  String _resolveDestino(Map<String, dynamic> data) {
    final nested = (data['country'] is Map)
        ? ((data['country']['name'] ?? data['country']['title'])?.toString() ?? '')
        : '';
    final candidates = [
      data['destination'],
      data['country'],
      data['pais'],
      data['destino'],
      data['title'],
      data['name'],
      nested,
    ].map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList();

    return candidates.isNotEmpty ? candidates.first : 'tu viaje';
  }

  String _daysLeft(DateTime start) {
    final diff = start.difference(DateTime.now());
    return diff.inDays > 0 ? '${diff.inDays}' : '0';
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // Un poco más alto para evitar recortes, pero compacto.
    final double targetHeight = w >= 700 ? 350 : 340;

    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadTrip(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SkeletonCard(height: 340),
          );
        }

        final data = snap.data!;
        final destino = _resolveDestino(data);
        final startIso = (data['startDate'] ?? '').toString();
        final start = DateTime.tryParse(startIso) ?? DateTime.now();
        final dias = _daysLeft(start);

        // Tipos unificados
        final headline = GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Palette.brown,
          height: 1.25,
        );
        final headlineAccent = headline.copyWith(
          color: Palette.accent,
          fontWeight: FontWeight.w900,
        );
        final noteText = GoogleFonts.lora(
          fontSize: 18,               // ↓ más pequeño para que quepa sin scroll
          height: 1.45,
          color: Palette.brown,
          fontWeight: FontWeight.w600,
        );
        final signature = GoogleFonts.lora(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontStyle: FontStyle.italic,
          color: Palette.brown,
        );

        // Contenidos (slide 3 resumido)
        final slides = <Widget>[
          Text(
            '¿Preparad@ para tu viaje a $destino?',
            textAlign: TextAlign.center,
            style: headline,
          ),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: headline,
              children: [
                const TextSpan(text: 'Solo quedan '),
                TextSpan(text: dias, style: headlineAccent),
                TextSpan(text: ' días para llegar a $destino'),
              ],
            ),
          ),
          // Nota final breve (sin scroll)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Gracias por unirte a este viaje a $destino. '
                        'Estoy feliz de compartirlo contigo y segura de que será inolvidable.',
                    textAlign: TextAlign.center,
                    style: noteText,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Marta', style: signature),
                  ),
                ],
              ),
            ),
          ),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SizedBox(
            height: targetHeight,
            child: Card(
              elevation: 6,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Marca de agua
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.08,
                        child: Image.asset(
                          'assets/images/pasaporte.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      // Banda superior
                      Container(
                        width: double.infinity,
                        color: Palette.mint,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Text(
                          '¡BIENVENID@ AL EQUIPO!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Palette.brown,
                            letterSpacing: .5,
                          ),
                        ),
                      ),

                      // Contenido con transición “flash”
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          child: _SlideInner(
                            key: ValueKey<int>(_index),
                            child: slides[_index],
                          ),
                        ),
                      ),

                      // Banda inferior
                      Container(
                        width: double.infinity,
                        color: Palette.mint.withOpacity(.9),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'VIAJE SOLIDARIO A ${destino.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlideInner extends StatelessWidget {
  const _SlideInner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Colchón cómodo y consistente
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Center(child: child),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
