import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/journal_repository.dart';
import '../data/photo_store.dart';
import '../models/climb_route.dart';
import 'quick_log_sheet.dart';
import 'widgets.dart';

/// Climbing mode (FR-12): the route's photos full screen with zoom, the
/// screen kept on, and a Log button for when you come down.
class ClimbingModeScreen extends StatefulWidget {
  const ClimbingModeScreen({
    super.key,
    required this.repo,
    required this.photos,
    required this.route,
    required this.subtitle,
  });

  final JournalRepository repo;
  final PhotoStore photos;
  final ClimbRoute route;
  final String subtitle;

  @override
  State<ClimbingModeScreen> createState() => _ClimbingModeScreenState();
}

class _ClimbingModeScreenState extends State<ClimbingModeScreen> {
  late ClimbRoute _route = widget.route;
  final Map<String, Future<Uint8List?>> _images = {};
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _keepScreenOn(true);
  }

  @override
  void dispose() {
    _keepScreenOn(false);
    _pages.dispose();
    super.dispose();
  }

  /// Best effort: tests and some platforms have no wakelock.
  Future<void> _keepScreenOn(bool on) async {
    try {
      await (on ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {}
  }

  Future<Uint8List?> _image(String id) =>
      _images.putIfAbsent(id, () => widget.photos.load(id));

  Future<void> _addPhoto(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
      );
      if (picked == null) return;
      final id = await widget.photos.save(await picked.readAsBytes());
      final updated = _route.copyWith(photoIds: [..._route.photoIds, id]);
      widget.repo.updateRoute(updated);
      if (!mounted) return;
      setState(() => _route = updated);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pages.hasClients) _pages.jumpToPage(updated.photoIds.length - 1);
      });
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not add the photo: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePhoto() async {
    if (_route.photoIds.isEmpty) return;
    final id = _route.photoIds[_page.clamp(0, _route.photoIds.length - 1)];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this photo?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final updated = _route.copyWith(
        photoIds: _route.photoIds.where((p) => p != id).toList());
    widget.repo.updateRoute(updated);
    await widget.photos.delete(id);
    _images.remove(id);
    if (!mounted) return;
    setState(() {
      _route = updated;
      _page = updated.photoIds.isEmpty
          ? 0
          : _page.clamp(0, updated.photoIds.length - 1);
    });
  }

  Future<void> _chooseSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _addPhoto(source);
  }

  Future<void> _log() async {
    final saved = await showQuickLog(
      context,
      repo: widget.repo,
      route: _route,
      subtitle: widget.subtitle,
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final photos = _route.photoIds;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            GradeBadge(_route.grade, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _route.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          if (photos.isNotEmpty)
            IconButton(
              tooltip: 'Delete this photo',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _deletePhoto,
            ),
          IconButton(
            tooltip: 'Add a photo',
            icon: const Icon(Icons.add_a_photo_outlined),
            onPressed: _busy ? null : _chooseSource,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: photos.isEmpty
                  ? _NoPhotos(
                      busy: _busy,
                      onCamera: () => _addPhoto(ImageSource.camera),
                      onGallery: () => _addPhoto(ImageSource.gallery),
                    )
                  : PageView.builder(
                      controller: _pages,
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => _ZoomablePhoto(
                        key: ValueKey(photos[i]),
                        image: _image(photos[i]),
                      ),
                    ),
            ),
            if (photos.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_page + 1} / ${photos.length} · swipe for more',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.light_mode_outlined,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('Screen stays on',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                  SizedBox(
                    width: 180,
                    child: FilledButton.icon(
                      onPressed: _log,
                      icon: const Icon(Icons.check),
                      label: const Text('Log'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePhoto extends StatelessWidget {
  const _ZoomablePhoto({super.key, required this.image});

  final Future<Uint8List?> image;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: image,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snap.data;
        if (bytes == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This photo is not on this phone.\n'
                'Backups hold your logbook but not photos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              semanticLabel: 'Route photo',
            ),
          ),
        );
      },
    );
  }
}

class _NoPhotos extends StatelessWidget {
  const _NoPhotos({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_outlined, color: Colors.white38, size: 56),
            const SizedBox(height: 12),
            const Text('No photo of this route yet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Snap the topo or the wall with the line, and it stays here '
              'while you climb.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : onCamera,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Take a photo'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onGallery,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from gallery'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
