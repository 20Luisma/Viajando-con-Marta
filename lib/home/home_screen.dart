// lib/home/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../theme/palette.dart';

// Páginas
import '../features/itinerario/itinerario_page.dart';
import '../features/info_util/datos_practicos_page.dart';
import '../features/info_util/equipaje_page.dart';
import '../features/info_util/guia_buenas_practicas_page.dart';
import '../features/idioma/idioma_page.dart';
import '../features/tramites/visado_page.dart';
import '../features/tramites/documentacion_page.dart';
import '../features/tramites/seguro_medico_page.dart';
import '../features/galeria/galeria_page.dart';
import '../features/mi_viaje/transporte_page.dart';
import '../features/mi_viaje/alojamiento_page.dart';
import '../features/info_util/ong_page.dart';
import '../features/info_util/mapas_page.dart';
import '../features/noticias/noticias_page.dart';
import '../features/tramites/vuelos_page.dart';

// Widgets
import 'widgets/quick_tile.dart';
import 'widgets/welcome_slides.dart';

/// Suscripción al topic del viaje para recibir notificaciones push
Future<void> subscribeTrip(String tripId) async {
  final topic = 'news_trip_${tripId.replaceAll(' ', '_')}';
  await FirebaseMessaging.instance.subscribeToTopic(topic);
  debugPrint('✅ Subscrito al topic: $topic');
}

class HomeItem {
  final String id;
  final String title;
  final String icon;
  final String section;
  final String route;
  final int order;
  final bool visible;

  HomeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.section,
    required this.route,
    this.order = 999,
    this.visible = true,
  });

  factory HomeItem.fromJson(Map<String, dynamic> j) => HomeItem(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    icon: (j['icon'] ?? 'info_outline').toString(),
    section: (j['section'] ?? 'mi_viaje').toString(),
    route: (j['route'] ?? '').toString(),
    order: (j['order'] is int)
        ? (j['order'] as int)
        : (int.tryParse('${j['order']}') ?? 999),
    visible: (j['visible'] is bool)
        ? (j['visible'] as bool)
        : ((j['visible']?.toString().toLowerCase() ?? '') == 'true'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'icon': icon,
    'section': section,
    'route': route,
    'order': order,
    'visible': visible,
  };
}

Future<List<HomeItem>> fetchHomeItems() async {
  return [
    HomeItem(
      id: 'itinerario',
      title: 'Itinerario',
      icon: 'route',
      section: 'mi_viaje',
      route: 'itinerario_page',
      order: 1,
    ),
    HomeItem(
      id: 'galeria',
      title: 'Galería',
      icon: 'photo_library_outlined',
      section: 'mi_viaje',
      route: 'galeria_page',
      order: 2,
    ),
    HomeItem(
      id: 'transporte',
      title: 'Transporte',
      icon: 'directions_car_filled_outlined',
      section: 'mi_viaje',
      route: 'transporte_page',
      order: 3,
    ),
    HomeItem(
      id: 'alojamiento',
      title: 'Alojamiento',
      icon: 'hotel_outlined',
      section: 'mi_viaje',
      route: 'alojamiento_page',
      order: 4,
    ),

    // Info útil
    HomeItem(
      id: 'datos',
      title: 'Datos prácticos',
      icon: 'public',
      section: 'info_util',
      route: 'datos_practicos_page',
      order: 1,
    ),
    HomeItem(
      id: 'equipaje',
      title: 'Equipaje',
      icon: 'backpack_outlined',
      section: 'info_util',
      route: 'equipaje_page',
      order: 2,
    ),
    HomeItem(
      id: 'buenas',
      title: 'Buenas prácticas',
      icon: 'volunteer_activism_outlined',
      section: 'info_util',
      route: 'guia_buenas_practicas_page',
      order: 3,
    ),
    HomeItem(
      id: 'idioma',
      title: 'Idioma',
      icon: 'language',
      section: 'info_util',
      route: 'idioma_page',
      order: 4,
    ),
    HomeItem(
      id: 'mapas',
      title: 'Mapas',
      icon: 'map_outlined',
      section: 'info_util',
      route: 'mapas_page',
      order: 5,
    ),
    HomeItem(
      id: 'ong',
      title: 'ONG',
      icon: 'group_outlined',
      section: 'info_util',
      route: 'ong_page',
      order: 6,
    ),

    // Trámites
    HomeItem(
      id: 'visado',
      title: 'Visado',
      icon: 'assignment_ind_outlined',
      section: 'tramites',
      route: 'visado_page',
      order: 1,
    ),
    HomeItem(
      id: 'vuelos',
      title: 'Vuelos',
      icon: 'flight_takeoff_outlined',
      section: 'tramites',
      route: 'vuelos_page',
      order: 2,
    ),
    HomeItem(
      id: 'seguro',
      title: 'Seguro médico',
      icon: 'health_and_safety_outlined',
      section: 'tramites',
      route: 'seguro_medico_page',
      order: 3,
    ),
    HomeItem(
      id: 'docs',
      title: 'Documentación',
      icon: 'description_outlined',
      section: 'tramites',
      route: 'documentacion_page',
      order: 99,
    ),
  ];
}

