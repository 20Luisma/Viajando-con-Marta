import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:dio/dio.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../theme/palette.dart';

/* ================== Config ================== */
// Subcolección donde el panel guarda las fotos de grupo
const String kGallerySubcollection = 'group_gallery';

// 🔓 Subidas habilitadas
const bool kDisableUploads = false;

/* ================== Modelo ================== */
class GroupPhoto {
  final String id;
  final String url;
  final String caption;
  final String authorName;
  final bool consent;
  final bool visible;
  final int order;
  final DateTime? createdAt;
  final String storagePath;

  const GroupPhoto({
    required this.id,
    required this.url,
    required this.caption,
    required this.authorName,
    required this.consent,
    required this.visible,
    required this.order,
    required this.createdAt,
    required this.storagePath,
  });

  factory GroupPhoto.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final j = d.data() ?? {};
    return GroupPhoto(
      id: d.id,
      url: (j['url'] ?? '').toString(),
      caption: (j['caption'] ?? '').toString(),
      authorName: (j['authorName'] ?? '').toString(),
      consent: (j['consent'] is bool)
          ? j['consent'] as bool
          : (j['consent']?.toString().toLowerCase() == 'true'),
      visible: (j['visible'] is bool)
          ? j['visible'] as bool
          : (j['visible']?.toString().toLowerCase() == 'true'),
      order: (j['order'] is int)
          ? j['order'] as int
          : (int.tryParse('${j['order']}') ?? 999),
      createdAt: (j['createdAt'] is Timestamp)
          ? (j['createdAt'] as Timestamp).toDate()
          : null,
      storagePath: (j['storagePath'] ?? '').toString(),
    );
  }
}

/* ================== Stream de fotos ================== */
Stream<List<GroupPhoto>> _watchGroupPhotos({required String tripId}) {
  final ref = FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection(kGallerySubcollection)
      .orderBy('createdAt', descending: true);

  return ref.snapshots().map((snap) {
    final items = snap.docs
        .map((d) => GroupPhoto.fromDoc(d))
        .where((p) => p.url.isNotEmpty && p.consent == true && p.visible != false)
        .toList();
    return items;
  });
}

/* ================== Tarjeta reutilizable ================== */
class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _SectionCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
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
      child: child,
    );
  }
}

/* ================== Página principal ================== */
class GaleriaPage extends StatefulWidget {
  const GaleriaPage({super.key, required this.tripId});
  final String tripId;

  @override
  State<GaleriaPage> createState() => _GaleriaPageState();
}

class _GaleriaPageState extends State<GaleriaPage> {
  final _picker = ImagePicker();
  bool _uploading = false;
  double _progress = 0;

  // --- Menú / Selección
  bool _menuOpen = false;
  bool _selectMode = false;
  final Set<String> _selected = {};
  List<GroupPhoto> _lastItems = const [];

