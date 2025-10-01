# 📖 Viajando con Marta — README_DEV

Este documento describe la **estructura actual del proyecto Flutter**, sus **dependencias**, y los **próximos pasos de desarrollo**.  
Está pensado para que cualquier desarrollador o IA pueda entender rápidamente cómo está organizado el proyecto.

---

## 🚀 Estado actual

El proyecto **Viajando con Marta** ya tiene:

- **Pantalla de splash** con sonido e intro.  
- **Pantalla de login** (mock local, lista para migrar a Firebase).  
- **Pantalla principal (`HomeScreen`)** con **NavigationBar** de 4 secciones:
  1. **Mi viaje** → Itinerario, Galería, Transporte, Alojamiento.  
  2. **Info útil** → Datos prácticos, Equipaje, Guía de buenas prácticas, Idioma.  
  3. **Trámites** → Visado, Trámites y gestiones, Documentación, Seguro médico.  
  4. **Chat** → Placeholder.  

Además, cada sección tiene ya su archivo propio y estilos coherentes.

---

## 📂 Estructura de carpetas

```bash
lib/
├── main.dart                # Punto de entrada, SplashScreen y rutas
├── theme/
│   └── palette.dart         # Paleta de colores globales (arena, marrón, menta)
├── login_screen.dart        # Pantalla de login
├── home/
│   ├── home_screen.dart     # Home principal con NavigationBar
│   └── widgets/             # Widgets compartidos de Home
│       ├── quick_tile.dart
│       └── welcome_card.dart
└── features/                # Cada sección modularizada
    ├── mi_viaje/
    │   ├── itinerario_page.dart
    │   ├── galeria_page.dart
    │   ├── transporte_page.dart
    │   └── alojamiento_page.dart
    ├── info_util/
    │   ├── datos_practicos_page.dart
    │   ├── equipaje_page.dart
    │   ├── guia_buenas_practicas_page.dart
    │   └── idioma_page.dart
    ├── tramites/
    │   ├── visado_page.dart
    │   ├── tramites_gestion_page.dart
    │   ├── documentacion_page.dart
    │   └── seguro_medico_page.dart
    └── chat/
        └── chat_page.dart

assets/
├── audio/
│   └── selva.mp3            # Audio del splash
└── images/
    ├── intro.png            # Imagen de bienvenida en splash
    ├── pasaporte.png        # Marca de agua en WelcomeCard
    ├── logo.png             # Logo de la app
    └── ... otras imágenes
```

---

## 🎨 Estilos globales

- **Fuentes**:  
  - Títulos → `Lora` (elegante, serif).  
  - Texto y UI → `Poppins` (limpia y moderna).  

- **Colores (`palette.dart`)**:  
  - `kSand`  → `#F3E5D0` (arena, fondo)  
  - `kBrown` → `#7A5D48` (marrón dossier)  
  - `kMint`  → `#5FC8B3` (verde/menta turquesa)  

- **UI components compartidos**:  
  - `QuickTile` → accesos rápidos en forma de tarjetas cuadradas.  
  - `WelcomeCard` → tarjeta de bienvenida con marca de agua y franjas de color.  
  - Chips (`ChipTag`) usados en Itinerario, Transporte y Alojamiento.  

---

## 📦 Dependencias (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8
  audioplayers: ^5.2.1
  google_fonts: ^6.2.1

  # Preparado para futuro (no usado aún)
  firebase_core: ^3.4.0
  firebase_auth: ^5.2.1
```

---

## ✅ Avances recientes

- [x] Se corrigieron errores `const` en los `RoundedRectangleBorder`.  
- [x] Se añadió **Transporte** (con texto narrativo sobre vuelos + chips de destinos).  
- [x] Se añadió **Alojamiento** (texto narrativo con secciones por ciudad y campamento).  
- [x] Se movió **Idioma** desde "Mi viaje" a **Info útil**.  
- [x] Se definió estructura `assets/` con subcarpetas `audio/` e `images/`.  

---

## 🔜 Próximos pasos

1. **Firebase**  
   - Migrar login a Firebase Auth.  
   - Configurar Firestore/Realtime DB para guardar contenido dinámico (itinerario, alojamientos, etc.).

2. **Panel de administración (web)**  
   - CRUD para itinerarios, alojamientos, trámites, galería, etc.  
   - Multiusuario con roles (admin / editor).  

3. **Galería**  
   - Subida de fotos y vídeos.  
   - Integración con Firebase Storage.  

4. **Chat**  
   - Reemplazar placeholder con chat real.  
   - Opción de grupos por viaje.  

5. **Extras**  
   - Mapas interactivos.  
   - Descargas offline (PDF, docs).  
   - Multiidioma (español/inglés).  

---

## 📊 Nivel de avance estimado

- App actual: **60% completa**.  
- Panel de control: **0% (por desarrollar)**.  
- Total proyecto (app + panel + backend): **~40% completado**.  

---

👉 Con esta guía, cualquier desarrollador o IA puede:  
- Entender la estructura del proyecto.  
- Saber qué dependencias tiene.  
- Localizar rápido dónde editar o añadir funciones.  
- Tener claro qué falta para llegar al 100%.
