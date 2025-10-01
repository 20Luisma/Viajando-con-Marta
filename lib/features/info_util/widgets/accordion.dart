import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/palette.dart';

class Accordion extends StatefulWidget {
  final String title, body;
  final IconData icon;
  const Accordion({super.key, required this.title, required this.body, required this.icon});

  @override
  State<Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<Accordion> {
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
            title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Palette.brown)),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more, color: Palette.brown),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(widget.body, style: GoogleFonts.poppins(fontSize: 14, height: 1.5)),
            ),
        ],
      ),
    );
  }
}