IconData _iconFrom(String name) {
  const map = <String, IconData>{
    'route': Icons.route,
    'photo_library_outlined': Icons.photo_library_outlined,
    'directions_car_filled_outlined': Icons.directions_car_filled_outlined,
    'hotel_outlined': Icons.hotel_outlined,
    'public': Icons.public,
    'backpack_outlined': Icons.backpack_outlined,
    'volunteer_activism_outlined': Icons.volunteer_activism_outlined,
    'group_outlined': Icons.group_outlined,
    'language': Icons.language,
    'map_outlined': Icons.map_outlined,
    'airplane_ticket_outlined': Icons.airplane_ticket_outlined,
    'approval_outlined': Icons.approval_outlined,
    'description_outlined': Icons.description_outlined,
    'health_and_safety_outlined': Icons.health_and_safety_outlined,
    'flight_takeoff_outlined': Icons.flight_takeoff_outlined,
    'assignment_ind_outlined': Icons.assignment_ind_outlined,
    'info_outline': Icons.info_outline,
  };
  return map[name] ?? Icons.help_outline;
}

Widget _openPage(String route, String tripId) {
  switch (route) {
    case 'itinerario_page':
      return ItinerarioPage(tripId: tripId);
    case 'galeria_page':
      return GaleriaPage(tripId: tripId);
    case 'transporte_page':
      return TransportePage(tripId: tripId);
    case 'alojamiento_page':
      return AlojamientoPage(tripId: tripId);
    case 'datos_practicos_page':
      return DatosPracticosPage(tripId: tripId);
    case 'equipaje_page':
      return EquipajePage(tripId: tripId);
    case 'guia_buenas_practicas_page':
      return GuiaBuenasPracticasPage(tripId: tripId);
    case 'idioma_page':
      return IdiomaPage(tripId: tripId);
    case 'mapas_page':
      return MapasPage(tripId: tripId);
    case 'ong_page':
      return OngPage(tripId: tripId);
    case 'visado_page':
      return VisadoPage(tripId: tripId);
    case 'vuelos_page':
      return VuelosPage(tripId: tripId);
    case 'documentacion_page':
      return DocumentacionPage(tripId: tripId);
    case 'seguro_medico_page':
      return SeguroMedicoPage(tripId: tripId);
    case 'noticias_page':
      return NoticiasPage(tripId: tripId);
    default:
      return const Scaffold(body: Center(child: Text('Página no encontrada')));
  }
}

int _gridColumnsAlways(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 1100) return 5;
  if (w >= 900) return 4;
  if (w >= 700) return 3;
  return 2;
}

double _tileAspectRatio(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 900) return 1.8;
  if (w >= 700) return 1.7;
  return 1.6;
}

Widget _tramitesHeader() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 200,
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
      child: Image.asset(
        'assets/images/tramites.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    ),
  );
}