  // Descarga
  bool _downloading = false;
  double _downloadProgress = 0;

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);
  void _enterSelectMode([GroupPhoto? p]) {
    setState(() {
      _selectMode = true;
      _menuOpen = false;
      if (p != null) _selected.add(p.id);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
      _menuOpen = false;
    });
  }

  void _toggleSelected(GroupPhoto p) {
    setState(() {
      if (_selected.contains(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected.add(p.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectMode = true;
      _selected
        ..clear()
        ..addAll(_lastItems.map((e) => e.id));
      _menuOpen = false;
    });
  }

  /* ====== Permiso y guardado con photo_manager ====== */
  Future<bool> _ensurePhotoPermission() async {
    final result = await PhotoManager.requestPermissionExtend();
    // photo_manager 3.7.x NO tiene isLimited
    final ok = result.isAuth || result.hasAccess;
    if (ok) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permiso de Fotos denegado. Abre Ajustes para concederlo.'),
          action: SnackBarAction(label: 'Ajustes', onPressed: PhotoManager.openSetting),
        ),
      );
    }
    return false;
  }

  Future<bool> _saveToGallery(String url, {String? name}) async {
    try {
      final dio = Dio();
      final resp = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes, followRedirects: true),
      );
      final bytes = Uint8List.fromList(resp.data ?? []);
      if (bytes.isEmpty) return false;

      final title = (name ?? 'viajando_${DateTime.now().millisecondsSinceEpoch}')
          .replaceAll(' ', '_');

      // photo_manager 3.x: usar filename
      final asset = await PhotoManager.editor.saveImage(
        bytes,
        filename: '$title.jpg',
      );
      return asset != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _downloadSelected() async {
    final n = _selected.length;
    if (n == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos una foto.')),
      );
      return;
    }

    // Intentar obtener permiso
    bool granted = await _ensurePhotoPermission();

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _menuOpen = false;
    });

    // Mapa rápido id->photo
    final map = {for (final p in _lastItems) p.id: p};
    final ids = _selected.toList();
    int ok = 0;

    // Modal con progreso
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setM) {
            Future<void> run() async {
              for (int i = 0; i < ids.length; i++) {
                final p = map[ids[i]];
                if (p == null) continue;

                bool saved = await _saveToGallery(
                  p.url,
                  name: p.caption.isNotEmpty ? p.caption : null,
                );

                if (!saved && !granted) {
                  await PhotoManager.openSetting();
                  final r = await PhotoManager.requestPermissionExtend();
                  granted = r.isAuth || r.hasAccess;
                  if (granted) {
                    saved = await _saveToGallery(
                      p.url,
                      name: p.caption.isNotEmpty ? p.caption : null,
                    );
                  }
                }

                if (saved) ok++;
                final prog = (i + 1) / ids.length;
                if (mounted) {
                  setState(() => _downloadProgress = prog);
                }
                setM(() {});
              }
              if (mounted) Navigator.of(ctx).pop();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_downloading && _downloadProgress == 0) run();
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Descargando fotos',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: (_downloadProgress == 0 || _downloadProgress >= 1.0)
                        ? null
                        : _downloadProgress,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${(_downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)} %',
                    style: GoogleFonts.poppins(fontSize: 13.5),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    setState(() {
      _downloading = false;
      _downloadProgress = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descargadas $ok de $n foto${n == 1 ? '' : 's'} en tu galería.')),
    );
  }

  /* ====== Subida: cámara / galería ====== */
  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2560,
      );
      if (x == null) return;
      if (!mounted) return;
      await _openUploadSheet(x);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir ${source == ImageSource.camera ? 'la cámara' : 'la galería'}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _openUploadSheet(XFile picked) async {
    final captionCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    bool consent = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
          child: StatefulBuilder(
            builder: (ctx, setM) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    width: 48,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Palette.mint.withOpacity(.15),
                        foregroundColor: Palette.brown,
                        child: const Icon(Icons.photo_camera, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Nueva foto de grupo',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: Palette.brown,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(picked.path),
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: captionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Título / caption (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: authorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre (para mostrar como autor)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: consent,
                        onChanged: (v) => setM(() => consent = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          'Declaro que tengo consentimiento para publicar esta imagen y que las personas reconocibles han aceptado aparecer en la galería del viaje.',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: const Color(0xFF333333),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_uploading)
                    LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _uploading ? null : () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.brown,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: (kDisableUploads || _uploading)
                              ? null
                              : () async {
                            Navigator.pop(ctx);
                            await _doUpload(
                              tripId: widget.tripId,
                              picked: picked,
                              caption: captionCtrl.text.trim(),
                              authorName: authorCtrl.text.trim(),
                              consent: consent,
                            );
                          },
                          child: Text(kDisableUploads ? 'Publicar (off)' : 'Publicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _doUpload({
    required String tripId,
    required XFile picked,
    required String caption,
    required String authorName,
    required bool consent,
  }) async {
    try {
      setState(() {
        _uploading = true;
        _progress = 0;
      });

      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File(picked.path);
      final fileName = picked.name;
      final storagePath = 'trips/$tripId/$kGallerySubcollection/${ts}_$fileName';

      final ref = FirebaseStorage.instance.ref(storagePath);
      final task = ref.putFile(file);

      task.snapshotEvents.listen((s) {
        if (!mounted) return;
        final double v = s.totalBytes > 0 ? s.bytesTransferred / s.totalBytes : 0.0;
        setState(() => _progress = v);
      });

      final snap = await task.whenComplete(() {});
      final url = await snap.ref.getDownloadURL();

      final col = FirebaseFirestore.instance
          .collection('trips')
          .doc(tripId)
          .collection(kGallerySubcollection);

      await col.add({
        'url': url,
        'caption': caption,
        'authorName': authorName,
        'consent': consent,
        'visible': true,
        'order': ts,
        'createdAt': FieldValue.serverTimestamp(),
        'storagePath': storagePath,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto publicada ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _progress = 0;
        });
      }
    }
  }

  void _openViewer(GroupPhoto p) {
    if (_selectMode) {
      _toggleSelected(p);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _FullImagePage(photo: p)),
      );
    }
  }

  int _crossAxisCountForWidth(double w) {
    if (w >= 1200) return 5;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    // === Evitar solapes con barra nativa de Android / gestos ===
    final safeBottom = MediaQuery.of(context).padding.bottom; // notches/gestos
    final viewBottom = MediaQuery.of(context).viewPadding.bottom; // iOS home bar
    final fabBottom =
        16.0 + (safeBottom > 0 ? safeBottom : (viewBottom > 0 ? viewBottom : 12.0));
    final listBottomReserve = fabBottom + 72.0; // espacio para que no tape el FAB/menú

    return Scaffold(
      backgroundColor: Palette.sand,
      appBar: AppBar(
        backgroundColor: Palette.sand,
        elevation: 0,
        centerTitle: !_selectMode,
        leading: _selectMode
            ? IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectMode,
        )
            : null,
        title: _selectMode
            ? Text(
          '${_selected.length} seleccionada${_selected.length == 1 ? '' : 's'}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Palette.brown,
          ),
        )
            : Text(
          'Galería',
          style: GoogleFonts.lora(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Palette.brown,
          ),
        ),
        actions: _selectMode
            ? [
          IconButton(
            tooltip: 'Seleccionar todo',
            icon: const Icon(Icons.done_all),
            onPressed: _lastItems.isEmpty ? null : _selectAll,
          ),
        ]
            : null,
      ),
      body: Stack(
        children: [
          // ===== Contenido =====
          StreamBuilder<List<GroupPhoto>>(
            stream: _watchGroupPhotos(tripId: widget.tripId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              _lastItems = items;

              final lastAt = items.isNotEmpty ? items.first.createdAt : null;

              return LayoutBuilder(
                builder: (_, c) {
                  final cross = _crossAxisCountForWidth(c.maxWidth);
                  return ListView(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, listBottomReserve),
                    children: [
                      // Banner bonito
                      _SectionCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Palette.mint.withOpacity(.18),
                              foregroundColor: Palette.brown,
                              child: const Icon(Icons.emoji_emotions_outlined, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sube tus mejores momentos ✨',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Comparte tus fotos favoritas del viaje con el grupo.',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Cabecera (stats)
                      _SectionCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Palette.mint.withOpacity(.18),
                              foregroundColor: Palette.brown,
                              child: const Icon(Icons.photo_library, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Galería del grupo',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Palette.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fotos: ${items.length}'
                                        '${lastAt != null ? ' · Última: ${lastAt.toLocal().toString().split(' ').first}' : ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: Color(0xFF444444),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (items.isEmpty)
                        _emptyBox()
                      else
                        _SectionCard(
                          padding: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemBuilder: (_, i) {
                                final p = items[i];
                                final selected = _selected.contains(p.id);
                                return _PhotoTile(
                                  p: p,
                                  selected: selected,
                                  selectMode: _selectMode,
                                  onTap: () => _openViewer(p),
                                  onLongPress: () => _enterSelectMode(p),
                                  onToggleSelect: () => _toggleSelected(p),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),

          // ===== Overlay oscuro cuando el menú está abierto =====
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: AnimatedOpacity(
                  opacity: 0.18,
                  duration: const Duration(milliseconds: 120),
                  child: Container(color: Colors.black),
                ),
              ),
            ),

          // ===== FAB y menú, con SafeArea para no solapar =====
          Positioned(
            right: 16,
            bottom: fabBottom,
            child: SafeArea(
              top: false,
              left: false,
              right: true,
              bottom: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: !_menuOpen
                        ? const SizedBox.shrink()
                        : _FabMenu(
                      selectMode: _selectMode,
                      selectedCount: _selected.length,
                      canUpload: !kDisableUploads && !_uploading,
                      onSelect: () => _enterSelectMode(),
                      onSelectAll: _selectAll,
                      onExitSelect: _exitSelectMode,
                      onDownloadSelected: _downloadSelected,
                      onPickGallery: () => _pickAndUpload(ImageSource.gallery),
                      onPickCamera: () => _pickAndUpload(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'fab_main',
                    onPressed: _toggleMenu,
                    backgroundColor: Palette.brown,
                    foregroundColor: Colors.white,
                    child: Icon(_menuOpen ? Icons.close : Icons.menu),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox() {
    return _SectionCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Palette.mint.withOpacity(.18),
            foregroundColor: Palette.brown,
            child: const Icon(Icons.image_outlined, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aún no hay fotos del grupo.\nCuando publiquéis, aparecerán aquí.',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                height: 1.35,
                color: const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ================== Menú flotante (speed-dial) ================== */
class _FabMenu extends StatelessWidget {
  final bool selectMode;
  final int selectedCount;
  final bool canUpload;
  final VoidCallback onSelect;
  final VoidCallback onSelectAll;
  final VoidCallback onExitSelect;
  final VoidCallback onDownloadSelected;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;

  const _FabMenu({
    required this.selectMode,
    required this.selectedCount,
    required this.canUpload,
    required this.onSelect,
    required this.onSelectAll,
    required this.onExitSelect,
    required this.onDownloadSelected,
    required this.onPickGallery,
    required this.onPickCamera,
  });

  Widget _btn({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: Color(0x1F000000)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 260,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!selectMode) ...[
              _btn(
                icon: Icons.checklist_rounded,
                label: 'Seleccionar fotos',
                onPressed: onSelect,
              ),
              _btn(
                icon: Icons.file_upload,
                label: 'Subir desde dispositivo',
                onPressed: canUpload ? onPickGallery : null,
              ),
              _btn(
                icon: Icons.add_a_photo,
                label: 'Cámara',
                onPressed: canUpload ? onPickCamera : null,
              ),
            ] else ...[
              _btn(
                icon: Icons.download,
                label: selectedCount == 0
                    ? 'Descargar seleccionadas'
                    : 'Descargar ($selectedCount)',
                onPressed: selectedCount == 0 ? null : onDownloadSelected,
              ),
              _btn(
                icon: Icons.done_all,
                label: 'Seleccionar todo',
                onPressed: onSelectAll,
              ),
              _btn(
                icon: Icons.close,
                label: 'Salir de selección',
                onPressed: onExitSelect,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ================== Tile de foto ================== */
class _PhotoTile extends StatelessWidget {
  final GroupPhoto p;
  final bool selected;
  final bool selectMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  const _PhotoTile({
    required this.p,
    required this.selected,
    required this.selectMode,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Palette.brown.withOpacity(.8) : Colors.black12;

    return Ink(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: p.url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFFF4F4F4)),
                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
              ),
              // Degradado inferior para el caption
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0, .1),
                        end: Alignment(0, 1),
                        colors: [
                          Colors.transparent,
                          Color.fromARGB(160, 0, 0, 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (p.caption.trim().isNotEmpty)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(.2),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        p.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),

              // Check de selección (arriba a la derecha)
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: selectMode ? 1.0 : 0.0,
                  child: GestureDetector(
                    onTap: onToggleSelect,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: selected ? Palette.brown : Colors.white,
                      foregroundColor: selected ? Colors.white : Colors.black54,
                      child: Icon(
                        selected ? Icons.check : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ================== Visor a pantalla completa ================== */
class _FullImagePage extends StatelessWidget {
  final GroupPhoto photo;
  const _FullImagePage({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: Text(
          photo.authorName.isEmpty ? 'Foto del grupo' : photo.authorName,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 3.0,
            child: CachedNetworkImage(
              imageUrl: photo.url,
              fit: BoxFit.contain,
              placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              errorWidget: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white70, size: 48),
              ),
            ),
          ),
          if (photo.caption.trim().isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  photo.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
