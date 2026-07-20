// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'Home';

  @override
  String get homeActiveSessions => 'Active sessions';

  @override
  String get homeMore => 'More';

  @override
  String get homeCreateAdventure => 'Create new adventure';

  @override
  String get navCreate => 'Create';

  @override
  String get navLibrary => 'Library';

  @override
  String get libraryAdventures => 'Adventures';

  @override
  String get librarySaves => 'Saves';

  @override
  String get libraryProjects => 'Projects';

  @override
  String get libraryFinished => 'Finished';

  @override
  String get libraryImport => 'Import adventure';

  @override
  String get libraryImportDone => 'Adventure imported';

  @override
  String get libraryImportDuplicate => 'Already in library';

  @override
  String get libraryImportInvalid => 'Not a valid adventure file';

  @override
  String get libraryCopyAsProject => 'Copy as project';

  @override
  String get libraryAdventurePlay => 'Play';

  @override
  String get launchGroupNameLabel => 'Group name';

  @override
  String get launchPlayersLabel => 'Players';

  @override
  String get launchAddPlayer => 'Add player';

  @override
  String get launchPlayerNameHint => 'Player name';

  @override
  String get launchRemovePlayer => 'Remove player';

  @override
  String get launchLastSceneLabel => 'Continues at';

  @override
  String get launchDryRun => 'Prep mode';

  @override
  String get launchImportProgress => 'Import progress';

  @override
  String get launchImportProgressEmpty =>
      'No finished games to import progress from.';

  @override
  String get launchReplace => 'Replace';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'Adventure $adventure for group $group is already started. Replacing it will lose all game progress.';
  }

  @override
  String get libraryCopyDone => 'Copied to projects';

  @override
  String get libraryExportLatex => 'Export to LaTeX';

  @override
  String get libraryExportLatexDone => 'LaTeX document exported';

  @override
  String get libraryExportLatexError =>
      'Could not export the adventure to LaTeX';

  @override
  String get latexChapterScenes => 'Scenes';

  @override
  String get latexChapterNpcs => 'NPCs';

  @override
  String get latexChapterPaths => 'Paths';

  @override
  String get latexNarration => 'Narration';

  @override
  String get latexNotes => 'Notes';

  @override
  String get latexImages => 'Images';

  @override
  String get latexNextScenes => 'Next scenes';

  @override
  String get latexShortDescription => 'Short description';

  @override
  String get latexBackstory => 'Backstory';

  @override
  String get latexVisibleWhen => 'Visible when';

  @override
  String get latexStats => 'Stats';

  @override
  String get latexSceneTypeStart => 'opening scene';

  @override
  String get latexSceneTypeStandard => 'standard scene';

  @override
  String get latexSceneTypeRecurring => 'recurring scene';

  @override
  String get latexSceneTypeEnd => 'ending scene';

  @override
  String latexPageReferenceTemplate(Object page) {
    return 'page $page';
  }

  @override
  String get librarySaveDeleteMessage =>
      'Deleting this save will lose all progress of the in-progress game.';

  @override
  String get libraryFinishedDeleteMessage =>
      'Deleting this finished session is permanent — it cannot be recovered.';

  @override
  String get navSettings => 'Settings';

  @override
  String get navMap => 'Map';

  @override
  String get sceneMapAllPaths => 'All paths';

  @override
  String get sceneMapEmpty => 'No scenes to map yet.';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSystemDefault => 'System default';

  @override
  String get settingsDisplayModeLabel => 'Display Mode';

  @override
  String get settingsModeLight => 'Light';

  @override
  String get settingsModeDark => 'Dark';

  @override
  String get settingsModeAuto => 'Auto';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsMusicLabel => 'Music';

  @override
  String get settingsAutoplayLabel => 'Autoplay';

  @override
  String get settingsBuildSectionLabel => 'Build';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsBuildNumberLabel => 'Build number';

  @override
  String get unsavedTitle => 'Unsaved changes';

  @override
  String get unsavedMessage =>
      'You have unsaved changes. Save them before leaving?';

  @override
  String get unsavedAbandon => 'Discard';

  @override
  String get unsavedCancel => 'Cancel';

  @override
  String get librarySaveEdit => 'Edit';

  @override
  String get createNewCoverLabel => 'Add cover';

  @override
  String get createNewTitleLabel => 'Title';

  @override
  String get createNewVersionLabel => 'Version';

  @override
  String get createNewSystemLabel => 'System';

  @override
  String get createNewSystemHint => 'Select a system';

  @override
  String get createNewAuthorLabel => 'Author';

  @override
  String get createNewDescriptionLabel => 'Description';

  @override
  String get createNewLanguageLabel => 'Language';

  @override
  String get createNewLanguageUnset => 'Not specified';

  @override
  String get createNewContentWarningsLabel => 'Content warnings';

  @override
  String get createNewLicenseLabel => 'License';

  @override
  String get createNewImport => 'Import data';

  @override
  String get createNewCreate => 'Create';

  @override
  String get createNewImportInvalid =>
      'The selected file is not a valid adventure.';

  @override
  String get createNewImportSuccess => 'Content imported';

  @override
  String get importSelectTitle => 'Select data to import';

  @override
  String get importConfirm => 'Import';

  @override
  String get importDone => 'Data imported';

  @override
  String get importNothing =>
      'No elements to import. Either already existing or not compatible with system';

  @override
  String get gameGmNotes => 'GM notes';

  @override
  String get coverCropTitle => 'Crop cover';

  @override
  String get coverCropConfirm => 'Crop';

  @override
  String get coverCropCancel => 'Cancel';

  @override
  String get gameScenes => 'Scenes';

  @override
  String get gameNpcs => 'NPCs';

  @override
  String get gameNotes => 'Notes';

  @override
  String get gameKeyEvents => 'Key events';

  @override
  String get gameImages => 'Images';

  @override
  String get gameSoundtracks => 'Soundtracks';

  @override
  String get gamePaths => 'Paths';

  @override
  String get gamePublish => 'Export';

  @override
  String get gameExportPart => 'Export elements';

  @override
  String get publishValidTitle => 'Exported';

  @override
  String get publishValidMessage => 'The adventure was successfully exported.';

  @override
  String get publishElementsReady => 'The elements file is ready to download.';

  @override
  String get publishInvalidTitle => 'Cannot publish yet';

  @override
  String get publishDownloadLs => 'Download .ls';

  @override
  String get publishDownloadLse => 'Download .lse';

  @override
  String get libraryDuplicateTitle => 'Already in library';

  @override
  String get libraryDuplicateMessage =>
      'An adventure with the same title, version, system, author and language is already in your library. Overwrite it?';

  @override
  String get libraryOverwrite => 'Overwrite';

  @override
  String publishIssueAdventureField(String field) {
    return 'Adventure setting \"$field\" is required.';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'NPC \"$name\" needs a name and both portrait images.';
  }

  @override
  String get publishIssueNoteName => 'A note is missing its name or content.';

  @override
  String get publishIssueNoStartScene =>
      'There must be at least one start scene.';

  @override
  String get publishIssueNoEndScene => 'There must be at least one end scene.';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return 'End scene \"$name\" must not have a next scene.';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'Scene \"$name\" must have a next scene.';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'Scene \"$name\" must have at least one next scene that is always available.';
  }

  @override
  String get publishIssueNoPathToEnd =>
      'No path of always-available scenes leads from a start scene to an end scene.';

  @override
  String publishIssueBlindLoop(String name) {
    return 'Scene \"$name\" is a dead loop: another scene leads back to it after it has already been visited. Make it a recurring scene to allow returning.';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'Path \"$name\" must have a start scene.';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'Path \"$name\" must have an end scene.';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'Within path \"$name\"\'s own scenes, no route of always-available scenes leads from its start scene to its end scene.';
  }

  @override
  String get gameAdventureSettings => 'Adventure settings';

  @override
  String get pathEditNameLabel => 'Path name';

  @override
  String get pathNameRequired =>
      'This path is used by a scene, so it needs a name';

  @override
  String get visibilityRulesTitle => 'Visibility rules';

  @override
  String get visibilityRulesAnd => 'All satisfied';

  @override
  String get visibilityRulesOr => 'Any satisfied';

  @override
  String get visibilityRulesAlwaysVisible => 'Always visible';

  @override
  String get visibilityRulesNoEvents => 'Add key events first';

  @override
  String get notesAddLabel => 'Add note';

  @override
  String get notesNameLabel => 'Note name';

  @override
  String get notesContentLabel => 'Content';

  @override
  String get notesInsertImage => 'Insert image';

  @override
  String get notesImagePickTitle => 'Insert image';

  @override
  String get notesImagePickEmpty => 'No images available';

  @override
  String get notesImagePickGroupImages => 'Images';

  @override
  String get notesImagePickGroupNpcs => 'NPCs';

  @override
  String get notesDeleteMessage => 'Delete this note?';

  @override
  String get notesDelete => 'Delete';

  @override
  String get notesNameNotUnique => 'Note title must be unique';

  @override
  String get notesSearchHint => 'Search notes';

  @override
  String get notesSearchClear => 'Clear search';

  @override
  String get keyEventsNameLabel => 'Event name';

  @override
  String get keyEventsDeleteMessage =>
      'Delete this event? Every reference to it will be removed.';

  @override
  String get keyEventsDelete => 'Delete';

  @override
  String get keyEventsNameNotUnique => 'Event name must be unique';

  @override
  String get keyEventsSearchHint => 'Search events';

  @override
  String get keyEventsSearchClear => 'Clear search';

  @override
  String get soundtracksAddLabel => 'Add soundtrack';

  @override
  String get soundtracksDeleteMessage => 'Delete this soundtrack?';

  @override
  String get soundtracksDelete => 'Delete';

  @override
  String get soundtracksNameNotUnique =>
      'A soundtrack with this name already exists';

  @override
  String get soundtracksSearchHint => 'Search soundtracks';

  @override
  String get soundtracksSearchClear => 'Clear search';

  @override
  String get imagesPickLabel => 'Choose image';

  @override
  String get imagesAddTooltip => 'Add image';

  @override
  String get imagesDeleteMessage => 'Delete this image?';

  @override
  String get imagesDelete => 'Delete';

  @override
  String get imagesAddButton => 'Add';

  @override
  String get npcsNameLabel => 'Name';

  @override
  String get npcsDescriptionLabel => 'Description';

  @override
  String get npcsBackstoryLabel => 'Backstory';

  @override
  String get npcsFullImageLabel => 'Full image';

  @override
  String get npcsIconLabel => 'Icon';

  @override
  String get npcsCropFull => 'Crop full image';

  @override
  String get npcsCropIcon => 'Crop icon';

  @override
  String get npcsClone => 'Clone';

  @override
  String get npcsDelete => 'Delete';

  @override
  String get npcsDeleteMessage => 'Delete this NPC?';

  @override
  String get npcsNameNotUnique => 'An NPC with this name already exists';

  @override
  String get npcsSearchHint => 'Search NPCs';

  @override
  String get npcsSearchClear => 'Clear search';

  @override
  String get adventureClone => 'Clone';

  @override
  String get adventureDelete => 'Delete';

  @override
  String get adventureDeleteMessage => 'Delete this adventure?';

  @override
  String get scenesAddLabel => 'Add scene';

  @override
  String get scenesSearchHint => 'Search scenes';

  @override
  String get scenesSearchClear => 'Clear search';

  @override
  String get scenesDeleteMessage => 'Delete this scene?';

  @override
  String get scenesDelete => 'Delete';

  @override
  String get scenesNameNotUnique => 'A scene with this name already exists';

  @override
  String get sceneNameLabel => 'Name';

  @override
  String get sceneNarrationLabel => 'Narration';

  @override
  String get sceneSectionNpc => 'NPC';

  @override
  String get sceneSectionNotes => 'Notes';

  @override
  String get playGmNotes => 'GM Notes';

  @override
  String get playGmNoteAdd => 'Add GM note';

  @override
  String get playGmNoteGlobal => 'Global note';

  @override
  String get playGmNoteDeleteMessage =>
      'Deleting this GM note removes it from every scene. This cannot be undone.';

  @override
  String get playNpcDeactivate => 'Deactivate NPC';

  @override
  String get playVillains => 'Villains (global)';

  @override
  String get sceneSectionKeyEvents => 'Key events';

  @override
  String get sceneSectionImages => 'Images';

  @override
  String get sceneSectionAudio => 'Soundtracks';

  @override
  String get sceneSectionPaths => 'Paths';

  @override
  String get sceneAddNotes => 'Add notes';

  @override
  String get sceneChooseSoundtrack => 'Choose soundtrack';

  @override
  String get scenePickNpcTitle => 'Select NPCs';

  @override
  String get scenePickNotesTitle => 'Select notes';

  @override
  String get scenePickKeyEventsTitle => 'Select key events';

  @override
  String get scenePickImagesTitle => 'Select images';

  @override
  String get scenePickSoundtrackTitle => 'Select soundtrack';

  @override
  String get sceneSectionType => 'Scene type';

  @override
  String get sceneTypeStart => 'Starting scene';

  @override
  String get sceneTypeStandard => 'Standard scene';

  @override
  String get sceneTypeRecurring => 'Recurring scene';

  @override
  String get sceneTypeEnd => 'Ending scene';

  @override
  String get sceneSectionNextScenes => 'Next scenes';

  @override
  String get scenePickNextScenesTitle => 'Select next scenes';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => 'Close';

  @override
  String get playPauseSession => 'Pause session';

  @override
  String get playAdHocScene => 'Ad-hoc scene';

  @override
  String get playPreviousScene => 'Previous scene';

  @override
  String get playNextScene => 'Next scene';

  @override
  String get playFinishAdventure => 'Finish adventure';

  @override
  String get playSplitParty => 'Split party';

  @override
  String get playSplitTitle => 'Split party';

  @override
  String get playSplitAssignHint =>
      'Choose the players who move to the new track:';

  @override
  String get playSplitConfirm => 'Split';

  @override
  String get playPipSwitchFocus => 'Switch focus';

  @override
  String get playAdHocTitle => 'Ad-hoc scene';

  @override
  String get playAdHocNameLabel => 'Scene name';

  @override
  String get playAdHocConfirm => 'Start';

  @override
  String get playMergeHint => '→ merge';

  @override
  String get playJumpToScene => 'Jump to scene';

  @override
  String get playJumpTitle => 'Jump to scene';

  @override
  String get playEndTrack => 'End this group';

  @override
  String get playPauseConfirm => 'Save progress and go to main?';

  @override
  String get sceneSectionBackground => 'Background image';

  @override
  String get scenePickBackgroundTitle => 'Select background image';

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
