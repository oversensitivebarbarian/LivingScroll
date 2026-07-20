import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/scenes/party_controller.dart';

void main() {
  // Deterministic ids: t1, t2, t3, … so assertions can name tracks directly.
  String Function() counter() {
    var n = 0;
    return () => 't${++n}';
  }

  PartyController single({
    String scene = 's1',
    Set<String> players = const {'Alice', 'Bob'},
    int? maxTracks,
    String Function()? newId,
  }) =>
      PartyController.single(
        sceneUuid: scene,
        players: players,
        maxTracks: maxTracks ?? players.length,
        newId: newId ?? counter(),
      );

  group('start single', () {
    test('one focused track holds all players on the start scene', () {
      final c = single();
      expect(c.tracks.length, 1);
      expect(c.isSplit, isFalse);
      expect(c.allTracksAtEnd((u) => u == 'end'), isFalse); // on s1, not an end
      final t = c.focused;
      expect(t.id, 't1');
      expect(t.focused, isTrue);
      expect(t.currentSceneUuid, 's1');
      expect(t.pcNames, {'Alice', 'Bob'});
      expect(c.focusedIndex, 0);
    });

    test('the players set is copied, not aliased', () {
      final players = {'Alice', 'Bob'};
      final c = single(players: players);
      players.add('Cara');
      expect(c.focused.pcNames, {'Alice', 'Bob'});
    });
  });

  group('split', () {
    test('moves the chosen PC to a new track on the same scene, focus stays',
        () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'});
      expect(c.tracks.length, 2);
      expect(c.isSplit, isTrue);
      // Source keeps Alice and stays focused.
      final source = c.tracks[0];
      expect(source.pcNames, {'Alice'});
      expect(source.focused, isTrue);
      // New track has Bob, same scene, not focused.
      expect(other.pcNames, {'Bob'});
      expect(other.currentSceneUuid, 's1');
      expect(other.focused, isFalse);
      expect(c.focused.id, source.id);
    });

    test('canSplit is false once tracks == maxTracks', () {
      final c = single(); // 2 players, maxTracks 2
      c.split(pcToNewTrack: {'Bob'});
      expect(c.canSplit, isFalse);
      expect(() => c.split(pcToNewTrack: {'Alice'}), throwsStateError);
    });

    test('canSplit is false when the focused track has fewer than 2 PC', () {
      // 3 players / maxTracks 3 leaves room, but the focused track is solo.
      final c = single(players: {'Alice'}, maxTracks: 3);
      expect(c.canSplit, isFalse);
      expect(() => c.split(pcToNewTrack: {'Alice'}), throwsStateError);
    });

    test('rejects an empty, full or foreign PC selection', () {
      final c = single(players: {'Alice', 'Bob', 'Cara'}, maxTracks: 3);
      expect(() => c.split(pcToNewTrack: {}), throwsArgumentError);
      // Cannot move ALL PC (at least one must stay).
      expect(() => c.split(pcToNewTrack: {'Alice', 'Bob', 'Cara'}),
          throwsArgumentError);
      // A PC the track does not hold.
      expect(() => c.split(pcToNewTrack: {'Zed'}), throwsArgumentError);
    });

    test('double split yields three tracks with 3 players', () {
      final c = single(players: {'Alice', 'Bob', 'Cara'}, maxTracks: 3);
      c.split(pcToNewTrack: {'Bob'}); // focus stays on source (Alice, Cara)
      expect(c.canSplit, isTrue); // 2 tracks < 3, focused has 2 PC
      c.split(pcToNewTrack: {'Cara'});
      expect(c.tracks.length, 3);
      expect(c.canSplit, isFalse); // now at the cap
      expect(c.tracks.map((t) => t.pcNames).toList(),
          [{'Alice'}, {'Bob'}, {'Cara'}]);
    });
  });

  group('max parallel tracks (hard cap of 4)', () {
    test('the cap constant is 4', () {
      expect(PartyController.maxParallelTracks, 4);
    });

    test('a roster larger than 4 is clamped to 4 tracks', () {
      // Six players, but the party can never exceed 4 parallel tracks.
      final c = single(
        players: {'A', 'B', 'C', 'D', 'E', 'F'},
        maxTracks: 6, // roster size, will be clamped
      );
      expect(c.maxTracks, 4);

      c.split(pcToNewTrack: {'B'}); // 2 tracks
      expect(c.canSplit, isTrue);
      c.split(pcToNewTrack: {'C'}); // 3 tracks
      expect(c.canSplit, isTrue);
      c.split(pcToNewTrack: {'D'}); // 4 tracks -> at the hard cap
      expect(c.tracks.length, 4);
      // Focused source still holds {A, E, F} (>= 2 PC) yet split is refused
      // solely because the 4-track cap is reached.
      expect(c.focused.pcNames.length, greaterThanOrEqualTo(2));
      expect(c.canSplit, isFalse);
      expect(() => c.split(pcToNewTrack: {'E'}), throwsStateError);
    });

    test('a roster of exactly 4 caps at 4', () {
      final c = single(players: {'A', 'B', 'C', 'D'}, maxTracks: 4);
      expect(c.maxTracks, 4);
    });

    test('a roster smaller than 4 caps at the roster size', () {
      // The cap never raises a small roster: 3 players -> at most 3 tracks.
      final c = single(players: {'A', 'B', 'C'}, maxTracks: 3);
      expect(c.maxTracks, 3);
      c.split(pcToNewTrack: {'B'});
      c.split(pcToNewTrack: {'C'});
      expect(c.tracks.length, 3);
      expect(c.canSplit, isFalse); // capped by the roster, below 4
    });

    test('fromJson also clamps maxTracks to 4', () {
      final json = {
        'tracks': [
          {'id': 'a', 'current_scene_uuid': 's1', 'pc_names': ['A', 'B'], 'focused': true},
        ],
      };
      final c = PartyController.fromJson(json, maxTracks: 10);
      expect(c.maxTracks, 4);
    });
  });

  group('switchFocus', () {
    test('moves focus to the named track and clears the rest', () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'});
      c.switchFocus(other.id);
      expect(c.focused.id, other.id);
      expect(c.tracks.where((t) => t.focused).length, 1);
    });

    test('is a no-op for an unknown id', () {
      final c = single();
      final before = c.focused.id;
      c.switchFocus('nope');
      expect(c.focused.id, before);
      expect(c.tracks.where((t) => t.focused).length, 1);
    });
  });

  group('mergeTargetFor', () {
    test('finds another active track on the same author scene', () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'}); // both on s1
      expect(c.mergeTargetFor(c.tracks[0])?.id, other.id);
    });

    test('returns null when tracks stand on different scenes', () {
      final c = single();
      c.split(pcToNewTrack: {'Bob'});
      c.moveFocusedTo('s2'); // source (focused) moves away
      expect(c.mergeTargetFor(c.focused), isNull);
    });

    test('merges on a shared ad-hoc uuid (rendezvous) …', () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'});
      // Both tracks land on the SAME ad-hoc scene (e.g. one jumped onto it).
      c.tracks[0].currentSceneUuid = 'adhoc-x';
      other.currentSceneUuid = 'adhoc-x';
      expect(c.mergeTargetFor(c.tracks[0])?.id, other.id);
    });

    test('… but NOT on two DIFFERENT ad-hoc uuids', () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'});
      c.tracks[0].currentSceneUuid = 'adhoc-x';
      other.currentSceneUuid = 'adhoc-y';
      expect(c.mergeTargetFor(c.tracks[0]), isNull);
    });
  });

  group('merge', () {
    test('unions PC into the lower-index survivor and focuses it', () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'}); // t1=[Alice], t2=[Bob]
      c.switchFocus(other.id); // focus the one that will NOT survive
      final survivor = c.tracks[0];
      c.merge(survivor, other);
      expect(c.tracks.length, 1);
      expect(c.tracks.single.id, survivor.id);
      expect(c.tracks.single.pcNames, {'Alice', 'Bob'});
      expect(c.focused.id, survivor.id); // focus moved to survivor
    });

    test('survivor is the lower index regardless of argument order', () {
      final c = single();
      final other = c.split(pcToNewTrack: {'Bob'});
      c.merge(other, c.tracks[0]); // pass them reversed
      expect(c.tracks.single.pcNames, {'Alice', 'Bob'});
      expect(c.tracks.single.currentSceneUuid, 's1');
    });
  });

  group('allTracksAtEnd', () {
    bool isEnd(String uuid) => uuid == 'sEnd1' || uuid == 'sEnd2';

    test('single track: true only when it stands on an end scene', () {
      final c = single(players: {'Alice', 'Bob'}, maxTracks: 2);
      c.moveFocusedTo('s1');
      expect(c.allTracksAtEnd(isEnd), isFalse);
      c.moveFocusedTo('sEnd1');
      expect(c.allTracksAtEnd(isEnd), isTrue);
    });

    test('split: true only when EVERY track is on an end scene (not necessarily '
        'the same)', () {
      final c = single(players: {'Alice', 'Bob'}, maxTracks: 2);
      c.moveFocusedTo('sEnd1');
      final t2 = c.split(pcToNewTrack: {'Bob'}); // t2 starts on sEnd1 too
      // Both tracks share sEnd1 -> all at end.
      expect(c.allTracksAtEnd(isEnd), isTrue);
      // Move the second track off an end scene -> no longer all at end.
      t2.currentSceneUuid = 's2';
      expect(c.allTracksAtEnd(isEnd), isFalse);
      // A DIFFERENT end scene still counts.
      t2.currentSceneUuid = 'sEnd2';
      expect(c.allTracksAtEnd(isEnd), isTrue);
    });
  });

  group('toJson / fromJson round-trip', () {
    test('preserves tracks, PC, scenes and the single focus', () {
      final c = single(players: {'Alice', 'Bob', 'Cara'}, maxTracks: 3);
      final other = c.split(pcToNewTrack: {'Bob'});
      other.currentSceneUuid = 'adhoc-z';
      c.switchFocus(other.id);

      final restored =
          PartyController.fromJson(c.toJson(), maxTracks: 3, newId: counter());
      expect(restored.tracks.length, 2);
      expect(restored.maxTracks, 3);
      expect(restored.tracks[0].pcNames, {'Alice', 'Cara'});
      expect(restored.tracks[1].pcNames, {'Bob'});
      expect(restored.tracks[1].currentSceneUuid, 'adhoc-z');
      expect(restored.tracks.where((t) => t.focused).length, 1);
      expect(restored.focused.currentSceneUuid, 'adhoc-z');
    });

    test('repairs a snapshot with no focused track (first becomes focused)', () {
      final json = {
        'tracks': [
          {'id': 'a', 'current_scene_uuid': 's1', 'pc_names': ['Alice'], 'focused': false},
          {'id': 'b', 'current_scene_uuid': 's2', 'pc_names': ['Bob'], 'focused': false},
        ],
      };
      final c = PartyController.fromJson(json, maxTracks: 2);
      expect(c.tracks.where((t) => t.focused).length, 1);
      expect(c.focused.id, 'a');
    });

    test('repairs a snapshot with multiple focused tracks', () {
      final json = {
        'tracks': [
          {'id': 'a', 'current_scene_uuid': 's1', 'pc_names': ['Alice'], 'focused': true},
          {'id': 'b', 'current_scene_uuid': 's2', 'pc_names': ['Bob'], 'focused': true},
        ],
      };
      final c = PartyController.fromJson(json, maxTracks: 2);
      expect(c.tracks.where((t) => t.focused).length, 1);
      expect(c.focused.id, 'a');
    });

    test('an empty snapshot yields a single focused track (defensive)', () {
      final c = PartyController.fromJson(const {'tracks': []},
          maxTracks: 1, newId: counter());
      expect(c.tracks.length, 1);
      expect(c.focused.id, 't1');
      expect(c.allTracksAtEnd((u) => u == 'end'), isFalse); // on '' , not an end
    });
  });
}
