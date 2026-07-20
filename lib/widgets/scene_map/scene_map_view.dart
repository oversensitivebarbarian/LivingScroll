import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

import '../../l10n/app_localizations.dart';
import '../../paths/path_colors.dart';
import '../scene_type_icon.dart';
import 'metro_edge_renderer.dart';
import 'scene_graph.dart';
import 'scene_map_layout.dart';

/// One legend line: a colour id paired with its authored path name.
typedef SceneMapPath = ({String colorId, String name});

/// Interactive, metro-style visualisation of an adventure's scene graph.
///
/// Stations are scenes (shape = `scene_type`, hollow ring = interchange), lines
/// are paths (colour), segments are `next_scenes` (directed arrows). The whole
/// graph is laid out with Sugiyama (top→bottom), wrapped in an
/// [InteractiveViewer] for zoom/pan, and overlaid with a tappable line legend
/// (filter) plus a shape legend. An empty model shows an empty-state message.
///
/// See `docs/scene_map_widget.md`.
class SceneMapView extends StatefulWidget {
  const SceneMapView({
    super.key,
    required this.model,
    required this.mode,
    required this.paths,
    this.onSceneTap,
    this.colorResolver,
    this.animated = true,
  });

  final SceneGraphModel model;
  final SceneMapMode mode;

  /// All adventure paths (colour id + name) for the legend; the in-use subset is
  /// taken from [SceneGraphModel.pathColorIdsInUse].
  final List<SceneMapPath> paths;

  /// Called with a tapped station's `scene_uuid`.
  final ValueChanged<String>? onSceneTap;

  /// Resolves a path colour id to a [Color]. Defaults to the built-in
  /// [pathColors] table, with a `#RRGGBB` hex fallback and a neutral grey for
  /// anything unknown.
  final Color Function(String colorId)? colorResolver;

  /// Pass `false` in widget tests to avoid pending animation timers.
  final bool animated;

  @override
  State<SceneMapView> createState() => _SceneMapViewState();
}

