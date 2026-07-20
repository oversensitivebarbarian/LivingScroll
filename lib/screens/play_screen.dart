import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../notes/note_content.dart';
import '../notes/note_image_embed.dart';
import '../npcs/seven_sea/seven_sea.dart';
import '../npcs/seven_sea/seven_sea_l10n.dart' show seaAdvantageLabel;
import '../scenes/scene.dart';
import '../services/audio_player_service.dart';
import '../visibility/visibility_rules.dart' show VisibilityOp;
import '../widgets/detail_dialog.dart';
import '../widgets/npc_tile.dart'
    show NpcTile, NpcVillainBadges, NpcVillainStats, sevenSeaVillain;
import '../widgets/pip_track_tile.dart';
import '../widgets/rail_menu_button.dart';
import '../widgets/rail_state.dart';
import '../widgets/scene_tile.dart' show SceneTileDisc;
import 'npc_7thsea_screen.dart' show showSchemeDialog;

/// How the Play view behaves: a read-only [preview] opened from
/// the editor, or the live [gameplay] session. The layout is identical; only the
/// side effects (persistence, history logging, the Pause action) differ.
enum PlayMode { preview, gameplay, replay }

/// What the Play stage's RIGHT column shows. The narration is ALWAYS visible in
/// the LEFT column (it is no longer a selectable view); the rail's NPC / Notes /
/// Images / GM Notes items each fill the right column with their own content.
/// The top title bar, the left narration column and the bottom key-events /
/// next-scenes rows always remain.
enum _CenterView { npcs, villains, notes, images, gmnotes, map }

/// One next-scene target shown in the bottom row: its [name], the path-colour
/// discs of the scene it points to, and the target scene's visibility gate
/// resolved to key-event NAMES ([requiredEvents] combined by [op]). The button
/// shows only when the gate is satisfied by the currently-checked key events
/// (an empty [requiredEvents] means "always visible") AND the target has not
/// been [visited] — an already-visited scene is never offered as a next scene.
typedef PlayNextScene = ({
  // The target scene's durable id — what next_scenes stores and what
  // [PlayScreen.onFollowScene] resolves against (survives a target rename).
  String uuid,
  // The target scene's display name — the button label and key (resolved from
  // [uuid]).
  String name,
  List<SceneTileDisc> discs,
  VisibilityOp op,
  List<String> requiredEvents,
  // The target scene's gameplay `visited` flag: a visited (already-seen) scene
  // is hidden from the Next scenes row. A `recurring` scene is never marked
  // visited, so it stays available.
  bool visited,
  // True when another ACTIVE party track already stands on this target scene:
  // following it merges the two tracks. The button then carries a "-> merge"
  // marker. Only ever set for author scenes.
  bool occupiedByOtherTrack,
});

/// One UN-focused party track shown as a PiP thumbnail (its scene background +
/// PC names); tapping it switches focus. Built by the host for every track
/// except the focused one.
typedef PipTrack = ({String trackId, File? backgroundImage, String pcLabel});

/// One destination in the **Jump to scene** dialog.
/// [otherTrackHere] flags the current position of another active track (an
/// author OR ad-hoc scene) — jumping there merges the tracks; these sort to the
/// top and carry a "-> merge" marker. Generic targets ([otherTrackHere] false)
/// are unvisited author scenes only.
typedef PlayJumpTarget = ({String uuid, String name, bool otherTrackHere});

/// One NPC attached to the scene, shown in the NPC grid (icon tile) and the NPC
/// info window (full image + name / backstory / description). [state] is the
/// NPC's persisted runtime state (`npcs[].state`, "active" / "inactive"): an
/// `inactive` NPC shows greyed, carries no deactivate button and is not
/// clickable.
typedef PlayNpc = ({
  String uuid,
  String name,
  File? iconImage,
  File? fullImage,
  String description,
  String backstory,
  String state,
  List<({String label, String value})> stats,
  // The 7th Sea badge values — a Villain's Strength / Influence / Rank, or a
  // Brute's Strength only — or null when the NPC's kind carries no badges (then
  // the tile stays plain, exactly as in the game NPC grid).
  NpcVillainStats? villain,
  // The RAW 7th Sea stats map (`npcs[].stats`) for a Villain — needed by the play
  // Schemes/Intrygi manager, which reads and MUTATES `influence` + `schemes`.
  // Empty for a non-7th-Sea / non-Villain NPC.
  Map<String, dynamic> sevenSeaStats,
});

