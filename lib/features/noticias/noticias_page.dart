import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ⬅️ para marcar leídas
import 'package:url_launcher/url_launcher.dart'; // ⬅️ abrir enlaces
import '../../theme/palette.dart';

class NoticiasPage extends StatefulWidget {
  const NoticiasPage({super.key, required this.tripId});
  final String tripId;

  @override
  State<NoticiasPage> createState() => _NoticiasPageState();
}

class _NoticiasPageState extends State<NoticiasPage> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'General';

  final List<String> _categories = const [
    'General', 'Vuelos', 'Visados', 'Salud', 'Seguridad', 'Clima', 'Pagos', // 👈 añadida
  ];

  // Stream en tiempo real de Firestore
  Stream<List<_NewsItem>> _stream() {
    final q = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('news')
        .orderBy('publishedAt', descending: true) // un solo orderBy → sin índice compuesto
        .snapshots();

    return q.map((snap) =>
        snap.docs.map((d) => _NewsItem.fromJson(d.data(), d.id)).toList());
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    // Sin snackbars de notificación dentro de la app, como pediste.
  }

  // ⬇️⬇️ marcar una noticia como leída (para que baje el numerito)
  Future<void> markNewsRead(String tripId, String newsId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('tripStates').doc(tripId)
        .collection('readNews').doc(newsId)
        .set({'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Noticias',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Palette.brown,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Guardar búsqueda',
            onPressed: () {},
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: StreamBuilder<List<_NewsItem>>(
          stream: _stream(),
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final items = (snapshot.data ?? []);

            // Filtro local: visible + categoría + búsqueda
            final q = _searchCtrl.text.trim().toLowerCase();
            final filtered = items.where((n) {
              if (n.visible == false) return false;
              final byCat = _selectedCategory == 'General'
                  ? true
                  : n.category == _selectedCategory;
              final byQuery = q.isEmpty ||
                  n.title.toLowerCase().contains(q) ||
                  n.excerpt.toLowerCase().contains(q) ||
                  n.tag.toLowerCase().contains(q);
              return byCat && byQuery;
            }).toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: _CategoryChips(
                    categories: _categories,
                    selected: _selectedCategory,
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                if (loading && items.isEmpty)
                  const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyCard(),
                    ),
                  )
                else
                  SliverList.separated(
                    itemBuilder: (context, i) {
                      final it = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _FeaturedCard(
                          item: it,
                          onOpen: () async {
                            await markNewsRead(widget.tripId, it.id);
                            if (!context.mounted) return;
                            _openNews(context, it);
                          },
                          onDownload: (it.downloadUrl == null)
                              ? null
                              : () => _launchExternal(context, it.downloadUrl!),
                          onOpenUrl: (it.actionUrl == null)
                              ? null
                              : () => _launchExternal(context, it.actionUrl!),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemCount: filtered.length,
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openNews(BuildContext context, _NewsItem it) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _NoticiasDetallePage(item: it)),
    );
  }
}

/* ----------------------------- Helpers enlaces ---------------------------- */

Uri? _sanitizedUri(String raw) {
  var u = raw.trim();
  if (u.isEmpty) return null;
  if (!u.contains('://')) u = 'https://$u'; // añade esquema si falta
  return Uri.tryParse(u);
}

Future<void> _launchExternal(BuildContext context, String url) async {
  final uri = _sanitizedUri(url);
  if (uri == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Enlace no válido')));
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('No se pudo abrir: $url')));
  }
}

/* ----------------------------- Widgets UI -------------------------------- */

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sin resultados',
              style: GoogleFonts.lora(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Prueba con otras palabras o cambia la categoría.',
            style: GoogleFonts.poppins(height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar noticias, vuelos, visados...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Palette.mint, width: 1.6),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) {
          final c = categories[i];
          final active = c == selected;
          return ChoiceChip(
            label: Text(c),
            selected: active,
            onSelected: (_) => onChanged(c),
            labelStyle: GoogleFonts.poppins(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
            selectedColor: Palette.mint.withOpacity(.18),
            side: BorderSide(
              color: active ? Palette.mint : Colors.black12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.item,
    required this.onOpen,
    this.onDownload,
    this.onOpenUrl,
  });

  final _NewsItem item;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final hasImg = item.image.trim().isNotEmpty;

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImg) ...[
            _NewsImage(imageUrl: item.image, height: 200),
            const SizedBox(height: 12),
          ],
          _MetaRow(item: item),
          const SizedBox(height: 6),
          Text(
            item.title,
            style: GoogleFonts.lora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Palette.brown,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.excerpt,
            style: GoogleFonts.poppins(
              height: 1.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _DynamicActions(
            hasDownload: onDownload != null,
            hasUrl: onOpenUrl != null,
            onOpen: onOpen,
            onDownload: onDownload,
            onOpenUrl: onOpenUrl,
          ),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _NewsImage extends StatelessWidget {
  const _NewsImage({required this.imageUrl, required this.height});
  final String imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hasImg = imageUrl.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: hasImg
            ? Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (c, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black12,
                child: const Center(
                    child: Icon(Icons.broken_image_outlined)),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const _BadgeText('Noticia'),
              ),
            )
          ],
        )
            : Container(color: Colors.black12),
      ),
    );
  }
}