Widget _infoUtilHeader() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 200,
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
      child: Image.asset(
        'assets/images/infoutil.png',
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _current = 0;
  String? _tripId;
  bool _loadingTrip = true;
  String? _loadError;

  // Contador de noticias sin leer = visibles - leídas
  int _unreadNews = 0;
  final Set<String> _visibleNewsIds = <String>{};
  final Set<String> _readNewsIds = <String>{};
  StreamSubscription<QuerySnapshot>? _newsSub;
  StreamSubscription<QuerySnapshot>? _readSub;

  @override
  void initState() {
    super.initState();
    _resolveTripId();

    // Al abrir desde notificación → vamos a Noticias
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      if (!mounted) return;
      setState(() => _current = 3);
    });

    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null && mounted) {
        setState(() => _current = 3);
      }
    });
  }

  @override
  void dispose() {
    _newsSub?.cancel();
    _readSub?.cancel();
    super.dispose();
  }

  Future<void> _resolveTripId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      await user.getIdToken(true);
      final token = await user.getIdTokenResult(true);
      String? tripId = token.claims?['tripId'] as String?;
      debugPrint('🔎 claims tripId = $tripId');

      if (tripId == null || tripId.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = snap.data();
        final trips = (data?['trips'] as List?)?.cast<String>() ?? const [];
        if (trips.isNotEmpty) tripId = trips.first;
        debugPrint('📄 users.trips[0] = $tripId');
      }

      if (!mounted) return;

      // 👉 NO bloquear la UI esperando la suscripción (iOS puede tardar si APNs no está)
      if (tripId != null && tripId.isNotEmpty) {
        // fire-and-forget
        unawaited(subscribeTrip(tripId).catchError((e) {
          debugPrint('⚠️ Error al suscribirse al topic: $e');
        }));
        _startUnreadWatchers(tripId); // badge en vivo
      }

      setState(() {
        _tripId = tripId;
        _loadingTrip = false;
      });
    } catch (e) {
      debugPrint('❌ _resolveTripId error: $e');
      if (!mounted) return;
      setState(() {
        _loadError = 'No pudimos cargar tu viaje.';
        _loadingTrip = false;
      });
    }
  }

  /// Cuenta pendientes = noticias visibles - noticias leídas (readNews)
  void _startUnreadWatchers(String tripId) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _newsSub?.cancel();
    _readSub?.cancel();

    _newsSub = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('news')
        .where('visible', isEqualTo: true)
        .snapshots()
        .listen((qs) {
      _visibleNewsIds
        ..clear()
        ..addAll(qs.docs.map((d) => d.id));
      _recalcUnread();
    }, onError: (e) => debugPrint('⚠️ news stream error: $e'));

    _readSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tripStates')
        .doc(tripId)
        .collection('readNews')
        .snapshots()
        .listen((qs) {
      _readNewsIds
        ..clear()
        ..addAll(qs.docs.map((d) => d.id));
      _recalcUnread();
    }, onError: (e) => debugPrint('⚠️ readNews stream error: $e'));
  }

  void _recalcUnread() {
    final pending = _visibleNewsIds.difference(_readNewsIds).length;
    if (mounted) setState(() => _unreadNews = pending);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTrip) {
      return const Scaffold(
        backgroundColor: Palette.sand,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: Palette.sand,
        body: Center(child: Text(_loadError!)),
      );
    }
    if (_tripId == null || _tripId!.isEmpty) {
      return const Scaffold(
        backgroundColor: Palette.sand,
        body: Center(child: Text('No tienes un viaje asignado.')),
      );
    }

    final pages = <Widget>[
      _MiViajePage(tripId: _tripId!),
      _InfoUtilPage(tripId: _tripId!),
      _TramitesPage(tripId: _tripId!),
      NoticiasPage(tripId: _tripId!),
    ];

    return Scaffold(
      backgroundColor: Palette.sand,
      body: SafeArea(child: pages[_current]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _current,
        onDestinationSelected: (i) => setState(() => _current = i),
        indicatorColor: Palette.mint.withOpacity(.18),
        backgroundColor: Colors.white,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Mi viaje',
          ),
          const NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info útil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Trámites',
          ),
          // Badge en Noticias (se oculta cuando _unreadNews == 0)
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadNews > 0,
              label: Text('$_unreadNews'),
              child: const Icon(Icons.article_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadNews > 0,
              label: Text('$_unreadNews'),
              child: const Icon(Icons.article),
            ),
            label: 'Noticias',
          ),
        ],
      ),
    );
  }
}

/* ===================== Secciones (sin cambios) ===================== */

class _MiViajePage extends StatelessWidget {
  const _MiViajePage({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeItem>>(
      future: fetchHomeItems(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snap.data ?? [])
            .where((e) => e.visible && e.section == 'mi_viaje')
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final cols = _gridColumnsAlways(context);
        final ar = _tileAspectRatio(context);

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: WelcomeSlides(tripId: tripId)),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: ar,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final item = items[i];
                    return QuickTile(
                      title: item.title,
                      icon: _iconFrom(item.icon),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _openPage(item.route, tripId),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoUtilPage extends StatelessWidget {
  const _InfoUtilPage({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeItem>>(
      future: fetchHomeItems(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snap.data ?? [])
            .where((e) => e.visible && e.section == 'info_util')
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final cols = _gridColumnsAlways(context);
        final ar = _tileAspectRatio(context);

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: _InfoUtilHeaderSlot()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: ar,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final item = items[i];
                    return QuickTile(
                      title: item.title,
                      icon: _iconFrom(item.icon),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _openPage(item.route, tripId),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoUtilHeaderSlot extends StatelessWidget {
  const _InfoUtilHeaderSlot();
  @override
  Widget build(BuildContext context) => _infoUtilHeader();
}

class _TramitesPage extends StatelessWidget {
  const _TramitesPage({required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HomeItem>>(
      future: fetchHomeItems(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = (snap.data ?? [])
            .where((e) => e.visible && e.section == 'tramites')
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        final cols = _gridColumnsAlways(context);
        final ar = _tileAspectRatio(context);

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _tramitesHeader()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: ar,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    final item = items[i];
                    return QuickTile(
                      title: item.title,
                      icon: _iconFrom(item.icon),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _openPage(item.route, tripId),
                        ),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
