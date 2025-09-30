import 'card_camera_screen.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FontFeature; // for tabular figures in grade pill
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as im;

// Enum MUST be top-level in Dart
enum CaptureStep { front, back, busy }

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => CardRepository(),
      child: const VerigradeApp(),
    ),
  );
}

class VerigradeApp extends StatelessWidget {
  const VerigradeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verigrade',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F80ED),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1A2E),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// Reusable gradient (logo blues)
LinearGradient get _verigradeGradient => const LinearGradient(
  colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
// =================== Top carousel ===================

class _TopCarousel extends StatefulWidget {
  const _TopCarousel({super.key});

  @override
  State<_TopCarousel> createState() => _TopCarouselState();
}

class _TopCarouselState extends State<_TopCarousel> {
  late final PageController _pc;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.72);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CardRepository>();
    final graded = repo.items.where((c) => c.grade != null).take(5).toList();
    if (graded.isEmpty) {
      return const SizedBox.shrink(); // nothing to show yet
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: graded.length,
            itemBuilder: (context, i) {
              final item = graded[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                child: _CarouselCardThumb(item: item),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            graded.length,
                (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _page == i ? 18 : 6,
              decoration: BoxDecoration(
                color: _page == i ? const Color(0xFF56CCF2) : Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselCardThumb extends StatelessWidget {
  final CardItem item;
  const _CarouselCardThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    // Frame with subtle gradient border
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardDetailPage(item: item)));
      },
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.5), // gradient outline thickness
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // image
                  if (item.imagePath == null)
                    Container(color: Colors.white12, child: const Icon(Icons.photo, color: Colors.white54))
                  else
                    Image.file(File(item.imagePath!), fit: BoxFit.cover),

                  // bottom gradient & text
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.player.isEmpty ? 'Unknown Player' : item.player,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'BebasNeue', letterSpacing: 1.1, fontSize: 18),
                          ),
                          Text(
                            item.team.isEmpty ? 'Team — ?' : item.team,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // top-right grade pill
                  if (item.grade != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '${item.grade!.overall.toStringAsFixed(2)}  •  ${item.grade!.label}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Gradient-outline pill button (dark fill + glowing border)
class _GradientOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _GradientOutlineButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const border = 2.0; // outline thickness
    final radiusOuter = BorderRadius.circular(18);
    final radiusInner = BorderRadius.circular(16);

    return SizedBox(
      height: 60,
      width: double.infinity,
      child: DecoratedBox(
        // OUTER: the gradient border
        decoration: BoxDecoration(
          gradient: _verigradeGradient,
          borderRadius: radiusOuter,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF56CCF2).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(border),
          // INNER: dark fill
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0B1A2E),
              borderRadius: radiusInner,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radiusInner,
                onTap: onPressed,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 22, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: 'BebasNeue',
                              fontSize: 18,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Homepage
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _button(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return _GradientOutlineButton(icon: icon, label: label, onPressed: onTap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'VERIGRADE',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _verigradeGradient)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 👇 NEW: carousel at top
              const _TopCarousel(),
              const SizedBox(height: 24),

              // existing buttons
              _button(
                context,
                Icons.add_circle,
                'ADD CARD',
                    () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddOrEditCardPage()),
                ),
              ),
              const SizedBox(height: 24),
              _button(
                context,
                Icons.photo_library,
                'MY GALLERY',
                    () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardListPage()),
                ),
              ),
              const SizedBox(height: 24),
              _button(
                context,
                Icons.grade,
                'PSA GRADING CRITERIA',
                    () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PSAInfoPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== Data & grading ===================

class GradeResult {
  double corners;
  double edges;
  double surface;
  double centering;

  GradeResult({
    this.corners = 10,
    this.edges = 10,
    this.surface = 10,
    this.centering = 10,
  });

  double get overall {
    const wCorners = 0.30;
    const wEdges = 0.25;
    const wSurface = 0.25;
    const wCentering = 0.20;
    return (corners * wCorners) + (edges * wEdges) + (surface * wSurface) + (centering * wCentering);
  }

  String get label {
    final g = double.parse(overall.toStringAsFixed(2));
    if (g >= 9.5) return 'Gem Mint 10';
    if (g >= 9.0) return 'Mint 9';
    if (g >= 8.0) return 'NM-MT 8';
    if (g >= 7.0) return 'NM 7';
    if (g >= 6.0) return 'EX-MT 6';
    if (g >= 5.0) return 'EX 5';
    if (g >= 4.0) return 'VG-EX 4';
    if (g >= 3.0) return 'VG 3';
    if (g >= 2.0) return 'Good 2';
    return 'Poor/Fair';
  }
}

class CardItem {
  final String id;
  String sport;
  String brand;
  String setName;
  int? year;
  String player;
  String team;
  String number;
  String? notes;
  String? imagePath;     // FRONT
  String? backImagePath; // BACK
  GradeResult? grade;
  final DateTime createdAt;

  CardItem({
    required this.id,
    this.sport = 'Baseball',
    this.brand = '',
    this.setName = '',
    this.year,
    this.player = '',
    this.team = '',
    this.number = '',
    this.notes,
    this.imagePath,
    this.backImagePath,
    this.grade,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CardItem copyWith({
    String? sport,
    String? brand,
    String? setName,
    int? year,
    String? player,
    String? team,
    String? number,
    String? notes,
    String? imagePath,
    String? backImagePath,
    GradeResult? grade,
  }) {
    return CardItem(
      id: id,
      sport: sport ?? this.sport,
      brand: brand ?? this.brand,
      setName: setName ?? this.setName,
      year: year ?? this.year,
      player: player ?? this.player,
      team: team ?? this.team,
      number: number ?? this.number,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      grade: grade ?? this.grade,
      createdAt: createdAt,
    );
  }
}

class CardRepository extends ChangeNotifier {
  final List<CardItem> _items = [];
  List<CardItem> get items => List.unmodifiable(_items);

  void add(CardItem c) {
    _items.insert(0, c);
    notifyListeners();
  }

  void update(CardItem c) {
    final idx = _items.indexWhere((e) => e.id == c.id);
    if (idx >= 0) {
      _items[idx] = c;
      notifyListeners();
    }
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}

// =================== Gallery ===================

class CardListPage extends StatelessWidget {
  const CardListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CardRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gallery',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.3,
          ),
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _verigradeGradient)),
      ),
      body: repo.items.isEmpty
          ? const _EmptyState()
          : ListView.separated(
        itemCount: repo.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
        itemBuilder: (context, i) {
          final item = repo.items[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: _CardTileThumb(item: item),
            title: Text(
              item.player.isEmpty ? '(Unknown Player)' : item.player,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              (item.team.isEmpty ? 'Team — ?' : item.team) +
                  (item.grade != null ? '   •   ${item.grade!.label} (${item.grade!.overall.toStringAsFixed(2)})' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CardDetailPage(item: item)),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFF2F80ED),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_circle),
            label: const Text(
              'Add Card',
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddOrEditCardPage())),
          ),
        ),
      ),
    );
  }
}

