import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/palette.dart';
import '../../shared/widgets/bullets.dart';
import '../../shared/widgets/chips.dart';

class DayCard extends StatelessWidget {
  final String dayLabel, date, place;
  final List<String> bullets, tags;
  final IconData icon;

  const DayCard({
    super.key,
    required this.dayLabel,
    required this.date,
    required this.place,
    required this.bullets,
    required this.tags,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        // 👇 un pelín más de aire abajo para evitar cualquier solape
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: Palette.mint.withOpacity(.15),
                foregroundColor: Palette.brown,
                child: Icon(icon),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$dayLabel  •  $date',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Palette.brown,
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 6),

            Text(
              place,
              style: GoogleFonts.lora(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Palette.brown,
              ),
            ),

            const SizedBox(height: 8),

            // Bullets con un pequeño espacio entre líneas
            ...bullets
                .where((t) => t.trim().isNotEmpty)
                .map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Bullet(t),
            )),

            // Separación clara antes de los chips
            if (tags.isNotEmpty) const SizedBox(height: 10),

            // 👇 Nada de valores negativos: runSpacing positivo evita solapes en la 2ª fila
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .where((t) => t.trim().isNotEmpty)
                    .map((t) => ChipTag(text: t))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
