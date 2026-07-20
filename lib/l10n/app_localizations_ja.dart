// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'ホーム';

  @override
  String get homeActiveSessions => '進行中のセッション';

  @override
  String get homeMore => 'もっと見る';

  @override
  String get homeCreateAdventure => '新しいアドベンチャーを作成';

  @override
  String get navCreate => '作成';

  @override
  String get navLibrary => 'ライブラリ';

  @override
  String get libraryAdventures => 'アドベンチャー';

  @override
  String get librarySaves => 'セーブ';

  @override
  String get libraryProjects => 'プロジェクト';

  @override
  String get libraryFinished => '完了';

  @override
  String get libraryImport => 'アドベンチャーをインポート';

  @override
  String get libraryImportDone => 'アドベンチャーをインポートしました';

  @override
  String get libraryImportDuplicate => 'すでにライブラリにあります';

  @override
  String get libraryImportInvalid => '有効なアドベンチャーファイルではありません';

  @override
  String get libraryCopyAsProject => 'プロジェクトとしてコピー';

  @override
  String get libraryAdventurePlay => 'プレイ';

  @override
  String get launchGroupNameLabel => 'グループ名';

  @override
  String get launchPlayersLabel => 'プレイヤー';

  @override
  String get launchAddPlayer => 'プレイヤーを追加';

  @override
  String get launchPlayerNameHint => 'プレイヤー名';

  @override
  String get launchRemovePlayer => 'プレイヤーを削除';

  @override
  String get launchLastSceneLabel => '再開地点';

  @override
  String get launchDryRun => '準備モード';

  @override
  String get launchImportProgress => '進行状況をインポート';

  @override
  String get launchImportProgressEmpty => '進行状況をインポートできる完了済みのゲームがありません。';

  @override
  String get launchReplace => '置き換える';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'グループ $group の冒険「$adventure」はすでに開始されています。置き換えるとすべての進行状況が失われます。';
  }

  @override
  String get libraryCopyDone => 'プロジェクトにコピーしました';

  @override
  String get libraryExportLatex => 'LaTeXにエクスポート';

  @override
  String get libraryExportLatexDone => 'LaTeX文書をエクスポートしました';

  @override
  String get libraryExportLatexError => 'アドベンチャーをLaTeXにエクスポートできませんでした';

  @override
  String get latexChapterScenes => 'シーン';

  @override
  String get latexChapterNpcs => 'NPC';

  @override
  String get latexChapterPaths => 'パス';

  @override
  String get latexNarration => 'ナレーション';

  @override
  String get latexNotes => 'メモ';

  @override
  String get latexImages => '画像';

  @override
  String get latexNextScenes => '次のシーン';

  @override
  String get latexShortDescription => '簡単な説明';

  @override
  String get latexBackstory => '背景';

  @override
  String get latexVisibleWhen => '表示条件';

  @override
  String get latexStats => 'ステータス';

  @override
  String get latexSceneTypeStart => '開始シーン';

  @override
  String get latexSceneTypeStandard => '標準シーン';

  @override
  String get latexSceneTypeRecurring => '再訪シーン';

  @override
  String get latexSceneTypeEnd => '終了シーン';

  @override
  String latexPageReferenceTemplate(Object page) {
    return '$pageページ';
  }

  @override
  String get librarySaveDeleteMessage => 'このセーブを削除すると、進行中のゲームのすべての進行状況が失われます。';

  @override
  String get libraryFinishedDeleteMessage => 'この終了したセッションの削除は取り消せません。復元できません。';

  @override
  String get navSettings => '設定';

  @override
  String get navMap => 'マップ';

  @override
  String get sceneMapAllPaths => 'すべてのパス';

  @override
  String get sceneMapEmpty => 'マップに表示するシーンがまだありません。';

  @override
  String get menuTooltip => 'メニュー';

  @override
  String get settingsLanguageLabel => '言語';

  @override
  String get settingsLanguageSystemDefault => 'システムのデフォルト';

  @override
  String get settingsDisplayModeLabel => '表示モード';

  @override
  String get settingsModeLight => 'ライト';

  @override
  String get settingsModeDark => 'ダーク';

  @override
  String get settingsModeAuto => '自動';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsMusicLabel => '音楽';

  @override
  String get settingsAutoplayLabel => '自動再生';

  @override
  String get settingsBuildSectionLabel => 'ビルド';

  @override
  String get settingsVersionLabel => 'バージョン';

  @override
  String get settingsBuildNumberLabel => 'ビルド番号';

  @override
  String get unsavedTitle => '保存されていない変更';

  @override
  String get unsavedMessage => '保存されていない変更があります。移動する前に保存しますか？';

  @override
  String get unsavedAbandon => '破棄';

  @override
  String get unsavedCancel => 'キャンセル';

  @override
  String get librarySaveEdit => '編集';

  @override
  String get createNewCoverLabel => 'カバーを追加';

  @override
  String get createNewTitleLabel => 'タイトル';

  @override
  String get createNewVersionLabel => 'バージョン';

  @override
  String get createNewSystemLabel => 'システム';

  @override
  String get createNewSystemHint => 'システムを選択';

  @override
  String get createNewAuthorLabel => '作者';

  @override
  String get createNewDescriptionLabel => '説明';

  @override
  String get createNewLanguageLabel => '言語';

  @override
  String get createNewLanguageUnset => '指定なし';

  @override
  String get createNewContentWarningsLabel => 'コンテンツ警告';

  @override
  String get createNewLicenseLabel => 'ライセンス';

  @override
  String get createNewImport => 'データをインポート';

  @override
  String get createNewCreate => '作成';

  @override
  String get createNewImportInvalid => '選択したファイルは有効なアドベンチャーではありません。';

  @override
  String get createNewImportSuccess => 'コンテンツをインポートしました';

  @override
  String get importSelectTitle => 'インポートするデータを選択';

  @override
  String get importConfirm => 'インポート';

  @override
  String get importDone => 'データをインポートしました';

  @override
  String get importNothing => 'インポートできる要素がありません。既に存在するか、システムと互換性がありません';

  @override
  String get gameGmNotes => 'GM メモ';

  @override
  String get coverCropTitle => 'カバーを切り抜く';

  @override
  String get coverCropConfirm => '切り抜く';

  @override
  String get coverCropCancel => 'キャンセル';

  @override
  String get gameScenes => 'シーン';

  @override
  String get gameNpcs => 'NPC';

  @override
  String get gameNotes => 'メモ';

  @override
  String get gameKeyEvents => '重要イベント';

  @override
  String get gameImages => '画像';

  @override
  String get gameSoundtracks => 'サウンドトラック';

  @override
  String get gamePaths => 'パス';

  @override
  String get gamePublish => 'エクスポート';

  @override
  String get gameExportPart => '要素をエクスポート';

  @override
  String get publishValidTitle => 'エクスポート完了';

  @override
  String get publishValidMessage => 'アドベンチャーを正常にエクスポートしました。';

  @override
  String get publishElementsReady => '要素ファイルをダウンロードできます。';

  @override
  String get publishInvalidTitle => 'まだ公開できません';

  @override
  String get publishDownloadLs => '.ls をダウンロード';

  @override
  String get publishDownloadLse => '.lse をダウンロード';

  @override
  String get libraryDuplicateTitle => 'すでにライブラリにあります';

  @override
  String get libraryDuplicateMessage =>
      '同じタイトル・バージョン・システム・作者・言語のアドベンチャーが既にライブラリにあります。上書きしますか？';

  @override
  String get libraryOverwrite => '上書き';

  @override
  String publishIssueAdventureField(String field) {
    return 'アドベンチャー設定「$field」は必須です。';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'NPC「$name」には名前と2つの肖像画像が必要です。';
  }

  @override
  String get publishIssueNoteName => 'ノートに名前または内容がありません。';

  @override
  String get publishIssueNoStartScene => '開始シーンが少なくとも1つ必要です。';

  @override
  String get publishIssueNoEndScene => '終了シーンが少なくとも1つ必要です。';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return '終了シーン「$name」に次のシーンを設定することはできません。';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'シーン「$name」には次のシーンが必要です。';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'シーン「$name」には常に利用可能な次のシーンが少なくとも1つ必要です。';
  }

  @override
  String get publishIssueNoPathToEnd =>
      '常に利用可能なシーンだけで、開始シーンから終了シーンに至る経路がありません。';

  @override
  String publishIssueBlindLoop(String name) {
    return 'シーン「$name」は行き止まりのループです。別のシーンが、すでに訪問済みのこのシーンへ戻ろうとしています。再訪を許可するには繰り返し（recurring）シーンに設定してください。';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'パス「$name」には開始シーンが必要です。';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'パス「$name」には終了シーンが必要です。';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'パス「$name」自身のシーンの中に、常に利用可能なシーンだけで開始シーンから終了シーンに至る経路がありません。';
  }

  @override
  String get gameAdventureSettings => 'アドベンチャー設定';

  @override
  String get pathEditNameLabel => 'パス名';

  @override
  String get pathNameRequired => 'このパスはシーンで使用されているため、名前が必要です';

  @override
  String get visibilityRulesTitle => '表示ルール';

  @override
  String get visibilityRulesAnd => 'すべて満たす';

  @override
  String get visibilityRulesOr => 'いずれか満たす';

  @override
  String get visibilityRulesAlwaysVisible => '常に表示';

  @override
  String get visibilityRulesNoEvents => '先に重要イベントを追加してください';

  @override
  String get notesAddLabel => 'メモを追加';

  @override
  String get notesNameLabel => 'メモ名';

  @override
  String get notesContentLabel => '内容';

  @override
  String get notesInsertImage => '画像を挿入';

  @override
  String get notesImagePickTitle => '画像を挿入';

  @override
  String get notesImagePickEmpty => '利用可能な画像がありません';

  @override
  String get notesImagePickGroupImages => '画像';

  @override
  String get notesImagePickGroupNpcs => 'NPC';

  @override
  String get notesDeleteMessage => 'このメモを削除しますか？';

  @override
  String get notesDelete => '削除';

  @override
  String get notesNameNotUnique => 'メモのタイトルは一意でなければなりません';

  @override
  String get notesSearchHint => 'メモを検索';

  @override
  String get notesSearchClear => '検索をクリア';

  @override
  String get keyEventsNameLabel => 'イベント名';

  @override
  String get keyEventsDeleteMessage => 'このイベントを削除しますか？このイベントへのすべての参照が削除されます。';

  @override
  String get keyEventsDelete => '削除';

  @override
  String get keyEventsNameNotUnique => 'イベント名は一意でなければなりません';

  @override
  String get keyEventsSearchHint => 'イベントを検索';

  @override
  String get keyEventsSearchClear => '検索をクリア';

  @override
  String get soundtracksAddLabel => 'サウンドトラックを追加';

  @override
  String get soundtracksDeleteMessage => 'このサウンドトラックを削除しますか？';

  @override
  String get soundtracksDelete => '削除';

  @override
  String get soundtracksNameNotUnique => 'この名前のサウンドトラックは既に存在します';

  @override
  String get soundtracksSearchHint => 'サウンドトラックを検索';

  @override
  String get soundtracksSearchClear => '検索をクリア';

  @override
  String get imagesPickLabel => '画像を選択';

  @override
  String get imagesAddTooltip => '画像を追加';

  @override
  String get imagesDeleteMessage => 'この画像を削除しますか？';

  @override
  String get imagesDelete => '削除';

  @override
  String get imagesAddButton => '追加';

  @override
  String get npcsNameLabel => '名前';

  @override
  String get npcsDescriptionLabel => '説明';

  @override
  String get npcsBackstoryLabel => '背景';

  @override
  String get npcsFullImageLabel => 'フル画像';

  @override
  String get npcsIconLabel => 'アイコン';

  @override
  String get npcsCropFull => 'フル画像を切り抜く';

  @override
  String get npcsCropIcon => 'アイコンを切り抜く';

  @override
  String get npcsClone => '複製';

  @override
  String get npcsDelete => '削除';

  @override
  String get npcsDeleteMessage => 'このNPCを削除しますか？';

  @override
  String get npcsNameNotUnique => 'この名前のNPCはすでに存在します';

  @override
  String get npcsSearchHint => 'NPCを検索';

  @override
  String get npcsSearchClear => '検索をクリア';

  @override
  String get adventureClone => '複製';

  @override
  String get adventureDelete => '削除';

  @override
  String get adventureDeleteMessage => 'このアドベンチャーを削除しますか？';

  @override
  String get scenesAddLabel => 'シーンを追加';

  @override
  String get scenesSearchHint => 'シーンを検索';

  @override
  String get scenesSearchClear => '検索をクリア';

  @override
  String get scenesDeleteMessage => 'このシーンを削除しますか？';

  @override
  String get scenesDelete => '削除';

  @override
  String get scenesNameNotUnique => 'この名前のシーンは既に存在します';

  @override
  String get sceneNameLabel => '名前';

  @override
  String get sceneNarrationLabel => 'ナレーション';

  @override
  String get sceneSectionNpc => 'NPC';

  @override
  String get sceneSectionNotes => 'メモ';

  @override
  String get playGmNotes => 'GMノート';

  @override
  String get playGmNoteAdd => 'GMノートを追加';

  @override
  String get playGmNoteGlobal => 'グローバルノート';

  @override
  String get playGmNoteDeleteMessage =>
      'このGMノートを削除すると、すべてのシーンから取り除かれます。この操作は元に戻せません。';

  @override
  String get playNpcDeactivate => 'NPCを無効化';

  @override
  String get playVillains => '悪役（全体）';

  @override
  String get sceneSectionKeyEvents => '重要イベント';

  @override
  String get sceneSectionImages => '画像';

  @override
  String get sceneSectionAudio => 'サウンドトラック';

  @override
  String get sceneSectionPaths => 'パス';

  @override
  String get sceneAddNotes => 'メモを追加';

  @override
  String get sceneChooseSoundtrack => 'サウンドトラックを選択';

  @override
  String get scenePickNpcTitle => 'NPCを選択';

  @override
  String get scenePickNotesTitle => 'メモを選択';

  @override
  String get scenePickKeyEventsTitle => '重要イベントを選択';

  @override
  String get scenePickImagesTitle => '画像を選択';

  @override
  String get scenePickSoundtrackTitle => 'サウンドトラックを選択';

  @override
  String get sceneSectionType => 'シーンタイプ';

  @override
  String get sceneTypeStart => '開始シーン';

  @override
  String get sceneTypeStandard => '標準シーン';

  @override
  String get sceneTypeRecurring => '再登場シーン';

  @override
  String get sceneTypeEnd => '終了シーン';

  @override
  String get sceneSectionNextScenes => '次のシーン';

  @override
  String get scenePickNextScenesTitle => '次のシーンを選択';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => '閉じる';

  @override
  String get playPauseSession => 'セッションを一時停止';

  @override
  String get playAdHocScene => 'アドホックシーン';

  @override
  String get playPreviousScene => '前のシーン';

  @override
  String get playNextScene => '次のシーン';

  @override
  String get playFinishAdventure => '冒険を終える';

  @override
  String get playSplitParty => 'パーティを分割';

  @override
  String get playSplitTitle => 'パーティを分割';

  @override
  String get playSplitAssignHint => '新しいグループに入るプレイヤーを選択：';

  @override
  String get playSplitConfirm => '分割';

  @override
  String get playPipSwitchFocus => 'フォーカスを切り替え';

  @override
  String get playAdHocTitle => 'アドホックシーン';

  @override
  String get playAdHocNameLabel => 'シーン名';

  @override
  String get playAdHocConfirm => '開始';

  @override
  String get playMergeHint => '→ 合流';

  @override
  String get playJumpToScene => 'シーンへ移動';

  @override
  String get playJumpTitle => 'シーンへ移動';

  @override
  String get playEndTrack => 'このグループを終了';

  @override
  String get playPauseConfirm => '進行状況を保存してメインに戻りますか？';

  @override
  String get sceneSectionBackground => '背景画像';

  @override
  String get scenePickBackgroundTitle => '背景画像を選択';

  @override
  String get npcSeaPageKind => 'NPC type';

  @override
  String get npcSeaPageDetails => 'Details';

  @override
  String get npcSeaNext => 'Next';

  @override
  String get npcSeaBack => 'Back';

  @override
  String get npcSeaKindLabel => 'NPC type';

  @override
  String get npcSeaKindVillain => 'Villain';

  @override
  String get npcSeaKindBrute => 'Brutes, Monsters, Allies';

  @override
  String get npcSeaKindMonster => 'Story character';

  @override
  String get npcSeaComputed => 'computed';

  @override
  String get statSeaStrength => 'Strength';

  @override
  String get statSeaInfluence => 'Influence';

  @override
  String get statSeaVillainyRank => 'Villainy Rank';

  @override
  String get statSeaAdvantages => 'Advantages';

  @override
  String get statSeaSchemes => 'Schemes';

  @override
  String get npcSeaSchemeNew => 'New scheme';

  @override
  String get npcSeaSchemeName => 'Scheme name';

  @override
  String get npcSeaSchemeCost => 'Cost';

  @override
  String get npcSeaSchemeAdd => 'Add';

  @override
  String get npcSeaSchemeEditTitle => 'Edit scheme';

  @override
  String get npcSeaSchemeAvailable => 'Available influence';

  @override
  String get npcSeaCostsTitle => 'Costs';

  @override
  String get npcSeaSchemeBuy => 'Buy';

  @override
  String get npcSeaCostDescription => 'Description';

  @override
  String get npcSeaTileStrength => 'Strength';

  @override
  String get npcSeaTileInfluence => 'Influence';

  @override
  String get npcSeaTileRank => 'Rank';
}