class _CardTileThumb extends StatelessWidget {
  final CardItem item;
  const _CardTileThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final w = 64.0;
    final h = 64.0 * (4 / 3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imagePath == null)
              Container(color: Colors.white12, child: const Icon(Icons.photo, color: Colors.white54))
            else
              Image.file(File(item.imagePath!), fit: BoxFit.cover),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.player.isEmpty ? 'Unknown' : item.player,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      item.team.isEmpty ? 'Team — ?' : item.team,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            if (item.grade != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    item.grade!.overall.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "No cards yet.\nTap “Add Card” to start your Verigrade collection.",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}

// =================== Card detail ===================

class CardDetailPage extends StatelessWidget {
  final CardItem item;
  const CardDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CardRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Card Details',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _verigradeGradient)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              repo.remove(item.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: item.imagePath == null
                ? Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade800.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.photo, size: 48)),
            )
                : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(item.imagePath!), fit: BoxFit.cover),
            ),
          ),
          if (item.backImagePath != null) ...[
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(item.backImagePath!), fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(item.player.isEmpty ? 'Unknown Player' : item.player,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(
            '${item.team.isEmpty ? 'Team — ?' : item.team}'
                ' • ${item.year ?? 'Year?'}'
                ' • ${item.brand} ${item.setName} • #${item.number}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (item.grade != null) _GradeCard(grade: item.grade!),
          const SizedBox(height: 12),
          if ((item.notes ?? '').isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(item.notes!),
              ),
            ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final GradeResult grade;
  const _GradeCard({required this.grade});

  @override
  Widget build(BuildContext context) {
    final g = grade.overall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Grade: ${g.toStringAsFixed(2)} • ${grade.label}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Corners: ${grade.corners.toStringAsFixed(1)}  •  '
              'Edges: ${grade.edges.toStringAsFixed(1)}  •  '
              'Surface: ${grade.surface.toStringAsFixed(1)}  •  '
              'Centering: ${grade.centering.toStringAsFixed(1)}'),
        ]),
      ),
    );
  }
}

