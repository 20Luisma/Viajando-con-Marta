import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/palette.dart';
import '../../../shared/widgets/bullets.dart';
import '../../../shared/widgets/chips.dart';

class PracticeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> bullets;
  final List<String> tags;

  const PracticeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.bullets,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                child: Text(title,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Palette.brown),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ...bullets.map((t) => Bullet(t)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: -6, children: tags.map((t) => ChipTag(text: t)).toList()),
          ],
        ),
      ),
    );
  }
}
