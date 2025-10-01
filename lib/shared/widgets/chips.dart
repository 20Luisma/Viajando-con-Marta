import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/palette.dart';

class ChipTag extends StatelessWidget {
  final String text;
  const ChipTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: GoogleFonts.poppins(fontSize: 12)),
      backgroundColor: Palette.mint.withOpacity(.18),
      side: BorderSide(color: Palette.mint.withOpacity(.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
