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
  final PageController _ctrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Avanza automáticamente cada 3 segundos
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      if (_page < 2) {
        _page++;
        _ctrl.animateToPage(
          _page,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        return true;
      }
      return false;
    });
  }

  Future<Map<String, dynamic>?> _loadTrip() async {
    final snap = await FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .get();
    return snap.data();
  }

  String _daysLeft(DateTime start) {
    final diff = start.difference(DateTime.now());
    return diff.inDays > 0 ? '${diff.inDays}' : '0';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadTrip(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 250, child: Center(child: CircularProgressIndicator()));
        }

        final data = snap.data!;
        final destino = (data['destination'] ?? 'tu viaje').toString();
        final startIso = (data['startDate'] ?? '').toString();
        final start = DateTime.tryParse(startIso) ?? DateTime.now();
        final dias = _daysLeft(start);

        final slides = <Widget>[
          _Slide(
            color: Palette.mint,
            child: Text(
              '¿Estás preparado para tu viaje a $destino?',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Palette.brown,
              ),
            ),
          ),
          _Slide(
            color: Palette.sand,
            child: Text(
              'Solo quedan $dias días',
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Palette.accent,
              ),
            ),
          ),
          _Slide(
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '¡BIENVENID@ AL EQUIPO!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Palette.brown,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Estoy muy feliz de poder compartir este viaje contigo y '
                      'estoy segura de que vamos a vivir una experiencia inolvidable.\n\n'
                      '¡Mil gracias por tu confianza!\n\nMarta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lora(
                    fontSize: 16,
                    height: 1.4,
                    color: Palette.brown,
                  ),
                ),
              ],
            ),
          ),
        ];

        return SizedBox(
          height: 250,
          child: PageView(
            controller: _ctrl,
            children: slides,
          ),
        );
      },
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}
