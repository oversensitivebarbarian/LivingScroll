import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/services/latex/latex_model.dart';
import 'package:living_scroll/services/latex/latex_npcs.dart';

/// Unit coverage for the Chapter-2 (NPCs) generator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> doc() => {
    'npcs': [
      {
        'npc_uuid': 'n1',
        'name': 'Guard & Co',
        'full_image': 'f1',
        'description': 'A gruff sentry.',
        'backstory': 'Once a soldier.',
      },
      {
        'npc_uuid': 'n2',
        'name': 'Innkeeper',
        'full_image': '',
        'description': 'Friendly host.',
        'backstory': '', // empty -> no Backstory subsubsection
      },
    ],
  };

  AssetSink present() => AssetSink((_) => true);

  test('chapter with one subsection per NPC, in order, each labelled', () {
    final out = latexNpcsChapter(doc(), LatexLabels.english, present());
    expect(out, contains(r'\chapter{NPCs}'));
    expect(out, contains(r'\label{npc:n1}'));
    expect(out, contains(r'\label{npc:n2}'));
    expect(
      out.indexOf(r'\subsection{Guard'),
      lessThan(out.indexOf(r'\subsection{Innkeeper}')),
    );
  });

  test('no NPCs -> empty output (no chapter at all — the Chapter 2 heading '
      'used to appear unconditionally even with zero NPCs)', () {
    expect(
      latexNpcsChapter({'npcs': <dynamic>[]}, LatexLabels.english, present()),
      isEmpty,
    );
  });

  test('an absent npcs[] key also produces empty output', () {
    expect(latexNpcsChapter({}, LatexLabels.english, present()), isEmpty);
  });

  test('name is escaped and the label matches the scenes-chapter link key', () {
    final out = latexNpcsChapter(doc(), LatexLabels.english, present());
    expect(out, contains(r'\subsection{Guard \& Co}'));
    // Same key a scene NPC link (\hyperref[npc:n1]) targets.
    expect(out, contains(r'\label{npc:n1}'));
  });

  test('full_image registers a portrait asset and emits the graphic', () {
    final assets = present();
    final out = latexNpcsChapter(doc(), LatexLabels.english, assets);
    expect(
      out,
      contains(r'\includegraphics[width=0.5\linewidth]{assets/npcfull_f1.png}'),
    );
    expect(
      assets.assets.map((a) => a.archivePath),
      contains('assets/npcfull_f1.png'),
    );
    expect(assets.assets.single.sourceRelPath, 'images/npcs/f1.png');
  });

  test('short description and backstory subsubsections', () {
    final out = latexNpcsChapter(doc(), LatexLabels.english, present());
    expect(out, contains(r'\subsubsection{Short description}'));
    expect(out, contains('A gruff sentry.'));
    expect(out, contains(r'\subsubsection{Backstory}'));
    expect(out, contains('Once a soldier.'));
  });

  test('an empty field drops its subsubsection', () {
    final out = latexNpcsChapter(doc(), LatexLabels.english, present());
    // Only n1 has a backstory; n2's empty backstory adds no subsubsection.
    expect(RegExp(r'\\subsubsection\{Backstory\}').allMatches(out).length, 1);
  });

  test('a missing portrait file drops the graphic and registers no asset', () {
    final assets = AssetSink((_) => false);
    final out = latexNpcsChapter(doc(), LatexLabels.english, assets);
    expect(assets.assets, isEmpty);
    expect(out, isNot(contains(r'\includegraphics')));
    // Text content is still present.
    expect(out, contains(r'\subsection{Guard \& Co}'));
  });

  group('7th Sea 2e NPC stats', () {
    // A 7thsea2e adventure with a single NPC carrying [stats].
    Map<String, dynamic> seaDoc(
      Map<String, dynamic> stats, {
      String language = 'en',
    }) => {
      'metadata': {'system': '7thsea2e', 'language': language},
      'npcs': [
        {'npc_uuid': 'v1', 'name': 'Boss', 'stats': stats},
      ],
    };

    String render(Map<String, dynamic> doc, {LatexLabels? labels}) =>
        latexNpcsChapter(
          doc,
          labels ?? LatexLabels.english,
          AssetSink((_) => true),
        );

    test('villain: Stats (strength/influence/rank) + Advantages list', () {
      final out = render(
        seaDoc({
          'kind': 'villain',
          'strength': 6,
          'influence': 3,
          'advantages': ['large', 'linguist'],
        }),
      );
      expect(out, contains(r'\subsubsection{Stats}'));
      expect(out, contains(r'\textbf{Strength:} 6'));
      expect(out, contains(r'\textbf{Influence:} 3'));
      // Villainy Rank = strength + available influence = 6 + 3.
      expect(out, contains(r'\textbf{Villainy Rank:} 9'));
      expect(out, contains(r'\subsubsection{Advantages}'));
      expect(out, contains(r'\item Large'));
      expect(out, contains(r'\item Linguist'));
    });

    test('villain rank drops by influence invested in a scheme', () {
      final out = render(
        seaDoc({
          'kind': 'villain',
          'strength': 6,
          'influence': 3,
          'schemes': [
            {'type': 'scheme', 'name': 'Poison', 'cost': 2},
          ],
        }),
      );
      // Rank = 6 + (3 - 2) = 7.
      expect(out, contains(r'\textbf{Villainy Rank:} 7'));
    });

    test('brute_squad: Stats with Strength only', () {
      final out = render(seaDoc({'kind': 'brute_squad', 'strength': 8}));
      expect(out, contains(r'\subsubsection{Stats}'));
      expect(out, contains(r'\textbf{Strength:} 8'));
      expect(out, isNot(contains('Influence')));
      expect(out, isNot(contains('Villainy Rank')));
      expect(out, isNot(contains(r'\subsubsection{Advantages}')));
    });

    test('monster (story character): no Stats subsubsection', () {
      final out = render(seaDoc({'kind': 'monster'}));
      expect(out, isNot(contains(r'\subsubsection{Stats}')));
    });

    test('villain with no advantages omits the Advantages subsubsection', () {
      final out = render(
        seaDoc({'kind': 'villain', 'strength': 5, 'influence': 2}),
      );
      expect(out, contains(r'\subsubsection{Stats}'));
      expect(out, isNot(contains(r'\subsubsection{Advantages}')));
    });

    test('advantages localize to the adventure language (Polish)', () {
      final out = render(
        seaDoc({
          'kind': 'villain',
          'strength': 6,
          'influence': 3,
          'advantages': ['large', 'linguist'],
        }, language: 'pl'),
        labels: LatexLabels.forLanguage('pl'),
      );
      // Polish headings + Polish advantage names.
      expect(out, contains(r'\subsubsection{Statystyki}'));
      expect(out, contains(r'\textbf{Siła:} 6'));
      expect(out, contains(r'\subsubsection{Atuty}'));
      expect(out, contains(r'\item Duży'));
      expect(out, contains(r'\item Poliglota'));
    });

    test('the NPC heading carries its localized type in parentheses', () {
      final out = render(seaDoc({'kind': 'villain', 'strength': 6}));
      expect(out, contains(r'\subsection{Boss (Villain)}'));
    });

    test(
      'the heading localizes the type to the adventure language (Polish)',
      () {
        final out = render(
          seaDoc({'kind': 'brute_squad'}, language: 'pl'),
          labels: LatexLabels.forLanguage('pl'),
        );
        expect(out, contains(r'\subsection{Boss ('));
        expect(out, isNot(contains(r'\subsection{Boss (Brute squad)}')));
      },
    );

    test(
      'an NPC with no stats/kind gets a plain heading (no parenthetical)',
      () {
        final out = latexNpcsChapter(
          seaDoc({}),
          LatexLabels.english,
          AssetSink((_) => true),
        );
        expect(out, contains(r'\subsection{Boss}'));
      },
    );

    test('a non-7thsea NPC gets no Stats subsubsection, and no type '
        'parenthetical either (basic has no "type" concept at all)', () {
      final out = latexNpcsChapter(
        {
          'metadata': {'system': 'basic', 'language': 'en'},
          'npcs': [
            {
              'npc_uuid': 'n1',
              'name': 'Guard',
              'stats': {'kind': 'villain', 'strength': 6},
            },
          ],
        },
        LatexLabels.english,
        AssetSink((_) => true),
      );
      expect(out, isNot(contains(r'\subsubsection{Stats}')));
      expect(out, contains(r'\subsection{Guard}'));
    });
  });
}