class _BadgeText extends StatelessWidget {
  const _BadgeText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final _NewsItem item;

  String _formatDate(DateTime d) {
    const months = [
      'Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.mint.withOpacity(.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        item.tag,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Palette.mint.darken(),
        ),
      ),
    );

    final dateRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 14, color: Colors.black.withOpacity(.6)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            _formatDate(item.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );

    final catRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.label_outline, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            item.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxChunk = (constraints.maxWidth - 24) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            chip,
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxChunk),
              child: dateRow,
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxChunk),
              child: catRow,
            ),
          ],
        );
      },
    );
  }
}

class _DynamicActions extends StatelessWidget {
  const _DynamicActions({
    required this.hasDownload,
    required this.hasUrl,
    this.onOpen,
    this.onDownload,
    this.onOpenUrl,
  });

  final bool hasDownload;
  final bool hasUrl;
  final VoidCallback? onOpen;
  final VoidCallback? onDownload;
  final VoidCallback? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (hasDownload && onDownload != null) {
      buttons.add(_ActionBtn(
        icon: Icons.download_outlined,
        label: 'Descargar',
        onTap: onDownload!,
      ));
    }
    if (hasUrl && onOpenUrl != null) {
      buttons.add(_ActionBtn(
        icon: Icons.link_outlined,
        label: 'Ir al sitio',
        onTap: onOpenUrl!,
      ));
    }
    if (onOpen != null) {
      buttons.add(_ActionBtn(
        icon: Icons.open_in_new,
        label: 'Abrir',
        onTap: onOpen!,
      ));
    }

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < buttons.length; i++) ...[
              if (i == 0) const SizedBox(width: 2),
              buttons[i],
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Detalle ----------------------------------- */

class _NoticiasDetallePage extends StatefulWidget {
  const _NoticiasDetallePage({required this.item});
  final _NewsItem item;

  @override
  State<_NoticiasDetallePage> createState() => _NoticiasDetallePageState();
}

class _NoticiasDetallePageState extends State<_NoticiasDetallePage> {
  final ScrollController _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Desplaza un poco al abrir para evitar solapes con UI nativa (notch/gestures).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // desplazamiento inicial ~72 px (ajustado si hay padding superior del sistema)
      final topInset = MediaQuery.of(context).viewPadding.top;
      _ctrl.jumpTo(72.0 + (topInset > 0 ? 8.0 : 0.0));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasImg = item.image.trim().isNotEmpty;

    // Padding inferior seguro para no quedar debajo de la barra nativa.
    final bottomSafe = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        title: const Text('Detalle'),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        controller: _ctrl,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomSafe),
        children: [
          Text(
            item.title,
            style: GoogleFonts.lora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Palette.brown,
            ),
          ),
          const SizedBox(height: 8),
          _MetaRow(item: item),
          if (hasImg) ...[
            const SizedBox(height: 12),
            _NewsImage(imageUrl: item.image, height: 220),
          ],
          const SizedBox(height: 16),
          _DynamicActions(
            hasDownload: item.downloadUrl != null,
            hasUrl: item.actionUrl != null,
            onOpen: null,
            onDownload: item.downloadUrl == null
                ? null
                : () => _launchExternal(context, item.downloadUrl!),
            onOpenUrl: item.actionUrl == null
                ? null
                : () => _launchExternal(context, item.actionUrl!),
          ),
          const SizedBox(height: 16),
          Text(item.body, style: GoogleFonts.poppins(height: 1.6)),
        ],
      ),
    );
  }
}

/* ------------------------------ Modelo ------------------------------------ */

class _NewsItem {
  final String id;
  final String title;
  final String excerpt;
  final String body;
  final String image;
  final DateTime date;
  final String category;
  final String tag;
  final String? downloadUrl; // null si vacío → no mostrar botón
  final String? actionUrl;   // null si vacío → no mostrar botón
  final bool visible;

  _NewsItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.image,
    required this.date,
    required this.category,
    required this.tag,
    required this.visible,
    this.downloadUrl,
    this.actionUrl,
  });

  factory _NewsItem.fromJson(Map<String, dynamic> j, String id) => _NewsItem(
    id: id,
    title: j['title'] ?? '',
    excerpt: j['excerpt'] ?? '',
    body: j['body'] ?? '',
    image: j['imageUrl'] ?? '',
    date: _toDate(j['publishedAt']) ?? DateTime.now(),
    category: j['category'] ?? 'General',
    tag: j['tag'] ?? 'Info',
    downloadUrl: _nz(j['downloadUrl']),
    actionUrl: _nz(j['actionUrl']),
    visible: (j['visible'] ?? true) as bool,
  );
}

/* ----------------------------- Helpers ------------------------------------ */

String? _nz(dynamic v) {
  final s = (v as String?)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  if (v is Timestamp) return v.toDate(); // por si llega como Timestamp
  return null;
}

extension _ColorX on Color {
  Color darken([double amount = .12]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark =
    hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