/// The Play view: a full-bleed location-image stage with the
/// scene title, narration, a Key events row and a Next scenes row, plus the
/// rail (Pause / Location / conditional NPC, Notes, Images).
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.scene,
    required this.mode,
    required this.keyEvents,
    required this.nextScenes,
    required this.npcs,
    this.villains = const [],
    required this.notes,
    required this.images,
    this.seenNotes = const [],
    this.seenImages = const [],
    required this.onExit,
    this.soundtrack,
    this.autoplayMusic = true,
    this.backgroundImage,
    this.onFollowScene,
    this.onAdHoc,
    this.onSaveAndExit,
    this.onFinishAdventure,
    this.onSplit,
    this.canSplit = false,
    this.focusedPcNames = const [],
    this.pipTracks = const [],
    this.onFocusSwitch,
    this.isSplit = false,
    this.allTracksAtEnd = false,
    this.jumpTargets = const [],
    this.onJump,
    this.onPreviousScene,
    this.onReplayPrevious,
    this.onReplayNext,
    this.noteImageResolver,
    this.gmNotes = const [],
    this.onAddGmNote,
    this.onDeleteGmNote,
    this.onUpdateNpcStats,
    this.mapView,
  });

  final Scene scene;
  final PlayMode mode;

  /// The scene's key events with their current checked state.
  final List<({String name, bool checked})> keyEvents;

  /// The scene's next-scene targets with their path-colour discs.
  final List<PlayNextScene> nextScenes;

  /// The scene's NPCs (icon tile + info-window content).
  final List<PlayNpc> npcs;

  /// ALL 7th Sea 2nd Edition Villain-kind NPCs (`stats.kind == "villain"`) in the
  /// WHOLE adventure — UNLIKE [npcs], this is NOT scoped to the current scene.
  /// Drives the "Villains/Złoczyńcy" rail item, shown only when this
  /// is non-empty (i.e. never for a non-7th-Sea adventure). An `inactive`
  /// villain is INCLUDED here (not dropped, unlike the scene NPC grid) so the
  /// roster stays complete — its tile shows greyed instead. This tab offers no
  /// deactivate button; a villain can only be deactivated from the NPC tab.
  /// Tapping a tile opens the SAME info window (+ Schemes/Intrygi manager)
  /// as the NPC tab.
  final List<PlayNpc> villains;
  final List<({String uuid, String name, String content})> notes;
  final List<File> images;

  /// The "seen" gallery: notes / images ALREADY SEEN earlier this playthrough
  /// (their `seen` flag committed on leaving a scene), shown BELOW a divider under
  /// the current scene's own notes / images. Excludes the current scene's ones (so
  /// nothing is listed twice).
  final List<({String uuid, String name, String content})> seenNotes;
  final List<File> seenImages;

  /// The current scene's GM notes (gm_notes the scene links by gmnote_uuid).
  /// A GM note carries only its uuid + content (no title).
  final List<({String uuid, String content})> gmNotes;

  /// Adds a GM note. A GM note is ALWAYS global — linked to EVERY scene. Null
  /// when the host does not persist (e.g. the editor preview).
  final void Function(String content)? onAddGmNote;

  /// Deletes the GM note with the given gmnote_uuid (removes it from gm_notes[]
  /// and unlinks it from every scene). Null when GM notes are read-only (replay)
  /// or the host does not persist — then no delete button is shown.
  final void Function(String uuid)? onDeleteGmNote;

  /// Persists a Villain's updated 7th Sea stats (`npcs[].stats`) after the play
  /// Schemes/Intrygi manager changes its `influence` / `schemes` (settling an
  /// Intryga, buying a Koszt, adding a scheme). The host (gameplay) writes the
  /// save so the change survives scene navigation; null in preview/replay makes
  /// the manager session-only.
  final void Function(String npcUuid, Map<String, dynamic> stats)?
  onUpdateNpcStats;

  /// The scene-map view (`SceneMapView`) for the whole adventure, injected by the
  /// host (it owns the full scene/path/key-event data the single-scene PlayScreen
  /// does not). When non-null the rail shows a "Mapa" item that switches the
  /// centre slot to this widget. Null in contexts without a map (e.g. the editor
  /// preview, which has its own Map destination).
  final Widget? mapView;

  /// The scene's soundtrack file (`audio/<uuid>.<ext>`), or null when the scene
  /// has no music attached. Drives the rail's Soundtrack item (present only when
  /// non-null).
  final File? soundtrack;

  /// Whether the scene's music starts playing automatically on open (the app's
  /// Music > Autoplay setting; on by default).
  final bool autoplayMusic;

  /// The scene's background image (`scenes.bg_image` ->
  /// `images/other/<uuid>.png`); null shows a flat surface colour.
  final File? backgroundImage;

  /// Pause in preview / leave the session. Also used when there is no
  /// [onSaveAndExit] in gameplay.
  final VoidCallback onExit;

  /// Following a next scene (preview navigates, gameplay advances). The first
  /// argument is the target scene's scene_uuid (next_scenes are stored by uuid).
  /// Carries the scene's currently-checked key events so the transition COMMITS
  /// them: a key event checked here stays checked in the next scene (and is
  /// hidden from its Key events row).
  /// Carries the scene's currently-checked key events AND the NPCs greyed
  /// (deactivated) this session, so the transition COMMITS both: a deactivated
  /// NPC's `npcs[].state` becomes "inactive" in the next scene (gameplay only).
  final void Function(
    String sceneUuid,
    Set<String> checkedKeyEvents,
    Set<String> deactivatedNpcs,
  )?
  onFollowScene;

  /// Start an ad-hoc scene (hidden on ending scenes). The [name] is entered by
  /// the GM in the ad-hoc dialog (the scene has no other content). Carries the
  /// checked key events AND deactivated NPCs forward, exactly like
  /// [onFollowScene]. The host mints the scene's uuid and inherits its
  /// next_scenes from the current scene.
  final void Function(
    String name,
    Set<String> checkedKeyEvents,
    Set<String> deactivatedNpcs,
  )?
  onAdHoc;

  /// Gameplay Pause -> OK: save progress and leave for the main view.
  final VoidCallback? onSaveAndExit;

  /// Gameplay only: the **Finish adventure** action shown on an END scene (which
  /// has no next scenes). Saves the game state, archives the save and returns to
  /// Home. Null in preview. While the party is split ([isSplit]) the button is
  /// DISABLED until [allTracksAtEnd] — the whole adventure can only end once
  /// every track has reached an end scene.
  final VoidCallback? onFinishAdventure;

  /// Splits the party: the PC in the given set move to a NEW track on the same
  /// scene. Null gates the **Split party** button OUT entirely (the editor
  /// preview and replay do not pass it). When non-null the button shows on every
  /// non-`end` scene, enabled only while [canSplit] is true.
  final void Function(Set<String> pcToNewTrack)? onSplit;

  /// Whether a split is currently possible (from the controller: below the
  /// roster cap AND the focused track holds >=2 PC). Drives the Split button's
  /// enabled state; the button is shown-but-disabled when false.
  final bool canSplit;

  /// The PC names on the focused track — the checkboxes offered in the split
  /// dialog (choose which move to the new track).
  final List<String> focusedPcNames;

  /// The UN-focused party tracks, shown as PiP thumbnails. Empty when the party
  /// is not split (a single track) — then no PiP bar is shown.
  final List<PipTrack> pipTracks;

  /// Switches focus to the track with the given id (tapping its PiP thumbnail).
  final void Function(String trackId)? onFocusSwitch;

  /// Whether the party is split (more than one track). Shows the **Jump to
  /// scene** button even when there ARE next scenes — a split party can always
  /// re-route toward a merge.
  final bool isSplit;

  /// Whether EVERY active track currently stands on an end scene. Only meaningful
  /// while [isSplit]; when true it re-enables **Finish adventure** so the whole
  /// adventure can be finished with the party still divided (each track having
  /// independently reached an end scene).
  final bool allTracksAtEnd;

  /// Destinations for the Jump dialog: other tracks' positions (top, "-> merge")
  /// then unvisited author scenes. Empty hides the dialog's list.
  final List<PlayJumpTarget> jumpTargets;

  /// Jumps the focused track to [sceneUuid] (an ordinary navigation that also
  /// runs the merge check). Carries the checked events + deactivated NPCs like a
  /// follow. Null gates the Jump button out (editor preview / replay).
  final void Function(
    String sceneUuid,
    Set<String> checkedKeyEvents,
    Set<String> deactivatedNpcs,
  )?
  onJump;

  /// PREP mode only: go back to the scene we arrived from. The host provides it
  /// (non-null) only when there IS a previous scene; the play view then shows a
  /// **Previous scene** button first in the Next scenes row.
  final VoidCallback? onPreviousScene;

  /// REPLAY mode: step BACK/FORWARD through the finished session's recorded scene
  /// chronology (history.json). The Next scenes row shows ONLY these two buttons;
  /// each is null (disabled) at the respective end of the chronology.
  final VoidCallback? onReplayPrevious;
  final VoidCallback? onReplayNext;

  /// Resolves a note image embed's `<scope>:<uuid>` reference to its file, so the
  /// note content window renders embedded images. Null shows a broken-image glyph.
  final File? Function(String reference)? noteImageResolver;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  /// Rail expanded (icons + labels) vs collapsed (icons only), backed by the
  /// app-wide [RailState] so the choice is preserved across views.
  bool get _extended => RailState.extended.value;

  /// What the stage's RIGHT column shows (the left narration column is ALWAYS
  /// present). Initialised in [initState] to [_defaultPanel] — the first of
  /// NPC / Notes / Images / GM Notes that has content — and changed when a rail
  /// item is tapped. [_effectiveCenter] falls back to [_defaultPanel] if the
  /// selected panel loses its content mid-scene.
  late _CenterView _center;

  late final Set<String> _checked = {
    for (final ke in widget.keyEvents)
      if (ke.checked) ke.name,
  };

  /// NPCs the GM has greyed out (deactivated) this session — by `npc_uuid`. A
  /// tile's deactivate button toggles membership; a greyed image marks it. The
  /// set is carried to the host on the next scene navigation, which persists each
  /// listed NPC's `npcs[].state` as "inactive" (gameplay only). An NPC ALREADY
  /// `inactive` on disk is greyed without being in this set (see [_npcGreyed]).
  final Set<String> _deactivatedNpcs = {};

  /// Live heights of the two bottom rows. The rows wrap to a variable number of
  /// lines, so a [_MeasureSize] listener on each row pushes its current rendered
  /// height here; the rail's legend indicators ([_bottomIndicators]) mirror these
  /// so each icon sits at exactly its row's height. One-directional: the row
  /// drives the indicator, never the reverse.
  final ValueNotifier<double> _keyEventsRowHeight = ValueNotifier<double>(0);
  final ValueNotifier<double> _nextScenesRowHeight = ValueNotifier<double>(0);

  /// Whether the scene's music is currently playing (drives the Soundtrack rail
  /// item's glyph: Music Off while playing, Music Note while paused/stopped).
  bool _musicPlaying = false;

  /// Whether the track has been started at least once this view (so toggling can
  /// RESUME a paused track instead of restarting it). False until the first play.
  bool _musicStarted = false;

  /// The most-recently-mounted Play view "owns" the audio. Following a next scene
  /// REPLACES the route, and the replaced view's [dispose] fires AFTER the new
  /// view's [initState]; without this guard that late dispose would stop the new
  /// scene's music. Each view takes the next token on mount and only stops on
  /// dispose when it is still the owner.
  static int _audioOwner = 0;
  int _audioToken = 0;

  @override
  void initState() {
    super.initState();
    RailState.extended.addListener(_onRailChanged);
    // The right column opens on the first panel that has content (NPC first).
    _center = _defaultPanel();
    _audioToken = ++_audioOwner;
    // Music is scoped to ONE scene: each scene's view establishes its own audio
    // on open. When the scene has a soundtrack and Autoplay is on (default), it
    // starts that track (looping), replacing whatever the previous scene played.
    // Otherwise it STOPS playback, so following a next scene that has no music
    // (or with Autoplay off) silences the previous scene's track rather than
    // letting it bleed through. Fire-and-forget: playback runs on the service.
    final track = widget.soundtrack;
    if (track != null && widget.autoplayMusic) {
      _musicPlaying = true;
      _musicStarted = true;
      AudioPlayerService.instance.playFromStart(track.path, loop: true);
    } else {
      AudioPlayerService.instance.stop();
    }
  }

  /// Rebuilds when the shared rail state changes (e.g. toggled on another view).
  void _onRailChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RailState.extended.removeListener(_onRailChanged);
    // Leaving the scene stops its music — but only if a newer Play view has not
    // already taken over the audio (see [_audioOwner]).
    if (widget.soundtrack != null && _audioToken == _audioOwner) {
      AudioPlayerService.instance.stop();
    }
    _keyEventsRowHeight.dispose();
    _nextScenesRowHeight.dispose();
    super.dispose();
  }

  bool get _hasNpcs => _visibleNpcs.isNotEmpty;

  /// Whether the Villains rail item shows — the adventure has at least one 7th
  /// Sea Villain-kind NPC, regardless of scene attachment or active/inactive
  /// state (an inactive villain still counts; it shows greyed, not hidden).
  bool get _hasVillains => widget.villains.isNotEmpty;
  bool get _hasNotes => widget.notes.isNotEmpty || widget.seenNotes.isNotEmpty;
  bool get _hasImages =>
      widget.images.isNotEmpty || widget.seenImages.isNotEmpty;
  bool get _hasSoundtrack => widget.soundtrack != null;

  /// Replaying a finished session (read-only chronological playback).
  bool get _replay => widget.mode == PlayMode.replay;

  /// Toggle the scene's music. Tapping Music Off PAUSES the looping track (the
  /// position is kept); tapping Music Note resumes it — or starts it the first
  /// time (e.g. when autoplay is off). An ACTION, not a centre-slot selector.
  void _toggleMusic() {
    final track = widget.soundtrack;
    if (track == null) return;
    setState(() {
      if (_musicPlaying) {
        _musicPlaying = false;
        AudioPlayerService.instance.pause();
      } else {
        _musicPlaying = true;
        if (_musicStarted) {
          AudioPlayerService.instance.resume();
        } else {
          _musicStarted = true;
          AudioPlayerService.instance.playFromStart(track.path, loop: true);
        }
      }
    });
  }

  /// Whether each bottom row actually renders (mirrors [_bottomRow]'s
  /// children-empty check), so the rail shows a legend indicator only for a row
  /// that is present. The key-events row shows when the scene has at least one
  /// UNCHECKED key event (already-checked events are hidden — see the row build);
  /// the next-scenes row shows when any next scene is currently visible or the
  /// Ad-hoc button is present (every non-ending scene).
  bool get _keyEventsRowPresent => widget.keyEvents.any((ke) => !ke.checked);
  bool get _nextScenesRowPresent =>
      widget.nextScenes.any(_nextSceneVisible) ||
      widget.scene.sceneType != 'end';

  void _toggleKeyEvent(String name) => setState(() {
    if (!_checked.remove(name)) _checked.add(name);
  });

  /// Whether an NPC is persisted `inactive`. The Play view's NPC section shows
  /// ONLY active NPCs, so an inactive NPC is not displayed at all (see
  /// [_visibleNpcs]).
  bool _npcInactive(PlayNpc npc) => npc.state == 'inactive';

  /// The scene's NPCs shown in the grid / driving the rail item: ONLY those with
  /// an active state. An NPC greyed THIS session is still `active` on disk (the
  /// commit happens on the next scene navigation), so it stays visible — greyed —
  /// until then; only a committed-`inactive` NPC drops out.
  List<PlayNpc> get _visibleNpcs => [
    for (final n in widget.npcs)
      if (!_npcInactive(n)) n,
  ];

  /// Toggle a shown NPC's session deactivation (greys / restores its tile). The
  /// greyed set is committed as `npcs[].state == "inactive"` on the next scene
  /// navigation (gameplay), after which the NPC no longer appears here.
  void _toggleNpc(String uuid) => setState(() {
    if (!_deactivatedNpcs.remove(uuid)) _deactivatedNpcs.add(uuid);
  });

  /// Desaturating filter for a greyed (deactivated / inactive) NPC tile — the
  /// standard luminance weights, alpha untouched.
  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  /// Whether a next-scene button is currently shown. A VISITED target is never
  /// offered (an already-seen scene drops out of the Next scenes row; a
  /// `recurring` scene is never marked visited, so it stays). Otherwise its
  /// visibility gate must be satisfied by the checked key events — an empty gate
  /// is always visible; `and` needs every listed event checked, `or` needs any.
  bool _nextSceneVisible(PlayNextScene ns) {
    if (ns.visited) return false;
    if (ns.requiredEvents.isEmpty) return true;
    return ns.op == VisibilityOp.and
        ? ns.requiredEvents.every(_checked.contains)
        : ns.requiredEvents.any(_checked.contains);
  }

  /// A dead end: after filtering (visited + visibility gate) NO next scene is
  /// visible. The always-available ad-hoc / split / jump actions do not count.
  bool get _deadEnd => !widget.nextScenes.any(_nextSceneVisible);

  /// Whether to show the **Jump to scene** button: the host wired [onJump] (not
  /// the editor preview / replay), it is not an end scene, and the party is split
  /// OR the focused track is in a dead end.
  bool get _showJump =>
      widget.onJump != null &&
      !_replay &&
      widget.scene.sceneType != 'end' &&
      (widget.isSplit || _deadEnd);

  /// The right column's DEFAULT panel: the FIRST of NPC / Notes / Images / GM
  /// Notes that has content, in that order. GM Notes always qualifies (its add
  /// tile in editable modes; any linked notes in replay), so it is the fallback.
  /// Resolved on open ([initState]) and whenever the current selection loses its
  /// content ([_effectiveCenter]).
  _CenterView _defaultPanel() {
    if (_hasNpcs) return _CenterView.npcs;
    if (_hasNotes) return _CenterView.notes;
    if (_hasImages) return _CenterView.images;
    return _CenterView.gmnotes;
  }

  /// The panel actually shown: the selected [_center] when it still has content,
  /// otherwise the [_defaultPanel]. Guards against a selected panel emptying
  /// mid-scene (e.g. every NPC deactivated, so its rail item disappears).
  _CenterView get _effectiveCenter {
    final available = switch (_center) {
      _CenterView.npcs => _hasNpcs,
      _CenterView.villains => _hasVillains,
      _CenterView.notes => _hasNotes,
      _CenterView.images => _hasImages,
      _CenterView.gmnotes => true,
      _CenterView.map => widget.mapView != null,
    };
    return available ? _center : _defaultPanel();
  }

  void _selectCenter(_CenterView view) => setState(() => _center = view);

  // --- Pause -------------------------------------------------------------

  void _handlePause() {
    // Preview and Replay just leave; only a gameplay session confirms + saves.
    if (widget.mode != PlayMode.gameplay) {
      widget.onExit();
      return;
    }
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('play.pause.dialog'),
        content: Text(l10n.playPauseConfirm),
        actions: [
          TextButton(
            key: const ValueKey('play.pause.cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('play.pause.ok'),
            onPressed: () {
              Navigator.of(ctx).pop();
              (widget.onSaveAndExit ?? widget.onExit)();
            },
            child: Text(l10n.dialogOk),
          ),
        ],
      ),
    );
  }

  // --- Notes / Images centre views ---------------------------------------

  /// The Notes centre view — a scrolling list of note tiles showing JUST the
  /// note name (no content, no delete button). Tapping a tile opens a window
  /// with the note's content. The tiles reuse the solid secondaryContainer /
  /// onSecondaryContainer tile pair (like the Notes section's note tile).
  Widget _notesCenter(BuildContext context) {
    // The scene's own notes, then (below a divider) the "seen" gallery — notes
    // already seen earlier this playthrough. No scroll of its own — it rides the
    // shared middle scroll.
    return Column(
      key: const ValueKey('play.notes.center'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in widget.notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: _noteTile(context, n, 'play.note.tile.${n.uuid}'),
          ),
        if (widget.seenNotes.isNotEmpty) ...[
          const Divider(
            key: ValueKey('play.notes.seen.divider'),
            height: 24,
            indent: 16,
            endIndent: 16,
          ),
          for (final n in widget.seenNotes)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: _noteTile(context, n, 'play.note.seen.${n.uuid}'),
            ),
        ],
      ],
    );
  }

  /// A single note tile (name only; tap opens the content window). [keyId] keys
  /// the tile (and `<keyId>.label` the name) so scene vs seen tiles are distinct.
  Widget _noteTile(
    BuildContext context,
    ({String uuid, String name, String content}) n,
    String keyId,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey(keyId),
        onTap: () => _openNoteContent(context, n),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.note_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  n.name,
                  key: ValueKey('$keyId.label'),
                  style: TextStyle(color: scheme.onSecondaryContainer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Raise the note content window: the note's content, with a Close button at
  /// the bottom.
  void _openNoteContent(
    BuildContext context,
    ({String uuid, String name, String content}) note,
  ) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: ValueKey('play.note.info.${note.uuid}'),
        // Scrollable so the fixed 480×360 content box scrolls with title +
        // actions on a SHORT window instead of overflowing (resize audit,
        // Finding 3).
        scrollable: true,
        title: Text(note.name),
        // The body is authored with flutter_quill; render it read-only so its
        // formatting AND embedded images show exactly as prepared (legacy plain
        // text loads as a single run).
        content: SizedBox(
          width: 480,
          height: 360,
          child: _NoteContentView(
            key: ValueKey('play.note.info.${note.uuid}.content'),
            content: note.content,
            imageResolver: widget.noteImageResolver,
          ),
        ),
        actions: [
          TextButton(
            key: ValueKey('play.note.info.${note.uuid}.close'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogClose),
          ),
        ],
      ),
    );
  }

  /// The Images centre view — a SQUARE-cell photo grid like the adventure's
  /// Images section, without the "+" add cell or per-tile
  /// delete button. Tapping a cell opens the full-size viewer.
  Widget _imagesCenter(BuildContext context) {
    // The scene's own images, then (below a divider) the "seen" gallery — images
    // already seen earlier this playthrough. Rides the shared middle scroll.
    final sceneFiles = [
      for (final f in widget.images)
        if (f.existsSync()) f,
    ];
    final seenFiles = [
      for (final f in widget.seenImages)
        if (f.existsSync()) f,
    ];
    return Column(
      key: const ValueKey('play.images.center'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _imageGrid(context, sceneFiles, seen: false),
        if (seenFiles.isNotEmpty) ...[
          const Divider(
            key: ValueKey('play.images.seen.divider'),
            height: 24,
            indent: 24,
            endIndent: 24,
          ),
          _imageGrid(context, seenFiles, seen: true),
        ],
      ],
    );
  }

  /// A square-cell photo grid (no scroll of its own). [seen] switches the tile
  /// keys between the scene grid (`play.image.tile.<uuid>`) and the seen gallery
  /// (`play.image.seen.<uuid>`).
  Widget _imageGrid(
    BuildContext context,
    List<File> files, {
    required bool seen,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final uuid = _imageUuid(file);
        return Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey(
              seen ? 'play.image.seen.$uuid' : 'play.image.tile.$uuid',
            ),
            onTap: () => _openImageViewer(context, file, uuid),
            child: Image.file(file, fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  /// The image_uuid of an image file (its name without the `.png` extension).
  String _imageUuid(File f) {
    final base = f.uri.pathSegments.last;
    final dot = base.lastIndexOf('.');
    return dot == -1 ? base : base.substring(0, dot);
  }

  /// Raise the full-size image viewer: the image at its original size, scaled
  /// down to fit the screen when larger (never upscaled). A close button in the
  /// top-right corner pops it off the top of the stack.
  void _openImageViewer(BuildContext context, File file, String uuid) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        key: ValueKey('play.image.viewer.$uuid'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            Center(
              child: Image.file(
                file,
                key: ValueKey('play.image.viewer.$uuid.image'),
                fit: BoxFit.scaleDown,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SizedBox(
                width: 48,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.onSecondaryContainer,
                  ),
                  child: IconButton(
                    key: ValueKey('play.image.viewer.$uuid.close'),
                    icon: const Icon(Icons.close),
                    color: scheme.secondaryContainer,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final railItems = <({IconData icon, String label, String key, VoidCallback onTap})>[
      (
        icon: Icons.pause_circle,
        label: l10n.playPauseSession,
        key: 'nav.play.pause',
        onTap: _handlePause,
      ),
      // NOTE: no Narration item — the narration is ALWAYS visible in the stage's
      // left column, so it is not a selectable rail destination.
      if (_hasNpcs)
        (
          icon: Icons.person,
          label: l10n.sceneSectionNpc,
          key: 'nav.play.npc',
          onTap: () => _selectCenter(_CenterView.npcs),
        ),
      if (_hasNotes)
        (
          icon: Icons.library_books,
          label: l10n.sceneSectionNotes,
          key: 'nav.play.notes',
          onTap: () => _selectCenter(_CenterView.notes),
        ),
      if (_hasImages)
        (
          icon: Icons.photo_library,
          label: l10n.sceneSectionImages,
          key: 'nav.play.images',
          onTap: () => _selectCenter(_CenterView.images),
        ),
      // SOUNDTRACK — an ACTION (not a centre-slot selector): toggles the scene's
      // music. Present only when the scene has a soundtrack. The glyph reflects
      // playback: Music Off while playing, Music Note while stopped.
      if (_hasSoundtrack)
        (
          icon: _musicPlaying ? Icons.music_off : Icons.music_note,
          label: l10n.sceneSectionAudio,
          key: 'nav.play.soundtrack',
          onTap: _toggleMusic,
        ),
      // MAP — the scene map for the whole adventure. DISABLED for now (kept for
      // future work; see docs/scene_map_widget.md). Re-enable this rail item
      // together with PlaythroughScreen's `mapView:` argument.
      // if (widget.mapView != null)
      //   (
      //     icon: Icons.map,
      //     label: l10n.navMap,
      //     key: 'nav.play.map',
      //     onTap: () => _selectCenter(_CenterView.map)
      //   ),
      // GM Notes.
      (
        icon: Symbols.clinical_notes,
        label: l10n.playGmNotes,
        key: 'nav.play.gmnotes',
        onTap: () => _selectCenter(_CenterView.gmnotes),
      ),
      // VILLAINS — 7th Sea 2e only, ALWAYS the LAST rail item: shown whenever
      // the adventure has at least one Villain-kind NPC, regardless of scene
      // attachment. The label spells out "(global)" / "(wszyscy)"
      // since it is the one rail item that is NOT scene-scoped.
      if (_hasVillains)
        (
          icon: Symbols.sentiment_extremely_dissatisfied,
          label: l10n.playVillains,
          key: 'nav.play.villains',
          onTap: () => _selectCenter(_CenterView.villains),
        ),
    ];

    return Scaffold(
      key: const ValueKey('play.root'),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // BACKGROUND — the location image fills the WHOLE window so toggling
          // the rail never resizes it.
          _background(scheme),
          SafeArea(
            // The stage plus a floating PiP bar of the un-focused tracks
            // (top-right, clear of the left rail and the top-left title).
            child: Stack(
              children: [
                Row(
                  children: [
                    NavigationRail(
                      // Key by the extended state so toggling REPLACES the rail with
                      // a fresh instance already at the target layout instead of
                      // animating — the rail is STATIC: expand/collapse is instant,
                      // no slide/reveal animation.
                      key: ValueKey('play.rail.$_extended'),
                      // Solid background — the side menu covers the location image
                      // behind it. The image still fills the whole window (it is
                      // merely hidden under the rail), so toggling the rail never
                      // resizes it.
                      backgroundColor: scheme.surface,
                      leading: RailMenuButton(
                        key: const ValueKey('nav.play.menu'),
                        tooltip: l10n.menuTooltip,
                        onTap: RailState.toggle,
                      ),
                      extended: _extended,
                      labelType: NavigationRailLabelType.none,
                      selectedIndex: null,
                      onDestinationSelected: (i) => railItems[i].onTap(),
                      destinations: [
                        for (final item in railItems)
                          NavigationRailDestination(
                            icon: Icon(item.icon, key: ValueKey(item.key)),
                            selectedIcon: Icon(
                              item.icon,
                              key: ValueKey(item.key),
                            ),
                            label: Text(item.label),
                          ),
                      ],
                      // LEGEND — pinned to the rail's bottom so each indicator lines
                      // up with its bottom row in the stage (both flush to the same
                      // SafeArea bottom; equal heights => row-by-row alignment).
                      trailingAtBottom: true,
                      trailing: _bottomIndicators(l10n, scheme),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: _stage(context, l10n, scheme)),
                  ],
                ),
                // PiP BAR — the un-focused tracks, floating at the top-right.
                if (widget.pipTracks.isNotEmpty)
                  Positioned(top: 8, right: 8, child: _pipBar(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The floating PiP bar: a vertical, height-capped, scrollable column of the
  /// un-focused tracks' thumbnails (top-right of the stage). Tapping one switches
  /// focus to it. Shown only while the party is split (pipTracks non-empty).
  Widget _pipBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height - 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in widget.pipTracks)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PipTrackTile(
                  key: ValueKey('play.pip.${t.trackId}'),
                  backgroundImage: t.backgroundImage,
                  pcLabel: t.pcLabel,
                  tooltip: l10n.playPipSwitchFocus,
                  onTap: () => widget.onFocusSwitch?.call(t.trackId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stage(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    final scrim = Colors.black.withValues(alpha: 0.5);
    final onScrim = Colors.white;
    final title = widget.scene.name;

    // The location image is painted by the Scaffold-level background (see
    // [build]); this overlay column floats over it. The title bar and the two
    // bottom rows are FIXED; only the middle (narration + right panel) scrolls.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TITLE — the full-width row is transparent; only the title text
        // sits in its own translucent container hugging its content.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Flexible(
                child: Container(
                  color: scrim,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    title,
                    key: const ValueKey('play.scene.title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: onScrim),
                  ),
                ),
              ),
            ],
          ),
        ),
        // MIDDLE — ONE shared scroll holding the left narration column
        // (always present, capped at 45% of the field width, shrinking to
        // its content) and the right panel (the selected rail item). Both
        // columns scroll together. The field is an Expanded sibling of the
        // rail, so it shrinks when the rail expands; the 45% is taken from
        // the field's LIVE width, so the narration column shrinks with it.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    key: const ValueKey('play.narration.column'),
                    // FIXED at 45% of the field: the narration column is as WIDE
                    // as its cap allows (never shrunk to its content), so short
                    // and long narrations occupy the same column; it shrinks with
                    // the field when the rail expands.
                    width: constraints.maxWidth * 0.45,
                    child: _narration(context, onScrim),
                  ),
                  Expanded(child: _rightPanel(context, scheme)),
                ],
              ),
            ),
          ),
        ),
        // KEY EVENTS ROW — solid-background buttons. Its rendered height
        // (it wraps to a variable number of lines) is mirrored into the
        // rail's legend indicator via [_MeasureSize]. Already-checked
        // (committed in a prior scene) key events are NOT shown — only the
        // scene's still-unchecked events get a button.
        _MeasureSize(
          onChange: (s) => _keyEventsRowHeight.value = s.height,
          child: _bottomRow(
            keyId: 'play.keyevents.row',
            children: [
              for (final ke in widget.keyEvents)
                // Play/Prep: only the still-UNCHECKED events get a
                // (toggleable) button. Replay: ALL events show, DISABLED,
                // reflecting their recorded state.
                if (_replay || !ke.checked)
                  FilledButton(
                    key: ValueKey('play.keyevent.${ke.name}'),
                    style: _solidButtonStyle(scheme),
                    onPressed: _replay ? null : () => _toggleKeyEvent(ke.name),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IgnorePointer(
                          child: Checkbox(
                            key: ValueKey('play.keyevent.${ke.name}.check'),
                            // Shrink the tap target so the checkbox does not
                            // inflate the button past _bottomButtonHeight.
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            value: _replay
                                ? ke.checked
                                : _checked.contains(ke.name),
                            onChanged: (_) {},
                          ),
                        ),
                        Text(ke.name),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        // NEXT SCENES ROW (+ ad-hoc) — solid-background buttons. Its
        // rendered height is likewise mirrored into the rail's indicator.
        _MeasureSize(
          onChange: (s) => _nextScenesRowHeight.value = s.height,
          child: _bottomRow(
            keyId: 'play.nextscenes.row',
            children: _nextScenesChildren(l10n, scheme),
          ),
        ),
      ],
    );
  }

  /// The Next scenes row's buttons. REPLAY shows ONLY Previous/Next stepping the
  /// finished session's chronology; otherwise the next-scene buttons (+ the prep
  /// Previous, ad-hoc and gameplay Finish actions).
  List<Widget> _nextScenesChildren(AppLocalizations l10n, ColorScheme scheme) {
    if (_replay) {
      return [
        FilledButton.icon(
          key: const ValueKey('play.replay.previous'),
          style: _solidButtonStyle(scheme),
          onPressed: widget.onReplayPrevious,
          icon: const Icon(Icons.arrow_back),
          label: Text(l10n.playPreviousScene),
        ),
        FilledButton.icon(
          key: const ValueKey('play.replay.next'),
          style: _solidButtonStyle(scheme),
          onPressed: widget.onReplayNext,
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.playNextScene),
        ),
      ];
    }
    return [
      // PREP mode only: the FIRST button goes back to the scene we arrived from
      // (shown once there is somewhere to go back to).
      if (widget.mode == PlayMode.preview && widget.onPreviousScene != null)
        FilledButton.icon(
          key: const ValueKey('play.nextscene.previous'),
          style: _solidButtonStyle(scheme),
          onPressed: widget.onPreviousScene,
          icon: const Icon(Icons.arrow_back),
          label: Text(l10n.playPreviousScene),
        ),
      for (final ns in widget.nextScenes)
        if (_nextSceneVisible(ns))
          FilledButton(
            key: ValueKey('play.nextscene.${ns.name}'),
            style: _solidButtonStyle(scheme),
            onPressed: () => widget.onFollowScene?.call(
              ns.uuid,
              Set<String>.from(_checked),
              Set<String>.from(_deactivatedNpcs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(ns.name),
                for (final d in ns.discs)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      key: ValueKey(
                        'play.nextscene.${ns.name}.path.${d.colorId}',
                      ),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d.color,
                        border: Border.all(
                          color: scheme.onSecondaryContainer,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                // MERGE marker — another active track already stands here;
                // following this scene merges the two.
                if (ns.occupiedByOtherTrack)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: l10n.playMergeHint,
                      child: Icon(
                        Icons.merge,
                        key: ValueKey('play.nextscene.${ns.name}.merge'),
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      if (widget.scene.sceneType != 'end')
        FilledButton.icon(
          key: const ValueKey('play.nextscene.adhoc'),
          style: _solidButtonStyle(scheme),
          onPressed: () => _showAdHocDialog(context),
          icon: const Icon(Icons.add),
          label: Text(l10n.playAdHocScene),
        ),
      // Split the party (gameplay/prep, non-end scenes). Shown whenever the host
      // wires onSplit (NOT in the editor preview / replay); disabled while a
      // split is not possible (roster cap reached, or a solo focused track).
      if (widget.onSplit != null && widget.scene.sceneType != 'end')
        FilledButton.icon(
          key: const ValueKey('play.split'),
          style: _solidButtonStyle(scheme),
          onPressed: widget.canSplit ? () => _showSplitDialog(context) : null,
          icon: const Icon(Icons.group_add),
          label: Text(l10n.playSplitParty),
        ),
      // Jump to scene — an escape/rendezvous route, shown when the party is split
      // OR the focused track is in a dead end (no visible next scenes). Not on an
      // end scene, nor in the editor preview / replay (onJump gates it out).
      if (_showJump)
        FilledButton.icon(
          key: const ValueKey('play.jump'),
          style: _solidButtonStyle(scheme),
          onPressed: () => _showJumpDialog(context),
          icon: const Icon(Icons.my_location),
          label: Text(l10n.playJumpToScene),
        ),
      // An END scene has no next scenes; in gameplay it offers Finish adventure.
      // While the party is SPLIT (more than one active track) the whole
      // adventure can only be finished once EVERY track has reached an end scene
      // (allTracksAtEnd, not necessarily the SAME scene) — until then the button
      // is DISABLED and the GM must bring the other tracks to an end scene. A
      // single (un-split) track always finishes straight away.
      if (widget.mode == PlayMode.gameplay && widget.scene.sceneType == 'end')
        FilledButton.icon(
          key: const ValueKey('play.finish'),
          style: _solidButtonStyle(scheme),
          onPressed: (!widget.isSplit || widget.allTracksAtEnd)
              ? widget.onFinishAdventure
              : null,
          icon: const Icon(Icons.flag_outlined),
          label: Text(l10n.playFinishAdventure),
        ),
    ];
  }

  /// The scene's bg_image painted across the WHOLE window (behind the rail too),
  /// so opening/closing the rail never changes its size. A flat surface colour
  /// shows when the scene has no bg_image.
  Widget _background(ColorScheme scheme) {
    if (widget.backgroundImage != null &&
        widget.backgroundImage!.existsSync()) {
      return Image.file(
        widget.backgroundImage!,
        key: const ValueKey('play.location.image'),
        fit: BoxFit.cover,
      );
    }
    return ColoredBox(
      key: const ValueKey('play.location.image'),
      color: scheme.surface,
    );
  }

  /// The widget filling the stage's RIGHT column for the current selection
  /// ([_effectiveCenter]): a header naming the shown content (matching the rail
  /// item that selected it) ABOVE the panel body. Each panel SHRINK-WRAPS (no
  /// scroll of its own) so it shares the single middle scroll with the left
  /// narration column.
  Widget _rightPanel(BuildContext context, ColorScheme scheme) {
    final l10n = AppLocalizations.of(context);
    final view = _effectiveCenter;
    final Widget body = switch (view) {
      _CenterView.npcs => _npcGrid(context, scheme),
      _CenterView.villains => _villainsGrid(context, scheme),
      _CenterView.notes => _notesCenter(context),
      _CenterView.images => _imagesCenter(context),
      _CenterView.gmnotes => _gmNotesCenter(context),
      _CenterView.map => widget.mapView ?? const SizedBox.shrink(),
    };
    // The panel's title — the SAME label as the rail item that selects it.
    final String title = switch (view) {
      _CenterView.npcs => l10n.sceneSectionNpc,
      _CenterView.villains => l10n.playVillains,
      _CenterView.notes => l10n.sceneSectionNotes,
      _CenterView.images => l10n.sceneSectionImages,
      _CenterView.gmnotes => l10n.playGmNotes,
      _CenterView.map => l10n.navMap,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_panelHeader(context, title), body],
    );
  }

  /// The RIGHT column's header: a translucent scrim block (like the scene title
  /// bar) that NAMES the content shown below it — NPC / Notes / Images / GM
  /// Notes, the SAME label as the rail item that selected the panel. It sits
  /// ABOVE the panel body and rides the shared middle scroll. Hugs its text (it
  /// does NOT span the full column width).
  Widget _panelHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Flexible(
            child: Container(
              key: const ValueKey('play.panel.title.box'),
              color: Colors.black.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                title,
                key: const ValueKey('play.panel.title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The GM Notes centre view — a grid whose FIRST cell adds a GM note (opens the
  /// add form) and the rest are the current scene's GM notes (tap -> content
  /// window). Displays all GM notes linked to this scene.
  Widget _gmNotesCenter(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      key: const ValueKey('play.gmnotes.center'),
      // No scroll of its own — it rides the shared middle scroll.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      // Adventure-tile proportions + size (220 wide, 1:1.43 portrait).
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 1 / 1.43,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      // REPLAY is read-only: no add tile (GM notes cannot be added).
      itemCount: widget.gmNotes.length + (_replay ? 0 : 1),
      itemBuilder: (context, index) {
        if (!_replay && index == 0) {
          return Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('play.gmnote.new'),
              onTap: _openAddGmNote,
              child: Center(
                child: Tooltip(
                  message: AppLocalizations.of(context).playGmNoteAdd,
                  child: Icon(
                    Icons.note_add_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }
        final n = widget.gmNotes[index - (_replay ? 0 : 1)];
        return Material(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('play.gmnote.tile.${n.uuid}'),
            // Tapping the tile body opens the full-content dialog.
            onTap: () => _openGmNoteContent(context, n),
            child: Stack(
              children: [
                // The note's content, only AS MUCH AS FITS — clipped, no scroll
                // (the full text opens in a dialog on tap). A GM note has no
                // title, so the content is the only thing shown. It STARTS BELOW
                // the top-right delete icon so the icon never covers it.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 56, 12, 12),
                  child: Text(
                    n.content,
                    key: ValueKey('play.gmnote.tile.${n.uuid}.label'),
                    style: TextStyle(color: scheme.onSecondaryContainer),
                    overflow: TextOverflow.fade,
                  ),
                ),
                // TOP-RIGHT — the SAME inset round delete button as a library
                // tile (an onSecondaryContainer disc behind a secondaryContainer
                // close glyph). Absent when GM notes are read-only (replay).
                if (widget.onDeleteGmNote != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.onSecondaryContainer,
                        ),
                        child: IconButton(
                          key: ValueKey('play.gmnote.tile.${n.uuid}.delete'),
                          icon: Icon(
                            Icons.close,
                            color: scheme.secondaryContainer,
                          ),
                          onPressed: () => _confirmDeleteGmNote(context, n),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the add-GM-note form (plain content only). A GM note is always global.
  Future<void> _openAddGmNote() async {
    final content = await showAddGmNoteDialog(context);
    if (content == null) return;
    widget.onAddGmNote?.call(content);
  }

  /// The GM note DETAIL dialog (opened by a tile or its Loupe): the SAME shared
  /// format-A detail dialog as the start-scene info. A GM note has no title, so
  /// the dialog shows only its full, scrollable content.
  void _openGmNoteContent(
    BuildContext context,
    ({String uuid, String content}) note,
  ) {
    showDetailDialog(
      context,
      rootKey: 'play.gmnote.detail',
      body: note.content,
      bodyKey: 'play.gmnote.detail.content',
      okKey: 'play.gmnote.detail.ok',
    );
  }

  /// Confirms (Delete / Cancel) — the SAME shape as the Saves/Finished tile
  /// delete dialogs — then removes the GM note. A GM note has no title, so the
  /// dialog is headed by the generic GM Notes label.
  Future<void> _confirmDeleteGmNote(
    BuildContext context,
    ({String uuid, String content}) note,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('play.gmnote.delete.dialog'),
        title: Text(l10n.playGmNotes),
        content: Text(l10n.playGmNoteDeleteMessage),
        actions: [
          TextButton(
            key: const ValueKey('play.gmnote.delete.cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.unsavedCancel),
          ),
          FilledButton(
            key: const ValueKey('play.gmnote.delete.confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.adventureDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.onDeleteGmNote?.call(note.uuid);
  }

  /// The **Split party** dialog: pick which of the focused track's PC move to a
  /// new track. Confirm is enabled only when at least one PC is selected AND at
  /// least one is left behind (you cannot move all or none). The chosen set is
  /// handed to [onSplit]; the new track starts on the current scene.
  Future<void> _showSplitDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final names = widget.focusedPcNames;
    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // At least one moves AND at least one stays.
          final valid = selected.isNotEmpty && selected.length < names.length;
          return AlertDialog(
            key: const ValueKey('play.split.dialog'),
            title: Text(l10n.playSplitTitle),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.playSplitAssignHint),
                  const SizedBox(height: 8),
                  // Bounded + scrollable so a long roster never overflows.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final name in names)
                            CheckboxListTile(
                              key: ValueKey('play.split.pc.$name'),
                              value: selected.contains(name),
                              title: Text(name),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (v) => setLocal(() {
                                if (v == true) {
                                  selected.add(name);
                                } else {
                                  selected.remove(name);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('play.split.cancel'),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.unsavedCancel),
              ),
              FilledButton(
                key: const ValueKey('play.split.confirm'),
                onPressed: valid
                    ? () => Navigator.of(ctx).pop({...selected})
                    : null,
                child: Text(l10n.playSplitConfirm),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && result.isNotEmpty) {
      widget.onSplit?.call(result);
    }
  }

  /// The **Ad-hoc scene** dialog: the GM names the improvised scene (its only
  /// content). Confirm is disabled while the name is blank. On confirm the name
  /// is handed to [onAdHoc], which mints the scene's uuid and inherits its
  /// next_scenes from the current scene.
  Future<void> _showAdHocDialog(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AdHocNameDialog(),
    );
    if (name != null && name.isNotEmpty) {
      widget.onAdHoc?.call(
        name,
        Set<String>.from(_checked),
        Set<String>.from(_deactivatedNpcs),
      );
    }
  }

  /// The **Jump to scene** dialog: a scrollable list of targets — other tracks'
  /// positions (top, "-> merge") then unvisited author scenes. Choosing one
  /// hands its uuid to [onJump] (an ordinary navigation that also merges when it
  /// lands on another track).
  Future<void> _showJumpDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final uuid = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('play.jump.dialog'),
        title: Text(l10n.playJumpTitle),
        content: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in widget.jumpTargets)
                    ListTile(
                      key: ValueKey('play.jump.target.${t.uuid}'),
                      title: Text(t.name),
                      trailing: t.otherTrackHere
                          ? Tooltip(
                              message: l10n.playMergeHint,
                              child: Icon(
                                Icons.merge,
                                key: ValueKey(
                                  'play.jump.target.${t.uuid}.merge',
                                ),
                              ),
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop(t.uuid),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('play.jump.cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.unsavedCancel),
          ),
        ],
      ),
    );
    if (uuid != null) {
      widget.onJump?.call(
        uuid,
        Set<String>.from(_checked),
        Set<String>.from(_deactivatedNpcs),
      );
    }
  }

  /// The always-present LEFT narration column: a translucent scrim block holding
  /// the scene's description. The caller ([_stage]) FIXES its width at 45% of the
  /// field, so the block is as wide as that cap allows (not shrunk to its
  /// content); the text wraps within it. It has NO scroll of its own — it rides
  /// the shared middle scroll, so a long narration scrolls together with the
  /// right panel.
  Widget _narration(BuildContext context, Color onScrim) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(16),
        child: Text(
          widget.scene.description,
          key: const ValueKey('play.scene.narration'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: onScrim),
        ),
      ),
    );
  }

  // --- NPC grid + info window -------------------------------------------

  /// The NPC grid that replaces the narration/location slot when NPC is selected.
  /// Same cell sizing as the game NPC grid; each tile is the NPC's icon image.
  ///
  /// Only ACTIVE NPCs are shown ([_visibleNpcs]) — an `inactive` NPC does not
  /// appear here at all. Each tile carries a top-right inset round DEACTIVATE
  /// button (the same shape as a library tile's delete button, glyph
  /// `Symbols.account_circle_off`) that greys the NPC's image — a session toggle
  /// committed as `npcs[].state == "inactive"` on the next scene navigation,
  /// after which the NPC drops out of this grid. Tapping a tile opens the NPC
  /// info window. The button is absent in REPLAY (read-only).
  Widget _npcGrid(BuildContext context, ColorScheme scheme) {
    final npcs = _visibleNpcs;
    return GridView.builder(
      key: const ValueKey('play.npc.grid'),
      // No scroll of its own — it rides the shared middle scroll.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: NpcTile.maxExtent,
        childAspectRatio: NpcTile.aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: npcs.length,
      itemBuilder: (context, i) {
        final npc = npcs[i];
        final hasIcon = npc.iconImage != null && npc.iconImage!.existsSync();
        // A shown NPC is always active; it greys only while deactivated THIS
        // session (pending commit on the next scene navigation).
        final greyed = _deactivatedNpcs.contains(npc.uuid);
        Widget image = hasIcon
            ? Image.file(npc.iconImage!, fit: BoxFit.cover)
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    npc.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              );
        if (greyed) {
          image = ColorFiltered(colorFilter: _greyscale, child: image);
        }
        return Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  InkWell(
                    key: ValueKey('play.npc.tile.${npc.uuid}'),
                    onTap: () => _openNpcInfo(npc),
                    // A 7th Sea Villain shows the SAME Strength/Influence/Rank badges
                    // as the game NPC grid, at the tile's bottom.
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        if (npc.villain != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: NpcVillainBadges(
                              keyPrefix: 'play.npc.tile.${npc.uuid}',
                              villain: npc.villain!,
                              tileHeight: constraints.maxHeight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // TOP-RIGHT — the deactivate toggle. Absent in replay (read-only).
                  if (!_replay)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.onSecondaryContainer,
                          ),
                          child: IconButton(
                            key: ValueKey(
                              'play.npc.tile.${npc.uuid}.deactivate',
                            ),
                            tooltip: AppLocalizations.of(
                              context,
                            ).playNpcDeactivate,
                            icon: Icon(
                              Symbols.account_circle_off,
                              color: scheme.secondaryContainer,
                            ),
                            onPressed: () => _toggleNpc(npc.uuid),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// The Villains grid (`nav.play.villains`, 7th Sea 2e only): EVERY Villain-kind
  /// NPC in the WHOLE adventure ([widget.villains]), NOT scoped to the current
  /// scene. Same tile shape as [_npcGrid] — the icon image plus the villain's
  /// Strength / Influence / Rank badges — but WITHOUT a deactivate button: a
  /// villain can only be deactivated from the NPC tab. An `inactive`
  /// villain stays in the grid, greyed, rather than being dropped like the scene
  /// NPC grid. Tapping a tile opens the SAME info window (+ Schemes/Intrygi
  /// manager) as the NPC tab, so editing intrygi works identically.
  Widget _villainsGrid(BuildContext context, ColorScheme scheme) {
    final villains = widget.villains;
    return GridView.builder(
      key: const ValueKey('play.villains.grid'),
      // No scroll of its own — it rides the shared middle scroll.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: NpcTile.maxExtent,
        childAspectRatio: NpcTile.aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: villains.length,
      itemBuilder: (context, i) {
        final npc = villains[i];
        final hasIcon = npc.iconImage != null && npc.iconImage!.existsSync();
        // Greyed when persisted `inactive` — unlike the NPC tab there is no
        // session toggle here, so this is the ONLY source of the grey state.
        final greyed = npc.state == 'inactive';
        Widget image = hasIcon
            ? Image.file(npc.iconImage!, fit: BoxFit.cover)
            : ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Text(
                    npc.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              );
        if (greyed) {
          image = ColorFiltered(colorFilter: _greyscale, child: image);
        }
        return Material(
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InkWell(
                key: ValueKey('play.villain.tile.${npc.uuid}'),
                onTap: () => _openNpcInfo(npc),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    if (npc.villain != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: NpcVillainBadges(
                          keyPrefix: 'play.villain.tile.${npc.uuid}',
                          villain: npc.villain!,
                          tileHeight: constraints.maxHeight,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// The read-only NPC info window — mirrors the NPC form
  /// with content blocks instead of inputs, and WITHOUT the icon_image and
  /// visibility-rules blocks: full image (left) beside Name + Description (right),
  /// then a full-width Statistics block joining both columns (only when the NPC
  /// has stats). Close dismisses; Historia opens the backstory window on top — but
  /// only when the NPC HAS a backstory (an empty backstory hides the button).
  void _openNpcInfo(PlayNpc npc) {
    final l10n = AppLocalizations.of(context);
    final hasBackstory = npc.backstory.trim().isNotEmpty;
    // The Schemes manager + live-updating info window need the RAW stats; a
    // Villain always carries them in production. (A bare NpcVillainStats snapshot
    // with no raw stats falls back to the static, non-reactive render.)
    final isVillain =
        npc.villain?.kind == 'villain' && npc.sevenSeaStats.isNotEmpty;
    // A Villain's info window reflects LIVE stat changes made in the Schemes
    // manager: settling an Intryga recomputes the shown Influence + Rank at once.
    // The manager writes to this shared
    // notifier; a ValueListenableBuilder re-renders the info body from it.
    final statsNotifier = isVillain
        ? ValueNotifier<Map<String, dynamic>>(npc.sevenSeaStats)
        : null;
    Widget content(BuildContext ctx) {
      if (statsNotifier == null) {
        return _infoFrame(
          ctx,
          'play.npc.info.${npc.uuid}',
          _npcInfoBody(ctx, l10n, npc),
        );
      }
      return ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: statsNotifier,
        builder: (ctx, stats, _) => _infoFrame(
          ctx,
          'play.npc.info.${npc.uuid}',
          _npcInfoBody(ctx, l10n, _npcWithStats(npc, stats)),
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: ValueKey('play.npc.info.${npc.uuid}'),
        content: content(ctx),
        actions: [
          // Historia — shown ONLY when the backstory field is non-empty.
          if (hasBackstory)
            TextButton(
              key: ValueKey('play.npc.info.${npc.uuid}.history'),
              onPressed: () => _openNpcHistory(ctx, npc),
              child: Text(l10n.npcsBackstoryLabel),
            ),
          // Schemes / Intrygi — Villain only: opens the schemes manager over this
          // window, sharing [statsNotifier] so this window updates live.
          if (isVillain)
            TextButton(
              key: ValueKey('play.npc.info.${npc.uuid}.schemes'),
              onPressed: () => _openSchemesManager(ctx, npc, statsNotifier!),
              child: Text(l10n.statSeaSchemes),
            ),
          TextButton(
            key: ValueKey('play.npc.info.${npc.uuid}.close'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogClose),
          ),
        ],
      ),
    ).then((_) => statsNotifier?.dispose());
  }

  /// A copy of [npc] whose 7th Sea Villain badge values are RECOMPUTED from
  /// [stats] — used so the info window can re-render live as the Schemes manager
  /// mutates the villain's `influence` / `schemes`.
  PlayNpc _npcWithStats(PlayNpc npc, Map<String, dynamic> stats) => (
    uuid: npc.uuid,
    name: npc.name,
    iconImage: npc.iconImage,
    fullImage: npc.fullImage,
    description: npc.description,
    backstory: npc.backstory,
    state: npc.state,
    stats: npc.stats,
    villain: sevenSeaVillain(SevenSea.systemId, stats),
    sevenSeaStats: stats,
  );

  /// The Schemes / Intrygi MANAGER — Villain only, opened from the info window's
  /// "Schemes" action. The SAME responsive frame as the info window, shown on top
  /// so it fully covers it, with a single Close action. Its `onChanged` persists
  /// the villain's updated stats via the host
  /// (`onUpdateNpcStats`) in gameplay; session-only when that callback is null.
  void _openSchemesManager(
    BuildContext infoCtx,
    PlayNpc npc,
    ValueNotifier<Map<String, dynamic>> statsNotifier,
  ) {
    final l10n = AppLocalizations.of(infoCtx);
    showDialog<void>(
      context: infoCtx,
      builder: (ctx) => AlertDialog(
        key: ValueKey('play.npc.info.${npc.uuid}.schemes.dialog'),
        content: _infoFrame(
          ctx,
          'play.npc.info.${npc.uuid}.schemes',
          _SchemesManagerDialog(
            keyPrefix: 'play.npc.info.${npc.uuid}.schemes',
            // Start from the CURRENT stats (reflects any prior changes).
            initialStats: statsNotifier.value,
            onChanged: (stats) {
              // Push into the shared notifier so the info window updates live,
              // and persist via the host (gameplay).
              statsNotifier.value = stats;
              widget.onUpdateNpcStats?.call(npc.uuid, stats);
            },
          ),
        ),
        actions: [
          TextButton(
            key: ValueKey('play.npc.info.${npc.uuid}.schemes.close'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogClose),
          ),
        ],
      ),
    );
  }

  /// The backstory ("Historia") window — the SAME size as the info window, shown
  /// on top of it so it fully covers it. One block holding the NPC's backstory,
  /// with a single Close action.
  void _openNpcHistory(BuildContext infoCtx, PlayNpc npc) {
    final l10n = AppLocalizations.of(infoCtx);
    showDialog<void>(
      context: infoCtx,
      builder: (ctx) => AlertDialog(
        key: ValueKey('play.npc.history.${npc.uuid}'),
        content: _infoFrame(
          ctx,
          'play.npc.history.${npc.uuid}',
          _roBlock(
            ctx,
            keyId: 'play.npc.history.${npc.uuid}.backstory',
            label: l10n.npcsBackstoryLabel,
            value: npc.backstory,
            expand: true,
          ),
        ),
        actions: [
          TextButton(
            key: ValueKey('play.npc.history.${npc.uuid}.close'),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.dialogClose),
          ),
        ],
      ),
    );
  }

  /// Both NPC windows share this RESPONSIVE content size so the backstory window
  /// exactly covers the info window beneath it, and resizing the app never
  /// overflows (a fixed box did). The frame fills 80% of the window HEIGHT (a 10%
  /// margin top and bottom) and keeps the windows' original 3:2 proportions
  /// (720:480) — width = height × ratio. On a very narrow window the width is
  /// clamped to fit and the height follows to keep the ratio.
  static const double _infoFrameRatio = 720 / 480;
  static const double _infoFrameHeightFraction = 0.8;

  /// Horizontal space an [AlertDialog] takes around its content on the window's
  /// width: the dialog's side insets (2×40) plus its content padding (2×24). The
  /// frame width is kept within `window.width - this` so a narrow window never
  /// overflows and the proportions still hold. (Can't use a LayoutBuilder here —
  /// AlertDialog measures its content's intrinsic width, which a LayoutBuilder
  /// forbids.)
  static const double _infoFrameChromeWidth = 128;

  /// Vertical space the [AlertDialog] takes around its content: the top/bottom
  /// insets (2×24) plus the content padding (2×24) plus the actions row (Historia
  /// / Close, ~52). The frame HEIGHT is kept within `window.height - this` so a
  /// SHORT window never overflows (the 0.8-height target alone could); the width
  /// then follows from the clamped height to keep the proportions. Only binds when
  /// `0.8·H > H − this` (i.e. H below ~760), so normal windows are unaffected.
  static const double _infoFrameChromeHeight = 152;

  Widget _infoFrame(BuildContext context, String keyId, Widget child) {
    final size = MediaQuery.sizeOf(context);
    var height = size.height * _infoFrameHeightFraction;
    // Never exceed the window height minus the dialog's vertical chrome.
    final maxHeight = size.height - _infoFrameChromeHeight;
    if (height > maxHeight) height = maxHeight;
    var width = height * _infoFrameRatio;
    final maxWidth = size.width - _infoFrameChromeWidth;
    if (width > maxWidth) {
      width = maxWidth;
      height = width / _infoFrameRatio;
    }
    return SizedBox(
      key: ValueKey('$keyId.frame'),
      width: width,
      height: height,
      child: child,
    );
  }

  Widget _npcInfoBody(BuildContext ctx, AppLocalizations l10n, PlayNpc npc) {
    final scheme = Theme.of(ctx).colorScheme;
    final hasFull = npc.fullImage != null && npc.fullImage!.existsSync();
    final villain = npc.villain;

    final nameBlock = _roBlock(
      ctx,
      keyId: 'play.npc.info.${npc.uuid}.name',
      label: l10n.npcsNameLabel,
      value: npc.name,
    );

    // RIGHT column. For a plain NPC it is Name over a height-FILLING Description.
    // For a 7th Sea VILLAIN / BRUTE it also carries the tile stat blocks BELOW the
    // description; those are fixed-height, so the whole column is made SCROLLABLE
    // (the description keeps a sensible minimum) — otherwise a short/narrow dialog
    // force-fits the fixed blocks and overflows (see the resize audit, Finding 1).
    final Widget rightColumn;
    if (villain != null) {
      rightColumn = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            nameBlock,
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 96),
              child: _roBlock(
                ctx,
                keyId: 'play.npc.info.${npc.uuid}.description',
                label: l10n.npcsDescriptionLabel,
                value: npc.description,
              ),
            ),
            // The SAME stat blocks as the NPC's tile — a Villain's Strength/
            // Influence/Rank (then its Advantages in two columns) or a Brute's
            // single centered Strength.
            const SizedBox(height: 16),
            _villainBadgesBar(ctx, npc, villain),
            if (villain.advantages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _villainAdvantages(ctx, l10n, npc, villain),
            ],
          ],
        ),
      );
    } else {
      rightColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          nameBlock,
          const SizedBox(height: 16),
          Expanded(
            child: _roBlock(
              ctx,
              keyId: 'play.npc.info.${npc.uuid}.description',
              label: l10n.npcsDescriptionLabel,
              value: npc.description,
              expand: true,
            ),
          ),
        ],
      );
    }

    // The two-column row FILLS the dialog height, so the full image is shown at
    // the MAXIMUM dialog height — the frame's margins (dialog padding + insets)
    // keep it off the edges. Same in the game preview and play views.
    final imageAndText = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT — full image (1:1.43), same slot as the form's full_image, as tall
        // as the dialog allows (its width follows from the ratio).
        AspectRatio(
          aspectRatio: 1 / 1.43,
          child: hasFull
              ? Image.file(
                  npc.fullImage!,
                  key: ValueKey('play.npc.info.${npc.uuid}.image'),
                  fit: BoxFit.cover,
                )
              : ColoredBox(
                  key: ValueKey('play.npc.info.${npc.uuid}.image'),
                  color: scheme.surfaceContainerHighest,
                ),
        ),
        const SizedBox(width: 24),
        Expanded(child: rightColumn),
      ],
    );

    // A non-7th-Sea NPC with stats keeps the generic full-width statistics block
    // JOINING both columns below the image row (the image row is Expanded above
    // it). A Villain has none — its stats live in the right column — so the image
    // fills the whole dialog height.
    if (villain == null && npc.stats.isNotEmpty) {
      return Column(
        children: [
          Expanded(child: imageAndText),
          const SizedBox(height: 16),
          _statsBlock(ctx, npc),
        ],
      );
    }
    return imageAndText;
  }

  /// Height of the 7th Sea badge bar in the NPC info dialog. [NpcVillainBadges]
  /// sizes its band to `tileHeight × heightFraction`, so the fed height is scaled
  /// up by the inverse fraction to make a bar exactly this tall.
  static const double _villainBarHeight = 72;

  /// The 7th Sea stat badge bar shown below the description in the NPC info dialog
  /// — the SAME blocks as the NPC tile (a Villain's Strength / Influence / Rank,
  /// or a Brute's single centered Strength), reusing [NpcVillainBadges] so they
  /// look identical. Keyed under `play.npc.info.<uuid>` (the tile uses
  /// `play.npc.tile.<uuid>`).
  Widget _villainBadgesBar(BuildContext ctx, PlayNpc npc, NpcVillainStats v) {
    return NpcVillainBadges(
      keyPrefix: 'play.npc.info.${npc.uuid}',
      villain: v,
      tileHeight: _villainBarHeight / NpcVillainBadges.heightFraction,
    );
  }

  /// The Villain's selected Advantages, laid out in TWO columns below the badge
  /// bar. Each advantage shows its locale-resolved label (Polish under `pl`,
  /// English elsewhere — [seaAdvantageLabel]), keyed
  /// `play.npc.info.<uuid>.advantage.<key>`.
  Widget _villainAdvantages(
    BuildContext ctx,
    AppLocalizations l10n,
    PlayNpc npc,
    NpcVillainStats v,
  ) {
    final scheme = Theme.of(ctx).colorScheme;
    final advs = v.advantages;
    // First half fills the left column (the odd one out sits left), the rest the
    // right column, keeping the source (table) order down each column.
    final half = (advs.length + 1) ~/ 2;
    final columns = [advs.sublist(0, half), advs.sublist(half)];
    Widget column(List<String> keys) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              seaAdvantageLabel(l10n, k),
              key: ValueKey('play.npc.info.${npc.uuid}.advantage.$k'),
            ),
          ),
      ],
    );
    return Container(
      key: ValueKey('play.npc.info.${npc.uuid}.advantages'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.statSeaAdvantages,
            style: Theme.of(ctx).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column(columns[0])),
              const SizedBox(width: 16),
              Expanded(child: column(columns[1])),
            ],
          ),
        ],
      ),
    );
  }

  /// The full-width statistics block (spans both columns). One row per stat:
  /// its label on the left, value on the right.
  Widget _statsBlock(BuildContext ctx, PlayNpc npc) {
    final scheme = Theme.of(ctx).colorScheme;
    return Container(
      key: ValueKey('play.npc.info.${npc.uuid}.stats'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in npc.stats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(s.label)),
                  Text(s.value),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// A read-only mirror of a form field: the form's outlined box + floating
  /// label, but holding static [value] text instead of an input.
  Widget _roBlock(
    BuildContext ctx, {
    required String keyId,
    required String label,
    required String value,
    bool expand = false,
  }) {
    final text = Text(value, key: ValueKey(keyId));
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
      child: expand
          ? SizedBox.expand(child: SingleChildScrollView(child: text))
          : text,
    );
  }

  /// Shared height of the bottom-row buttons so the Key events and Next scenes
  /// buttons line up at exactly the same height (the embedded checkbox would
  /// otherwise make the key-event buttons taller).
  static const double _bottomButtonHeight = 44;

  /// A solid (opaque) button background using the app's tile colour pair so the
  /// key-event / next-scene buttons read clearly over the location image. The
  /// height is PINNED to [_bottomButtonHeight] so both bottom rows match.
  ButtonStyle _solidButtonStyle(ColorScheme scheme) => FilledButton.styleFrom(
    backgroundColor: scheme.secondaryContainer,
    foregroundColor: scheme.onSecondaryContainer,
    minimumSize: const Size(0, _bottomButtonHeight),
    maximumSize: const Size(double.infinity, _bottomButtonHeight),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _bottomRow({required String keyId, required List<Widget> children}) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      // The `.box` node is the full row band (buttons + padding); the rail's
      // legend indicator is sized to match exactly this height.
      key: ValueKey('$keyId.box'),
      color: Colors.black.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(8),
      child: Wrap(
        key: ValueKey(keyId),
        spacing: 8,
        runSpacing: 8,
        children: children,
      ),
    );
  }

  // --- Rail legend indicators -------------------------------------------

  /// The rail's collapsed / expanded widths (M3 defaults; the rail sets no
  /// override). The destinations centre their icon in a leading box [_railMinWidth]
  /// wide and grow to [_railMinExtendedWidth] when expanded; the legend indicators
  /// use the SAME widths and the same leading box so their icons land on the same
  /// vertical axis and left-align identically (icon centred when collapsed;
  /// left-aligned leading box with the label flowing right when expanded).
  static const double _railMinWidth = 80;
  static const double _railMinExtendedWidth = 256;

  /// The rail's bottom legend: one indicator per present bottom row, stacked in
  /// the same order (Key events above Next scenes) and bottom-pinned via the
  /// rail's `trailingAtBottom`. Each indicator's height tracks its row's live
  /// height, so the icon (and label, when the rail is expanded) sits at exactly
  /// the height of the row it labels.
  Widget _bottomIndicators(AppLocalizations l10n, ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_keyEventsRowPresent)
          _rowIndicator(
            keyId: 'play.keyevents.indicator',
            // Same icon as the Key events destination in the game rail
            // (nav.game.keyevents / Icons.library_add_check), so the rollers read
            // consistently.
            icon: Icons.library_add_check,
            label: l10n.sceneSectionKeyEvents,
            height: _keyEventsRowHeight,
            scheme: scheme,
          ),
        if (_nextScenesRowPresent)
          _rowIndicator(
            keyId: 'play.nextscenes.indicator',
            // Same icon as the Scenes destination in the game rail
            // (nav.game.scenes / Icons.videocam), since a next scene IS a scene.
            icon: Icons.videocam,
            label: l10n.sceneSectionNextScenes,
            height: _nextScenesRowHeight,
            scheme: scheme,
          ),
      ],
    );
  }

  /// One legend indicator: a [height]-tall box (the live height of the row it
  /// labels, fed by the row's [_MeasureSize] listener) holding the centred icon,
  /// plus the label to its right when the rail is expanded.
  Widget _rowIndicator({
    required String keyId,
    required IconData icon,
    required String label,
    required ValueNotifier<double> height,
    required ColorScheme scheme,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: height,
      builder: (context, h, _) {
        return SizedBox(
          key: ValueKey(keyId),
          height: h,
          // Same width as a destination (collapsed / expanded), so this box fills
          // the rail and its leading icon box is flush left — left-aligned exactly
          // like the destinations, not centred in the expanded rail.
          width: _extended ? _railMinExtendedWidth : _railMinWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Leading box matching the destinations' icon box, so the icon sits
              // on the same vertical axis (centred at _railMinWidth / 2).
              SizedBox(
                width: _railMinWidth,
                child: Center(
                  child: Icon(
                    icon,
                    key: ValueKey('$keyId.icon'),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_extended)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Reports its child's rendered size whenever it changes — including the first
/// layout, which `SizeChangedLayoutNotifier` skips. Used to mirror the bottom
/// rows' (wrapping) heights into the rail's legend indicators. The notifier
/// update is deferred to after the frame because mutating a [ValueNotifier]
/// during layout is illegal.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required Widget super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _previous;

  @override
  void performLayout() {
    super.performLayout();
    final next = child?.size ?? Size.zero;
    if (_previous == next) return;
    _previous = next;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(next));
  }
}

/// A read-only flutter_quill view of a note's body, shown in the Play view's
/// note content window. Renders the stored Delta with its formatting and embeds
/// the note's images (resolved by [imageResolver]); a legacy plain-text body
/// loads as a single run. Read-only, no cursor, no selection.
class _NoteContentView extends StatefulWidget {
  const _NoteContentView({
    super.key,
    required this.content,
    required this.imageResolver,
  });

  final String content;
  final File? Function(String reference)? imageResolver;

  @override
  State<_NoteContentView> createState() => _NoteContentViewState();
}

class _NoteContentViewState extends State<_NoteContentView> {
  late final QuillController _controller = QuillController(
    document: documentFromStored(widget.content),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolve = widget.imageResolver;
    return QuillEditor(
      controller: _controller,
      focusNode: _focus,
      scrollController: _scroll,
      config: QuillEditorConfig(
        expands: true,
        showCursor: false,
        enableInteractiveSelection: false,
        embedBuilders: [
          NoteImageEmbedBuilder((reference) => resolve?.call(reference)),
        ],
      ),
    );
  }
}

/// Opens the add-GM-note form (GM Notes). Returns the entered
/// plain-text content, or null on Cancel. A GM note is ALWAYS global (added to
/// EVERY scene), so the form has no scope choice.
Future<String?> showAddGmNoteDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _AddGmNoteDialog(),
  );
}

class _AddGmNoteDialog extends StatefulWidget {
  const _AddGmNoteDialog();

  @override
  State<_AddGmNoteDialog> createState() => _AddGmNoteDialogState();
}

class _AddGmNoteDialogState extends State<_AddGmNoteDialog> {
  final TextEditingController _content = TextEditingController();

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A GM note carries no title; Save needs only some content.
    final canSave = _content.text.trim().isNotEmpty;
    return AlertDialog(
      key: const ValueKey('play.gmnote.add'),
      title: Text(l10n.playGmNoteAdd),
      // The content field takes its MAXIMUM adventure-tile size (480 wide, height
      // = 480*1.43) on a tall window, but the box FLEXES SMALLER on a short
      // window (the dialog is NON-scrollable, its height capped at 480*1.43) so
      // it never overflows. A GM note is ALWAYS global, so there is no scope
      // checkbox — the content input is the whole form.
      content: ConstrainedBox(
        key: const ValueKey('play.gmnote.add.body'),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 480 * 1.43),
        child: SizedBox(
          width: 480,
          child: Column(
            children: [
              // PLAIN content input (no rich-text formatting), unlike Notes.
              // Expands to fill the box.
              Expanded(
                child: TextField(
                  key: const ValueKey('play.gmnote.add.content'),
                  controller: _content,
                  onChanged: (_) => setState(() {}),
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    labelText: l10n.notesContentLabel,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('play.gmnote.add.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.unsavedCancel),
        ),
        FilledButton(
          key: const ValueKey('play.gmnote.add.save'),
          onPressed: canSave
              ? () => Navigator.of(context).pop(_content.text)
              : null,
          child: Text(l10n.settingsSave),
        ),
      ],
    );
  }
}

/// The play-view Schemes / Intrygi MANAGER for a Villain. Two vertical
/// panels: LEFT the named **Intrygi** — each a tile (Tactic icon, "name (cost)", a
/// Settle / Fail round-button pair) over a "New scheme" add button; RIGHT the
/// purchased **Koszty** as plain text over a "Buy" button. Holds a WORKING COPY of
/// the villain's stats; every mutation calls [onChanged] so the host persists it.
class _SchemesManagerDialog extends StatefulWidget {
  const _SchemesManagerDialog({
    required this.keyPrefix,
    required this.initialStats,
    required this.onChanged,
  });

  final String keyPrefix;
  final Map<String, dynamic> initialStats;
  final void Function(Map<String, dynamic> stats) onChanged;

  @override
  State<_SchemesManagerDialog> createState() => _SchemesManagerDialogState();
}

class _SchemesManagerDialogState extends State<_SchemesManagerDialog> {
  late final Map<String, dynamic> _stats = _deepCopy(widget.initialStats);

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> m) {
    final out = Map<String, dynamic>.from(m);
    final schemes = m['schemes'];
    if (schemes is List) {
      out['schemes'] = [
        for (final s in schemes)
          if (s is Map) Map<String, dynamic>.from(s) else s,
      ];
    }
    return out;
  }

  List<dynamic> get _schemes {
    final raw = _stats['schemes'];
    return raw is List ? raw : (_stats['schemes'] = <dynamic>[]);
  }

  int get _stored {
    final v = _stats['influence'];
    return v is int ? v : 0;
  }

  void _apply(void Function() mutate) {
    setState(mutate);
    // Emit a FRESH copy so a shared ValueNotifier (the info window) sees a new
    // reference and re-renders; the host persists this copy.
    widget.onChanged(_deepCopy(_stats));
  }

  Future<void> _addScheme() async {
    final result = await showSchemeDialog(
      context,
      available: SevenSea.availableInfluence(_stats),
    );
    if (result == null) return;
    _apply(
      () => _schemes.add({
        'type': SevenSea.schemeTypeScheme,
        'name': result.name,
        'cost': result.cost,
        'resolved': false,
      }),
    );
  }

  /// Settle (check) or fail (X) the Intryga at [rawIndex]: on [settle] the STORED
  /// influence gains `cost × 2`; either way it is marked resolved and moved to the
  /// end of the list (greyed).
  void _resolve(int rawIndex, {required bool settle}) {
    final list = _schemes;
    if (rawIndex < 0 || rawIndex >= list.length) return;
    final s = Map<String, dynamic>.from(list[rawIndex] as Map);
    if (s['resolved'] == true) return;
    final cost = s['cost'] is int ? s['cost'] as int : 0;
    _apply(() {
      if (settle) _stats['influence'] = _stored + cost * 2;
      s['resolved'] = true;
      list.removeAt(rawIndex);
      list.add(s); // move to the end
    });
  }

  Future<void> _buyCost() async {
    final result = await showDialog<({String name, int cost})>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BuyCostDialog(available: _stored),
    );
    if (result == null) return;
    _apply(() {
      _stats['influence'] = _stored - result.cost;
      _schemes.add({
        'type': SevenSea.schemeTypeCost,
        'name': result.name,
        'cost': result.cost,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _intrigues(l10n, scheme)),
          const VerticalDivider(width: 24),
          Expanded(child: _costs(l10n, scheme)),
        ],
      ),
    );
  }

  Widget _intrigues(AppLocalizations l10n, ColorScheme scheme) {
    final raw = _schemes;
    final tiles = <Widget>[];
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      if (s is! Map) continue;
      if ((s['type'] ?? SevenSea.schemeTypeScheme) !=
          SevenSea.schemeTypeScheme) {
        continue;
      }
      tiles.add(_intrigueTile(l10n, scheme, i, Map<String, dynamic>.from(s)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.statSeaSchemes,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            key: ValueKey('${widget.keyPrefix}.intrigues'),
            children: tiles,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: ValueKey('${widget.keyPrefix}.new'),
          onPressed: _addScheme,
          icon: const Icon(Icons.add),
          label: Text(l10n.npcSeaSchemeNew),
        ),
      ],
    );
  }

  Widget _intrigueTile(
    AppLocalizations l10n,
    ColorScheme scheme,
    int rawIndex,
    Map<String, dynamic> s,
  ) {
    final name = s['name'] is String ? s['name'] as String : '';
    final cost = s['cost'] is int ? s['cost'] as int : 0;
    final resolved = s['resolved'] == true;
    Widget round(String suffix, IconData icon) => Padding(
      padding: const EdgeInsets.only(right: 4),
      child: SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.onSecondaryContainer,
          ),
          child: IconButton(
            key: ValueKey('${widget.keyPrefix}.intrigue.$rawIndex.$suffix'),
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: Icon(icon, color: scheme.secondaryContainer),
            // A resolved tile's buttons are inert.
            onPressed: resolved
                ? null
                : () => _resolve(rawIndex, settle: suffix == 'settle'),
          ),
        ),
      ),
    );
    final tile = Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(Symbols.tactic, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            // The scheme content with the invested influence in parentheses.
            Expanded(
              child: Text(
                '$name ($cost)',
                key: ValueKey('${widget.keyPrefix}.intrigue.$rawIndex.label'),
                style: TextStyle(color: scheme.onSecondaryContainer),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            round('settle', Icons.check_circle), // pays out cost × 2
            round('fail', Icons.cancel), // computes nothing
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // A resolved scheme is greyed.
      child: resolved ? Opacity(opacity: 0.5, child: tile) : tile,
    );
  }

  Widget _costs(AppLocalizations l10n, ColorScheme scheme) {
    final raw = _schemes;
    final rows = <Widget>[];
    for (var i = 0; i < raw.length; i++) {
      final s = raw[i];
      if (s is! Map) continue;
      if ((s['type'] ?? SevenSea.schemeTypeScheme) != SevenSea.schemeTypeCost) {
        continue;
      }
      final name = s['name'] is String ? s['name'] as String : '';
      final cost = s['cost'] is int ? s['cost'] as int : 0;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            '$name ($cost)',
            key: ValueKey('${widget.keyPrefix}.cost.$i'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.npcSeaCostsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            OutlinedButton.icon(
              key: ValueKey('${widget.keyPrefix}.buy'),
              onPressed: _buyCost,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(l10n.npcSeaSchemeBuy),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            key: ValueKey('${widget.keyPrefix}.costs'),
            children: rows,
          ),
        ),
      ],
    );
  }
}

/// The "Buy" (Kup) dialog for a play-view Villain Koszt: a description + a cost
/// (spent from influence). On Buy the influence is reduced by the cost.
/// Cost must fit the [available] influence.
class _BuyCostDialog extends StatefulWidget {
  const _BuyCostDialog({required this.available});

  final int available;

  @override
  State<_BuyCostDialog> createState() => _BuyCostDialogState();
}

class _BuyCostDialogState extends State<_BuyCostDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cost = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  String get _nameText => _name.text.trim();
  int? get _costValue => int.tryParse(_cost.text.trim());
  bool get _canBuy {
    final c = _costValue;
    return _nameText.isNotEmpty && c != null && c >= 0 && c <= widget.available;
  }

  void _buy() {
    if (!_canBuy) return;
    Navigator.of(context).pop((name: _nameText, cost: _costValue!));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final over = _costValue != null && _costValue! > widget.available;
    return AlertDialog(
      key: const ValueKey('play.npc.scheme.buy.dialog'),
      title: Text(l10n.npcSeaSchemeBuy),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('play.npc.scheme.buy.dialog.name'),
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.npcSeaCostDescription,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('play.npc.scheme.buy.dialog.cost'),
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(SevenSea.statDigits),
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.npcSeaSchemeCost,
                helperText:
                    '${l10n.npcSeaSchemeAvailable}: ${widget.available}',
                errorText: over
                    ? '${l10n.npcSeaSchemeAvailable}: ${widget.available}'
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('play.npc.scheme.buy.dialog.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.unsavedCancel),
        ),
        FilledButton(
          key: const ValueKey('play.npc.scheme.buy.dialog.buy'),
          onPressed: _canBuy ? _buy : null,
          child: Text(l10n.npcSeaSchemeBuy),
        ),
      ],
    );
  }
}

/// The ad-hoc scene NAME dialog. A tiny stateful dialog so
/// it OWNS its [TextEditingController] and disposes it in [dispose] — after the
/// route is fully gone — avoiding a use-after-dispose during the pop animation.
/// Pops the trimmed name on Confirm (enabled once non-blank), or null on Cancel.
class _AdHocNameDialog extends StatefulWidget {
  const _AdHocNameDialog();

  @override
  State<_AdHocNameDialog> createState() => _AdHocNameDialogState();
}

class _AdHocNameDialogState extends State<_AdHocNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = _controller.text.trim().isNotEmpty;
    return AlertDialog(
      key: const ValueKey('play.adhoc.dialog'),
      title: Text(l10n.playAdHocTitle),
      content: SizedBox(
        width: 320,
        child: TextField(
          key: const ValueKey('play.adhoc.name'),
          controller: _controller,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.playAdHocNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('play.adhoc.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.unsavedCancel),
        ),
        FilledButton(
          key: const ValueKey('play.adhoc.confirm'),
          onPressed: valid
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: Text(l10n.playAdHocConfirm),
        ),
      ],
    );
  }
}
