import 'package:flutter/material.dart';

import '../create/projects_store.dart';
import '../l10n/app_localizations.dart';
import 'adventure_tile.dart';
import 'library_tile_actions.dart';

/// Library tab indices the Home "More" links open.
const int _libAdventures = 0;
const int _libSaves = 1;

/// The Home view: two horizontal sections of [AdventureTile]s — Active
/// sessions ({Saves}) and Adventures ({Adventures}). Each section is shown
/// ONLY when it has content, fills a single row with as many tiles as fit, and
/// ends with a **More** link to the matching Library tab. Tapping a tile does the
/// SAME thing as in that Library tab (resume a save / open the adventure info
/// window).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.store = const ProjectsStore(),
    this.onHome,
    this.onNavigate,
    this.onMore,
    this.onEditSave,
    this.onCreateNew,
  });

  final ProjectsStore store;

  /// Threaded to the launch screen opened from a tile (Home / Settings rail +
  /// finish-adventure exit).
  final VoidCallback? onHome;
  final ValueChanged<int>? onNavigate;

  /// Opens the Library at a tab index (a section's More link).
  final ValueChanged<int>? onMore;

  /// Opens a save in the game editor — threaded to the resume screen's Edit
  /// button, so Active-sessions tiles reach save-content editing.
  final ValueChanged<String>? onEditSave;

  /// Opens the new-adventure form on the Create destination — the empty-state
  /// "create new adventure" tile (the same form as the Create grid's new cell).
  final VoidCallback? onCreateNew;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AdventureSummary> _saves = const [];
  List<AdventureSummary> _adventures = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<AdventureSummary> saves = const [];
    List<AdventureSummary> adventures = const [];
    try {
      saves = await widget.store.listSaves();
      adventures = await widget.store.listAdventures();
    } catch (_) {
      // No path provider (a bare widget test) -> empty sections.
    }
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _adventures = adventures;
    });
  }

  Future<void> _resume(AdventureSummary save) async {
    await resumeSaveTile(
      context,
      store: widget.store,
      save: save,
      onHome: widget.onHome,
      onNavigate: widget.onNavigate,
      onEditSave: widget.onEditSave,
    );
    if (mounted) await _load(); // a finished save no longer lists here
  }

  Future<void> _info(AdventureSummary adventure) => showAdventureInfoTile(
    context,
    store: widget.store,
    adventure: adventure,
    onHome: widget.onHome,
    onNavigate: widget.onNavigate,
  );

  /// Empty-state "add adventure" tile: import a `.ls` into the library — the SAME
  /// flow as the Library Adventures import tile. A successful add reloads, so the
  /// Adventures section replaces the empty state.
  Future<void> _import() async {
    final added = await importLsToLibraryTile(context, store: widget.store);
    if (added && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Nothing to resume and nothing in the library: offer the two entry tiles.
    if (_saves.isEmpty && _adventures.isEmpty) return _emptyState(l10n);
    return ListView(
      key: const ValueKey('home.root'),
      padding: const EdgeInsets.all(24),
      children: [
        if (_saves.isNotEmpty)
          _section(
            'saves',
            l10n.homeActiveSessions,
            _saves,
            _libSaves,
            (a) => _resume(a),
          ),
        if (_adventures.isNotEmpty)
          _section(
            'adventures',
            l10n.libraryAdventures,
            _adventures,
            _libAdventures,
            (a) => _info(a),
          ),
      ],
    );
  }

  /// Shown when there are no saves and no adventures: two adventure-tile-sized
  /// cells — "add adventure" (import a `.ls`, as in Library/Adventures) and
  /// "create new adventure" (open the new-adventure form, as in Create).
  Widget _emptyState(AppLocalizations l10n) {
    const tileWidth = 220.0;
    return ListView(
      key: const ValueKey('home.root'),
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          key: const ValueKey('home.empty'),
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: tileWidth,
              child: AspectRatio(
                aspectRatio: 1 / 1.43,
                child: _entryTile(
                  key: 'home.empty.create',
                  icon: Icons.note_add_outlined,
                  label: l10n.homeCreateAdventure,
                  onTap: () => widget.onCreateNew?.call(),
                ),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: AspectRatio(
                aspectRatio: 1 / 1.43,
                child: _entryTile(
                  key: 'home.empty.import',
                  icon: Icons.upload_file_outlined,
                  label: l10n.libraryImport,
                  onTap: _import,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// One empty-state entry tile: a solid-colour card with a centred icon over a
  /// label, styled like the Create grid's new cell / Library import cell.
  Widget _entryTile({
    required String key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(key),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One section: a header (title + More link) then a single row filled with as
  /// many tiles as fit the available width.
  Widget _section(
    String key,
    String title,
    List<AdventureSummary> items,
    int libTab,
    ValueChanged<AdventureSummary> onTap,
  ) {
    // Same tile size as the Library grids (maxCrossAxisExtent 220, 1:1.43).
    const tileWidth = 220.0;
    const spacing = 16.0;
    return Padding(
      key: ValueKey('home.section.$key'),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                key: ValueKey('home.more.$key'),
                onPressed: () => widget.onMore?.call(libTab),
                child: Text(AppLocalizations.of(context).homeMore),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Only as many tiles as fill ONE row.
          LayoutBuilder(
            builder: (context, constraints) {
              final n = (constraints.maxWidth / (tileWidth + spacing))
                  .floor()
                  .clamp(1, items.length);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < n; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: spacing),
                      child: SizedBox(
                        width: tileWidth,
                        child: AdventureTile(
                          adventure: items[i],
                          onOpen: () => onTap(items[i]),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