// =================== Add Card (camera-only, auto metadata) ===================

class AddOrEditCardPage extends StatefulWidget {
  const AddOrEditCardPage({super.key});

  @override
  State<AddOrEditCardPage> createState() => _AddOrEditCardPageState();
}

class _AddOrEditCardPageState extends State<AddOrEditCardPage> {
  CaptureStep _step = CaptureStep.front;
  File? _front;
  File? _back;

  Future<void> _onPress() async {
    if (_step == CaptureStep.busy) return;

    try {
      if (_step == CaptureStep.front) {
        final f = await Navigator.push<File?>(
          context,
          MaterialPageRoute(builder: (_) => const CardCameraScreen(aspect: 3 / 4)),

        );
        if (f == null) return; // user canceled
        _front = f;
        setState(() => _step = CaptureStep.back);
        return;
      }

      if (_step == CaptureStep.back) {
        final b = await Navigator.push<File?>(
          context,
          MaterialPageRoute(builder: (_) => const CardCameraScreen(aspect: 3 / 4)),

        );
        if (b == null) return; // user canceled
        _back = b;
        setState(() => _step = CaptureStep.busy);

        // analyze & save
        final cv = await analyzeFrontBack(front: _front!, back: _back!);
        final grade = GradeResult(
          corners: cv.corners,
          edges: cv.edges,
          surface: cv.surface,
          centering: (cv.centeringFront * 0.8 + cv.centeringBack * 0.2),
        );
        final meta = await _extractNameTeam(_front!);

        context.read<CardRepository>().add(
          CardItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            player: meta['player'] ?? '',
            team: meta['team'] ?? '',
            imagePath: _front!.path,
            backImagePath: _back!.path,
            grade: grade,
          ),
        );

        if (!mounted) return;
        Navigator.pop(context); // back to gallery/home
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      setState(() => _step = CaptureStep.front);
    }
  }

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    if (_step == CaptureStep.front) {
      label = 'Capture Front';
      icon = Icons.filter_1;
    } else if (_step == CaptureStep.back) {
      label = 'Capture Back';
      icon = Icons.filter_2;
    } else {
      label = 'Processing…';
      icon = Icons.hourglass_bottom;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add a Card',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _verigradeGradient)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Capture the front, then the back.\nWe’ll auto-detect details and estimate a PSA-like grade.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 280,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: const Color(0xFF2F80ED),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(icon),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  onPressed: _step == CaptureStep.busy ? null : _onPress,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================== PSA info page ===================

class PSAInfoPage extends StatelessWidget {
  const PSAInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PSA Grading Criteria',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: _verigradeGradient)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Overview', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'PSA grades trading cards on a 1–10 scale, with 10 representing Gem Mint. '
                'While sub-grades are not official PSA outputs, collectors often evaluate centering, corners, edges, and surface individually.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _PSASection(
            title: 'Centering (typical allowances)',
            bullets: const [
              'PSA 10: roughly 55/45 or better (front), 60/40 or better (back).',
              'PSA 9: around 60/40 or better (front), ~65/35 (back).',
              'PSA 8: around 65/35 or better (front), ~70/30 (back).',
            ],
          ),
          _PSASection(
            title: 'Corners',
            bullets: const [
              'PSA 10: sharp, no wear under 5–10× magnification.',
              'PSA 9: essentially sharp; tiny touch visible on one corner at most.',
              'PSA 8: minor touches/wear allowed; no major rounding.',
            ],
          ),
          _PSASection(
            title: 'Edges',
            bullets: const [
              'PSA 10: clean, no chipping or fraying.',
              'PSA 9: extremely minor chipping/print-cut roughness permissible.',
              'PSA 8: small areas of chipping or light wear allowed.',
            ],
          ),
          _PSASection(
            title: 'Surface',
            bullets: const [
              'PSA 10: original gloss; no print lines, scratches, or stains.',
              'PSA 9: very minor print or surface ticks allowed, hard to see.',
              'PSA 8: light scratches/print lines allowed; no heavy creases.',
            ],
          ),
          _PSASection(
            title: 'Defects that strongly cap grades',
            bullets: const [
              'Creases or wrinkles (often cap at PSA 6 or lower depending on severity).',
              'Paper loss, writing, stains, or heavy print/roller lines.',
              'Trimmed or altered cards (typically deemed “N5 Altered”).',
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Tip • Verigrade uses heuristics to approximate these factors. '
                    'For the best results when photographing, use a solid background, fill the on-screen frame, and avoid glare.',
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PSASection extends StatelessWidget {
  final String title;
  final List<String> bullets;
  const _PSASection({required this.title, required this.bullets});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...bullets.map(
                (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(b, style: textTheme.bodyMedium)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// =============== On-device photo analysis (heuristics) ==============
// ===================================================================

class CvResult {
  final double centeringFront; // 1..10
  final double centeringBack;  // 1..10
  final double corners;        // 1..10
  final double edges;          // 1..10
  final double surface;        // 1..10
  final Map<String, dynamic> debug;
  CvResult({
    required this.centeringFront,
    required this.centeringBack,
    required this.corners,
    required this.edges,
    required this.surface,
    this.debug = const {},
  });
}

/// Analyze both sides and produce PSA-style sub-scores (pure Dart).
Future<CvResult> analyzeFrontBack({
  required File front,
  required File back,
}) async {
  final f = await _loadAndDownscale(front);
  final b = await _loadAndDownscale(back);

  final cFront = _centeringScore(f);
  final cBack  = _centeringScore(b);

  final cornersScore = _cornersScore(f);
  final edgesScore   = _edgesScore(f);
  final surfaceScore = _surfaceScore(f);

  return CvResult(
    centeringFront: cFront,
    centeringBack: cBack,
    corners: cornersScore,
    edges: edgesScore,
    surface: surfaceScore,
  );
}

/// Map sub-scores to PSA-like overall (tune later as you calibrate).
double psaEstimate(CvResult r) {
  final front = 0.25*r.centeringFront + 0.25*r.corners + 0.25*r.edges + 0.15*r.surface;
  final back  = 0.10*r.centeringBack;
  return (front + back).clamp(1.0, 10.0);
}

String psaLabel(double g) {
  if (g >= 9.5) return 'Gem Mint 10';
  if (g >= 9.0) return 'Mint 9';
  if (g >= 8.0) return 'NM-MT 8';
  if (g >= 7.0) return 'NM 7';
  if (g >= 6.0) return 'EX-MT 6';
  if (g >= 5.0) return 'EX 5';
  if (g >= 4.0) return 'VG-EX 4';
  if (g >= 3.0) return 'VG 3';
  if (g >= 2.0) return 'Good 2';
  return 'Poor/Fair';
}

// ---------- Image utilities & heuristics ----------

Future<im.Image> _loadAndDownscale(File f) async {
  final bytes = await f.readAsBytes();
  final img = im.decodeImage(bytes)!;
  final maxDim = 1400; // cap longest dimension for speed
  final longSide = math.max(img.width, img.height);
  if (longSide <= maxDim) return img;
  final scale = maxDim / longSide;
  return im.copyResize(
    img,
    width: (img.width * scale).round(),
    height: (img.height * scale).round(),
    interpolation: im.Interpolation.linear,
  );
}

/// Centering via border thickness symmetry. Returns 1..10.
double _centeringScore(im.Image img) {
  final gray = im.grayscale(img);

  int left = _firstStrongVerticalEdge(gray, fromLeft: true);
  int right = gray.width - _firstStrongVerticalEdge(gray, fromLeft: false);
  int top = _firstStrongHorizontalEdge(gray, fromTop: true);
  int bottom = gray.height - _firstStrongHorizontalEdge(gray, fromTop: false);

  left = left.clamp(1, gray.width - 2);
  right = right.clamp(1, gray.width - 2);
  top = top.clamp(1, gray.height - 2);
  bottom = bottom.clamp(1, gray.height - 2);

  final lrRatio = left / right;
  final tbRatio = top / bottom;

  double errLR = (lrRatio > 1) ? (lrRatio - 1) : (1 - lrRatio);
  double errTB = (tbRatio > 1) ? (tbRatio - 1) : (1 - tbRatio);
  final combined = (errLR + errTB) / 2.0;
  final pct = combined * 100.0;

  final score = (10.0 - 0.08 * pct).clamp(1.0, 10.0);
  return score;
}

int _firstStrongVerticalEdge(im.Image gray, {required bool fromLeft}) {
  final w = gray.width, h = gray.height;
  final y0 = (h * 0.35).round();
  final y1 = (h * 0.65).round();
  int bestX = fromLeft ? 1 : w - 2;
  double bestMag = -1;

  if (fromLeft) {
    for (int x = 1; x < w - 1; x++) {
      double sum = 0;
      for (int y = y0; y < y1; y++) {
        final g1 = gray.getPixel(x - 1, y);
        final g2 = gray.getPixel(x + 1, y);
        sum += (im.getLuminance(g2) - im.getLuminance(g1)).abs();
      }
      final mag = sum / (y1 - y0);
      if (mag > bestMag) {
        bestMag = mag;
        bestX = x;
      }
      if (bestMag > 25 && x > (w * 0.05)) break;
    }
  } else {
    for (int x = w - 2; x >= 1; x--) {
      double sum = 0;
      for (int y = y0; y < y1; y++) {
        final g1 = gray.getPixel(x - 1, y);
        final g2 = gray.getPixel(x + 1, y);
        sum += (im.getLuminance(g2) - im.getLuminance(g1)).abs();
      }
      final mag = sum / (y1 - y0);
      if (mag > bestMag) {
        bestMag = mag;
        bestX = x;
      }
      if (bestMag > 25 && x < (w * 0.95)) break;
    }
  }
  return bestX;
}

int _firstStrongHorizontalEdge(im.Image gray, {required bool fromTop}) {
  final w = gray.width, h = gray.height;
  final x0 = (w * 0.35).round();
  final x1 = (w * 0.65).round();
  int bestY = fromTop ? 1 : h - 2;
  double bestMag = -1;

  if (fromTop) {
    for (int y = 1; y < h - 1; y++) {
      double sum = 0;
      for (int x = x0; x < x1; x++) {
        final g1 = gray.getPixel(x, y - 1);
        final g2 = gray.getPixel(x, y + 1);
        sum += (im.getLuminance(g2) - im.getLuminance(g1)).abs();
      }
      final mag = sum / (x1 - x0);
      if (mag > bestMag) {
        bestMag = mag;
        bestY = y;
      }
      if (bestMag > 25 && y > (h * 0.05)) break;
    }
  } else {
    for (int y = h - 2; y >= 1; y--) {
      double sum = 0;
      for (int x = x0; x < x1; x++) {
        final g1 = gray.getPixel(x, y - 1);
        final g2 = gray.getPixel(x, y + 1);
        sum += (im.getLuminance(g2) - im.getLuminance(g1)).abs();
      }
      final mag = sum / (x1 - x0);
      if (mag > bestMag) {
        bestMag = mag;
        bestY = y;
      }
      if (bestMag > 25 && y < (h * 0.95)) break;
    }
  }
  return bestY;
}

/// Corners: edge energy/whitening in four corner patches.
double _cornersScore(im.Image img) {
  const s = 64;
  final patches = [
    im.copyCrop(img, x: 0, y: 0, width: s, height: s),
    im.copyCrop(img, x: img.width - s, y: 0, width: s, height: s),
    im.copyCrop(img, x: 0, y: img.height - s, width: s, height: s),
    im.copyCrop(img, x: img.width - s, y: img.height - s, width: s, height: s),
  ];
  double penalty = 0;
  for (final p in patches) {
    final g = im.grayscale(p);
    double sum = 0;
    for (int y = 1; y < g.height - 1; y++) {
      for (int x = 1; x < g.width - 1; x++) {
        final vx = im.getLuminance(g.getPixel(x + 1, y)) -
            im.getLuminance(g.getPixel(x - 1, y));
        final vy = im.getLuminance(g.getPixel(x, y + 1)) -
            im.getLuminance(g.getPixel(x, y - 1));
        sum += (vx.abs() + vy.abs());
      }
    }
    penalty += sum / ((g.width - 2) * (g.height - 2));
  }
  penalty /= patches.length;
  return (10.0 - (penalty / 28.0)).clamp(1.0, 10.0);
}

/// Edges: bright-pixel ratio in thin strips around borders.
double _edgesScore(im.Image img) {
  final g = im.grayscale(img);
  const t = 220;
  final w = g.width, h = g.height, strip = (math.min(w, h) * 0.01).clamp(4, 12).toInt();

  int bright = 0, total = 0;

  // left
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < strip; x++) {
      if (im.getLuminance(g.getPixel(x, y)) >= t) bright++;
      total++;
    }
  }
  // right
  for (int y = 0; y < h; y++) {
    for (int x = w - strip; x < w; x++) {
      if (im.getLuminance(g.getPixel(x, y)) >= t) bright++;
      total++;
    }
  }
  // top
  for (int y = 0; y < strip; y++) {
    for (int x = 0; x < w; x++) {
      if (im.getLuminance(g.getPixel(x, y)) >= t) bright++;
      total++;
    }
  }
  // bottom
  for (int y = h - strip; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (im.getLuminance(g.getPixel(x, y)) >= t) bright++;
      total++;
    }
  }

  final ratio = total == 0 ? 0.0 : (bright / total);
  return (10.0 - ratio * 40.0).clamp(1.0, 10.0);
}

/// Surface: tiny bright specks density in center region.
double _surfaceScore(im.Image img) {
  final crop = im.copyCrop(
    img,
    x: (img.width * 0.1).round(),
    y: (img.height * 0.1).round(),
    width: (img.width * 0.8).round(),
    height: (img.height * 0.8).round(),
  );
  final g = im.grayscale(crop);
  final blurred = im.gaussianBlur(g, radius: 1);
  int specks = 0;

  for (int y = 1; y < blurred.height - 1; y++) {
    for (int x = 1; x < blurred.width - 1; x++) {
      final v = im.getLuminance(blurred.getPixel(x, y));
      if (v > 235) {
        int neighbors = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (im.getLuminance(blurred.getPixel(x + dx, y + dy)) > 220) neighbors++;
          }
        }
        if (neighbors <= 2) specks++;
      }
    }
  }

  final density = specks / (blurred.width * blurred.height);
  return (10.0 - density * 25000.0).clamp(1.0, 10.0);
}

// =================== Simple metadata stub (replace with OCR later) ===================

Future<Map<String, String>> _extractNameTeam(File frontImage) async {
  // Placeholder: try naive hints from filename; else return blanks.
  final name = frontImage.path.split(Platform.pathSeparator).last;
  final base = name.toLowerCase();
  String player = '';
  String team = '';

  // naive parsing like "2020_topps_mike_trout_angels.jpg"
  final maybe = base
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\.(jpg|jpeg|png|heic|webp)$'), '');
  if (maybe.contains('trout')) {
    player = 'Mike Trout';
    team = 'Angels';
  } else if (maybe.contains('jordan')) {
    player = 'Michael Jordan';
    team = 'Bulls';
  }

  return {'player': player, 'team': team};
}