class _SceneMapViewState extends State<SceneMapView> {
  final Graph _graph = Graph();
  late SugiyamaAlgorithm _algorithm;
  late MetroEdgeRenderer _renderer;
  String? _activeColorId;

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(SceneMapView old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model) {
      _graph.nodes.clear();
      _graph.edges.clear();
      _buildGraph();
    }
  }

  void _buildGraph() {
    final nodeByUuid = <String, Node>{};
    for (final n in widget.model.nodes) {
      final node = Node.Id(n.uuid);
      _graph.addNode(node);
      nodeByUuid[n.uuid] = node;
    }
    for (final e in widget.model.edges) {
      final a = nodeByUuid[e.fromUuid];
      final b = nodeByUuid[e.toUuid];
      if (a != null && b != null) _graph.addEdge(a, b);
    }

    final config = SugiyamaConfiguration()
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM
      ..nodeSeparation = 30
      ..levelSeparation = 60;
    // All start scenes pinned to a top row, all end scenes to a bottom row, and
    // each body scene snapped to the column of its primary path (variant 1).
    _algorithm = SceneMapLayout(
      config,
      startUuids: {
        for (final n in widget.model.nodes)
          if (n.shape == SceneShape.start) n.uuid,
      },
      endUuids: {
        for (final n in widget.model.nodes)
          if (n.shape == SceneShape.end) n.uuid,
      },
      columnOrder: widget.model.pathColorIdsInUse,
      primaryColorByUuid: {
        for (final n in widget.model.nodes)
          if (n.pathColorIds.isNotEmpty) n.uuid: n.pathColorIds.first,
      },
    );
    _renderer = MetroEdgeRenderer(
      edgeByPair: {
        for (final e in widget.model.edges) '${e.fromUuid}->${e.toUuid}': e,
      },
      resolveColor: _resolve,
      neutralColor: const Color(0xFF9E9E9E),
      // Avoid drawing a line over / next to a station that is not its own.
      nodesProvider: () => _graph.nodes,
      laneStep: 180,
    );
    _algorithm.renderer = _renderer;
  }

  Color _resolve(String colorId) {
    final custom = widget.colorResolver;
    if (custom != null) return custom(colorId);
    for (final c in pathColors) {
      if (c.id == colorId) return c.color;
    }
    if (colorId.startsWith('#') && (colorId.length == 7 || colorId.length == 9)) {
      final hex = colorId.substring(1);
      final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF9E9E9E);
  }

  void _setFilter(String? colorId) {
    setState(() {
      _activeColorId = colorId;
      _renderer.activeColorId = colorId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Self-contained Material ancestor so the legend's FilterChips / ink work
    // wherever the map is hosted (game page, play centre slot, or a bare test).
    if (widget.model.isEmpty) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          key: const ValueKey('scene.map.view'),
          alignment: Alignment.center,
          child: Text(
            l10n.sceneMapEmpty,
            key: const ValueKey('scene.map.empty'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Container(
        key: const ValueKey('scene.map.view'),
        color: scheme.surface,
        child: Column(
          children: [
            _legend(context, l10n, scheme),
            const Divider(height: 1),
            Expanded(child: _graphView(scheme)),
          ],
        ),
      ),
    );
  }

  Widget _graphView(ColorScheme scheme) {
    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(400),
      minScale: 0.2,
      maxScale: 3,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: GraphView(
          graph: _graph,
          algorithm: _algorithm,
          paint: Paint()
            ..color = const Color(0xFF9E9E9E)
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
          animated: widget.animated,
          builder: (node) {
            final uuid = node.key?.value as String?;
            final model =
                uuid == null ? null : widget.model.nodeFor(uuid);
            if (model == null) return const SizedBox.shrink();
            final dimmed = _activeColorId != null &&
                !model.pathColorIds.contains(_activeColorId);
            return _StationTile(
              key: ValueKey('scene.map.node.$uuid'),
              node: model,
              color: model.pathColorIds.isEmpty
                  ? const Color(0xFF9E9E9E)
                  : _resolve(model.pathColorIds.first),
              scheme: scheme,
              dimmed: dimmed,
              onTap: () => widget.onSceneTap?.call(uuid!),
            );
          },
        ),
      ),
    );
  }

  Widget _legend(
      BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    final lines = widget.model.pathColorIdsInUse;
    final nameById = {for (final p in widget.paths) p.colorId: p.name};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            key: const ValueKey('scene.map.legend.all'),
            label: Text(l10n.sceneMapAllPaths),
            selected: _activeColorId == null,
            onSelected: (_) => _setFilter(null),
          ),
          const SizedBox(width: 8),
          for (final colorId in lines) ...[
            FilterChip(
              key: ValueKey('scene.map.legend.line.$colorId'),
              avatar: CircleAvatar(backgroundColor: _resolve(colorId), radius: 8),
              label: Text(nameById[colorId] ?? colorId),
              selected: _activeColorId == colorId,
              onSelected: (sel) => _setFilter(sel ? colorId : null),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// A single laid-out station: the shape painter over the scene name, tappable.
class _StationTile extends StatelessWidget {
  const _StationTile({
    super.key,
    required this.node,
    required this.color,
    required this.scheme,
    required this.dimmed,
    required this.onTap,
  });

  final SceneNode node;
  final Color color;
  final ColorScheme scheme;
  final bool dimmed;
  final VoidCallback onTap;

  /// The canonical `scene_type` string for [node]'s shape, so the station shows
  /// the SAME glyph as the scene tile / type radios via [sceneTypeIcon].
  static String _sceneType(SceneShape shape) => switch (shape) {
        SceneShape.start => 'start',
        SceneShape.recurring => 'recurring',
        SceneShape.end => 'end',
        SceneShape.standard => 'standard',
      };

  @override
  Widget build(BuildContext context) {
    // Greyed when inactive or line-less; tinted by the line colour otherwise.
    var glyphColor =
        node.inactive || node.pathColorIds.isEmpty ? scheme.onSurfaceVariant : color;
    if (dimmed) glyphColor = glyphColor.withValues(alpha: 0.25);

    Widget station = Icon(
      sceneTypeIcon(_sceneType(node.shape)),
      size: 30,
      color: glyphColor,
    );

    // An interchange (≥2 lines) gets a thick transfer ring; a conditional (gated)
    // scene a thin one. The glyph itself stays the scene-type icon.
    if (node.interchange || node.conditional) {
      final ringColor = dimmed
          ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
          : scheme.onSurfaceVariant;
      station = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: ringColor,
            width: node.interchange ? 2.5 : 1,
          ),
        ),
        child: station,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 40, child: Center(child: station)),
            const SizedBox(height: 4),
            Text(
              node.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: dimmed
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                    : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
