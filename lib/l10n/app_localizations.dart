import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('pl'),
    Locale('pt'),
    Locale('zh'),
  ];

  /// Application name shown in the title bar and task switcher.
  ///
  /// In en, this message translates to:
  /// **'Living Scroll - Weave every thread'**
  String get appTitle;

  /// Navigation rail label for the home destination.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Home view section title over the started playthroughs (saves) row.
  ///
  /// In en, this message translates to:
  /// **'Active sessions'**
  String get homeActiveSessions;

  /// Home view link at the end of a section row that opens the matching Library tab.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get homeMore;

  /// Home empty-state tile that opens the new-adventure form (same as the Create grid's new cell).
  ///
  /// In en, this message translates to:
  /// **'Create new adventure'**
  String get homeCreateAdventure;

  /// Navigation rail label for the adventure creation destination.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// Navigation rail label for the library destination.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Library tab listing the {Adventures} directory (unpacked .ls archives).
  ///
  /// In en, this message translates to:
  /// **'Adventures'**
  String get libraryAdventures;

  /// Library tab listing the {Saves} directory (in-progress playthroughs).
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get librarySaves;

  /// Library tab listing the {Projects} directory (work-in-progress adventures).
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get libraryProjects;

  /// Library tab listing the {Finished} directory (completed read-only adventures).
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get libraryFinished;

  /// Tooltip/label of the import tile in the Library Adventures grid (picks a .ls).
  ///
  /// In en, this message translates to:
  /// **'Import adventure'**
  String get libraryImport;

  /// Confirmation after a .ls is imported into the Adventures library.
  ///
  /// In en, this message translates to:
  /// **'Adventure imported'**
  String get libraryImportDone;

  /// Shown when the picked .ls is already in the Adventures library (not imported).
  ///
  /// In en, this message translates to:
  /// **'Already in library'**
  String get libraryImportDuplicate;

  /// Shown when the picked .ls fails validation (not imported).
  ///
  /// In en, this message translates to:
  /// **'Not a valid adventure file'**
  String get libraryImportInvalid;

  /// Library Adventures tile context-menu item: copy the library adventure into Projects as an editable copy.
  ///
  /// In en, this message translates to:
  /// **'Copy as project'**
  String get libraryCopyAsProject;

  /// Button on the Library Adventures info dialog that starts playing the adventure.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get libraryAdventurePlay;

  /// Label of the group-name text field on the adventure launch screen; required to enable Play / Dry run.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get launchGroupNameLabel;

  /// Header of the players (PC names) section on the adventure launch screen; used later to allow party split (tracks <= players).
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get launchPlayersLabel;

  /// Tooltip/label of the + button that adds another empty player-name field on the adventure launch screen.
  ///
  /// In en, this message translates to:
  /// **'Add player'**
  String get launchAddPlayer;

  /// Hint text inside an empty player-name field on the adventure launch screen.
  ///
  /// In en, this message translates to:
  /// **'Player name'**
  String get launchPlayerNameHint;

  /// Tooltip of the button that removes a player-name field on the adventure launch screen.
  ///
  /// In en, this message translates to:
  /// **'Remove player'**
  String get launchRemovePlayer;

  /// Header above the last-scene panel on the resume (saved game) launch screen, showing where the playthrough will continue.
  ///
  /// In en, this message translates to:
  /// **'Continues at'**
  String get launchLastSceneLabel;

  /// Button on the adventure launch screen: play the selected start scene WITHOUT recording any progress.
  ///
  /// In en, this message translates to:
  /// **'Prep mode'**
  String get launchDryRun;

  /// Button (new game only) on the adventure launch screen, and title of its dialog: import a finished game's key-event progress into the new save. Sits between Cancel and Prep mode.
  ///
  /// In en, this message translates to:
  /// **'Import progress'**
  String get launchImportProgress;

  /// Empty-state note in the Import progress dialog when there are no finished games to import from.
  ///
  /// In en, this message translates to:
  /// **'No finished games to import progress from.'**
  String get launchImportProgressEmpty;

  /// Confirm button that replaces an already-started save (losing its progress).
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get launchReplace;

  /// Dialog body shown when a save for this adventure + group already exists; offers Replace or Cancel.
  ///
  /// In en, this message translates to:
  /// **'Adventure {adventure} for group {group} is already started. Replacing it will lose all game progress.'**
  String launchSaveExistsMessage(String adventure, String group);

  /// Confirmation after a library adventure is copied into Projects.
  ///
  /// In en, this message translates to:
  /// **'Copied to projects'**
  String get libraryCopyDone;

  /// Context-menu item on a Library Adventures tile: export the adventure as a LaTeX document (ZIP).
  ///
  /// In en, this message translates to:
  /// **'Export to LaTeX'**
  String get libraryExportLatex;

  /// SnackBar after a LaTeX export ZIP is saved.
  ///
  /// In en, this message translates to:
  /// **'LaTeX document exported'**
  String get libraryExportLatexDone;

  /// SnackBar when a LaTeX export fails (adventure missing/unreadable).
  ///
  /// In en, this message translates to:
  /// **'Could not export the adventure to LaTeX'**
  String get libraryExportLatexError;

  /// LaTeX export: Chapter 1 title (in the adventure's language).
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get latexChapterScenes;

  /// LaTeX export: Chapter 2 title, and the in-scene NPC subsection heading.
  ///
  /// In en, this message translates to:
  /// **'NPCs'**
  String get latexChapterNpcs;

  /// LaTeX export: the Paths chapter title, shown before Chapter 1 (Scenes) only when the adventure defines any paths.
  ///
  /// In en, this message translates to:
  /// **'Paths'**
  String get latexChapterPaths;

  /// LaTeX export: a scene's Narration subsection heading.
  ///
  /// In en, this message translates to:
  /// **'Narration'**
  String get latexNarration;

  /// LaTeX export: a scene's Notes subsection heading.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get latexNotes;

  /// LaTeX export: a scene's Images subsection heading.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get latexImages;

  /// LaTeX export: a scene's Next scenes subsection heading.
  ///
  /// In en, this message translates to:
  /// **'Next scenes'**
  String get latexNextScenes;

  /// LaTeX export: an NPC's short-description subsubsection heading.
  ///
  /// In en, this message translates to:
  /// **'Short description'**
  String get latexShortDescription;

  /// LaTeX export: an NPC's backstory subsubsection heading.
  ///
  /// In en, this message translates to:
  /// **'Backstory'**
  String get latexBackstory;

  /// LaTeX export: label before a visibility-rule condition.
  ///
  /// In en, this message translates to:
  /// **'Visible when'**
  String get latexVisibleWhen;

  /// LaTeX export: the Stats subsubsection heading for a 7th Sea 2e NPC (villain/brute).
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get latexStats;

  /// LaTeX export: the scene_type phrase for 'start' in a section title.
  ///
  /// In en, this message translates to:
  /// **'opening scene'**
  String get latexSceneTypeStart;

  /// LaTeX export: the scene_type phrase for 'standard'.
  ///
  /// In en, this message translates to:
  /// **'standard scene'**
  String get latexSceneTypeStandard;

  /// LaTeX export: the scene_type phrase for 'recurring'.
  ///
  /// In en, this message translates to:
  /// **'recurring scene'**
  String get latexSceneTypeRecurring;

  /// LaTeX export: the scene_type phrase for 'end'.
  ///
  /// In en, this message translates to:
  /// **'ending scene'**
  String get latexSceneTypeEnd;

  /// LaTeX export: the Paths chapter's page-number parenthetical template — '{page}' is replaced verbatim with a \pageref{...} LaTeX call (word order varies per language).
  ///
  /// In en, this message translates to:
  /// **'page {page}'**
  String latexPageReferenceTemplate(Object page);

  /// Confirm-dialog body shown before deleting a Saves tile (an in-progress playthrough).
  ///
  /// In en, this message translates to:
  /// **'Deleting this save will lose all progress of the in-progress game.'**
  String get librarySaveDeleteMessage;

  /// Confirm-dialog body shown before deleting a Finished tile (a completed, archived session).
  ///
  /// In en, this message translates to:
  /// **'Deleting this finished session is permanent — it cannot be recovered.'**
  String get libraryFinishedDeleteMessage;

  /// Navigation rail label for the settings destination.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Navigation rail / menu label for the scene Map destination (game and play views).
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Scene map legend chip that clears the line filter and shows every path.
  ///
  /// In en, this message translates to:
  /// **'All paths'**
  String get sceneMapAllPaths;

  /// Empty-state message shown on the scene map when there are no scenes.
  ///
  /// In en, this message translates to:
  /// **'No scenes to map yet.'**
  String get sceneMapEmpty;

  /// Tooltip for the leading menu button in the navigation rail.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTooltip;

  /// Label above the language override dropdown on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// Language dropdown entry meaning no override (follow the system / default language).
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystemDefault;

  /// Label above the display-mode (light/dark/auto) options on the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Display Mode'**
  String get settingsDisplayModeLabel;

  /// Display-mode option forcing the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsModeLight;

  /// Display-mode option forcing the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsModeDark;

  /// Display-mode option following the system brightness (the application default).
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsModeAuto;

  /// Button that persists the pending settings overrides.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// Settings section header for music options.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get settingsMusicLabel;

  /// Label for the toggle that auto-plays a scene's music; on by default.
  ///
  /// In en, this message translates to:
  /// **'Autoplay'**
  String get settingsAutoplayLabel;

  /// Settings section header for the app's own build/version info.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get settingsBuildSectionLabel;

  /// Label for the row showing the app's version (from the running build).
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionLabel;

  /// Label for the row showing the app's build number (from the running build).
  ///
  /// In en, this message translates to:
  /// **'Build number'**
  String get settingsBuildNumberLabel;

  /// Title of the dialog shown when navigating away from a screen with unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedTitle;

  /// Body of the unsaved-changes dialog asking the user to choose how to leave.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Save them before leaving?'**
  String get unsavedMessage;

  /// Unsaved-changes dialog button: leave without saving, discarding pending changes.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get unsavedAbandon;

  /// Unsaved-changes dialog button: dismiss the prompt and stay on the current screen.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get unsavedCancel;

  /// No description provided for @librarySaveEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get librarySaveEdit;

  /// Hint shown on the empty cover picker tile of the new-adventure form.
  ///
  /// In en, this message translates to:
  /// **'Add cover'**
  String get createNewCoverLabel;

  /// Label for the required adventure title field.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get createNewTitleLabel;

  /// Label for the adventure version field.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get createNewVersionLabel;

  /// Label for the required game-system dropdown.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get createNewSystemLabel;

  /// Placeholder shown in the system dropdown before a system is chosen.
  ///
  /// In en, this message translates to:
  /// **'Select a system'**
  String get createNewSystemHint;

  /// Label for the adventure author field.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get createNewAuthorLabel;

  /// Label for the adventure description field.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get createNewDescriptionLabel;

  /// Label for the adventure language field.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get createNewLanguageLabel;

  /// The 'no language chosen' option in the adventure language dropdown (language is optional).
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get createNewLanguageUnset;

  /// Label for the adventure content-warnings field.
  ///
  /// In en, this message translates to:
  /// **'Content warnings'**
  String get createNewContentWarningsLabel;

  /// Label for the adventure license field.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get createNewLicenseLabel;

  /// Secondary button that imports an external LivingScroll.json into the new adventure.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get createNewImport;

  /// Primary button that creates the adventure and opens the game screen.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createNewCreate;

  /// Error shown when an imported file fails schema validation.
  ///
  /// In en, this message translates to:
  /// **'The selected file is not a valid adventure.'**
  String get createNewImportInvalid;

  /// Confirmation shown when an imported file passes validation and is staged.
  ///
  /// In en, this message translates to:
  /// **'Content imported'**
  String get createNewImportSuccess;

  /// Title of the dialog that lists the importable content categories as checkboxes.
  ///
  /// In en, this message translates to:
  /// **'Select data to import'**
  String get importSelectTitle;

  /// Button that performs the import of the selected categories.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importConfirm;

  /// Confirmation shown after the selected data has been imported into the adventure.
  ///
  /// In en, this message translates to:
  /// **'Data imported'**
  String get importDone;

  /// Shown in the import dialog when nothing can be imported: every element is already in the adventure or was skipped as system-incompatible.
  ///
  /// In en, this message translates to:
  /// **'No elements to import. Either already existing or not compatible with system'**
  String get importNothing;

  /// Label for the GM-notes content category (gm_notes).
  ///
  /// In en, this message translates to:
  /// **'GM notes'**
  String get gameGmNotes;

  /// Header of the cover-crop dialog.
  ///
  /// In en, this message translates to:
  /// **'Crop cover'**
  String get coverCropTitle;

  /// Button that accepts the selected crop region as the cover.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get coverCropConfirm;

  /// Button that dismisses the cover-crop dialog without staging a cover.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get coverCropCancel;

  /// In-game navigation rail label for the scenes section.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get gameScenes;

  /// In-game navigation rail label for the NPCs section.
  ///
  /// In en, this message translates to:
  /// **'NPCs'**
  String get gameNpcs;

  /// In-game navigation rail label for the notes section.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get gameNotes;

  /// In-game navigation rail label for the key-events section.
  ///
  /// In en, this message translates to:
  /// **'Key events'**
  String get gameKeyEvents;

  /// In-game navigation rail label for the images section.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get gameImages;

  /// In-game navigation rail label for the soundtracks section.
  ///
  /// In en, this message translates to:
  /// **'Soundtracks'**
  String get gameSoundtracks;

  /// In-game navigation rail label for the paths section.
  ///
  /// In en, this message translates to:
  /// **'Paths'**
  String get gamePaths;

  /// In-game navigation rail trailing action that validates the adventure for publishing.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get gamePublish;

  /// In-game rail trailing action: a partial export (name + system only) producing a downloadable .lse file.
  ///
  /// In en, this message translates to:
  /// **'Export elements'**
  String get gameExportPart;

  /// Title of the dialog shown when the adventure passes all publish checks.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get publishValidTitle;

  /// Body of the publish dialog when the adventure is valid.
  ///
  /// In en, this message translates to:
  /// **'The adventure was successfully exported.'**
  String get publishValidMessage;

  /// Body of the Export-elements success dialog (the .lse is ready to download).
  ///
  /// In en, this message translates to:
  /// **'The elements file is ready to download.'**
  String get publishElementsReady;

  /// Title of the dialog listing problems that block publishing.
  ///
  /// In en, this message translates to:
  /// **'Cannot publish yet'**
  String get publishInvalidTitle;

  /// Button on the export success dialog that saves the portable .ls archive to a chosen location.
  ///
  /// In en, this message translates to:
  /// **'Download .ls'**
  String get publishDownloadLs;

  /// Button on the Export-elements success dialog that saves the partial .lse archive to a chosen location.
  ///
  /// In en, this message translates to:
  /// **'Download .lse'**
  String get publishDownloadLse;

  /// Title of the dialog shown when exporting an adventure already present in the Adventures library.
  ///
  /// In en, this message translates to:
  /// **'Already in library'**
  String get libraryDuplicateTitle;

  /// Body of the library-duplicate dialog (offers Overwrite or Cancel).
  ///
  /// In en, this message translates to:
  /// **'An adventure with the same title, version, system, author and language is already in your library. Overwrite it?'**
  String get libraryDuplicateMessage;

  /// Confirm button that replaces the existing library copy of the adventure.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get libraryOverwrite;

  /// A required adventure metadata field is empty.
  ///
  /// In en, this message translates to:
  /// **'Adventure setting \"{field}\" is required.'**
  String publishIssueAdventureField(String field);

  /// An NPC is missing its name or one of its portrait images.
  ///
  /// In en, this message translates to:
  /// **'NPC \"{name}\" needs a name and both portrait images.'**
  String publishIssueNpcIncomplete(String name);

  /// A note has no name.
  ///
  /// In en, this message translates to:
  /// **'A note is missing its name or content.'**
  String get publishIssueNoteName;

  /// The adventure has no start scene.
  ///
  /// In en, this message translates to:
  /// **'There must be at least one start scene.'**
  String get publishIssueNoStartScene;

  /// The adventure has no end scene.
  ///
  /// In en, this message translates to:
  /// **'There must be at least one end scene.'**
  String get publishIssueNoEndScene;

  /// An end scene declares a next scene.
  ///
  /// In en, this message translates to:
  /// **'End scene \"{name}\" must not have a next scene.'**
  String publishIssueEndSceneHasNext(String name);

  /// A non-end scene declares no next scene.
  ///
  /// In en, this message translates to:
  /// **'Scene \"{name}\" must have a next scene.'**
  String publishIssueSceneNoNext(String name);

  /// A non-end scene's only next scenes are all conditional.
  ///
  /// In en, this message translates to:
  /// **'Scene \"{name}\" must have at least one next scene that is always available.'**
  String publishIssueSceneOnlyConditionalNext(String name);

  /// No unconditional path reaches an end scene.
  ///
  /// In en, this message translates to:
  /// **'No path of always-available scenes leads from a start scene to an end scene.'**
  String get publishIssueNoPathToEnd;

  /// A non-recurring scene lies on a next_scenes cycle (blind loop).
  ///
  /// In en, this message translates to:
  /// **'Scene \"{name}\" is a dead loop: another scene leads back to it after it has already been visited. Make it a recurring scene to allow returning.'**
  String publishIssueBlindLoop(String name);

  /// A named story path has no start scene tagged onto it.
  ///
  /// In en, this message translates to:
  /// **'Path \"{name}\" must have a start scene.'**
  String publishIssuePathNoStartScene(String name);

  /// A named story path has no end scene tagged onto it.
  ///
  /// In en, this message translates to:
  /// **'Path \"{name}\" must have an end scene.'**
  String publishIssuePathNoEndScene(String name);

  /// No unconditional route within a story path's own tagged scenes reaches its end scene.
  ///
  /// In en, this message translates to:
  /// **'Within path \"{name}\"\'s own scenes, no route of always-available scenes leads from its start scene to its end scene.'**
  String publishIssuePathNoRouteToEnd(String name);

  /// In-game navigation rail label for the adventure-settings section (edits the adventure's metadata and cover).
  ///
  /// In en, this message translates to:
  /// **'Adventure settings'**
  String get gameAdventureSettings;

  /// Label for the path name field on the path edit form (Paths section).
  ///
  /// In en, this message translates to:
  /// **'Path name'**
  String get pathEditNameLabel;

  /// Dialog message shown when Save is attempted on a path that is referenced by a scene's path_names but whose name field has been left blank.
  ///
  /// In en, this message translates to:
  /// **'This path is used by a scene, so it needs a name'**
  String get pathNameRequired;

  /// Header of the GM-only visibility-rules editor.
  ///
  /// In en, this message translates to:
  /// **'Visibility rules'**
  String get visibilityRulesTitle;

  /// Operator radio (AND): the object is visible when ALL selected key events are checked.
  ///
  /// In en, this message translates to:
  /// **'All satisfied'**
  String get visibilityRulesAnd;

  /// Operator radio (OR): the object is visible when ANY selected key event is checked.
  ///
  /// In en, this message translates to:
  /// **'Any satisfied'**
  String get visibilityRulesOr;

  /// Hint shown in the visibility-rules editor when no key events are selected (no gate).
  ///
  /// In en, this message translates to:
  /// **'Always visible'**
  String get visibilityRulesAlwaysVisible;

  /// Hint shown in the visibility-rules editor when the adventure has no key events to choose from.
  ///
  /// In en, this message translates to:
  /// **'Add key events first'**
  String get visibilityRulesNoEvents;

  /// Label on the empty 'add note' cell of the Notes grid.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get notesAddLabel;

  /// Label for the note name field on the note edit form.
  ///
  /// In en, this message translates to:
  /// **'Note name'**
  String get notesNameLabel;

  /// Label for the note content field on the note edit form.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get notesContentLabel;

  /// Tooltip for the note editor toolbar button that embeds an image into the note body.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get notesInsertImage;

  /// Title of the dialog that picks an image (adventure image or NPC portrait) to embed in a note.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get notesImagePickTitle;

  /// Shown in the note image picker when the adventure has no images or NPC portraits to embed.
  ///
  /// In en, this message translates to:
  /// **'No images available'**
  String get notesImagePickEmpty;

  /// Header over the adventure images section of the note image picker.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get notesImagePickGroupImages;

  /// Header over the NPC portraits section of the note image picker.
  ///
  /// In en, this message translates to:
  /// **'NPCs'**
  String get notesImagePickGroupNpcs;

  /// Body of the confirm dialog shown before deleting a note.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get notesDeleteMessage;

  /// Confirm button that deletes a note.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get notesDelete;

  /// Dialog message shown when the user tries to save a note whose name is already used by another note in the same document.
  ///
  /// In en, this message translates to:
  /// **'Note title must be unique'**
  String get notesNameNotUnique;

  /// Placeholder hint in the search field at the top of the Notes section; filtering matches the note title and content.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get notesSearchHint;

  /// Tooltip/label for the button at the end of the Notes search field that clears the query.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get notesSearchClear;

  /// Label for the event name field on the key-event edit form.
  ///
  /// In en, this message translates to:
  /// **'Event name'**
  String get keyEventsNameLabel;

  /// Body of the confirm dialog shown before cascade-deleting a key event.
  ///
  /// In en, this message translates to:
  /// **'Delete this event? Every reference to it will be removed.'**
  String get keyEventsDeleteMessage;

  /// Confirm button that cascade-deletes a key event.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get keyEventsDelete;

  /// Dialog message shown when the user tries to save a key event whose name is already used by another event in the same document.
  ///
  /// In en, this message translates to:
  /// **'Event name must be unique'**
  String get keyEventsNameNotUnique;

  /// Placeholder hint in the search field at the top of the Key events section; filtering matches the event name and description.
  ///
  /// In en, this message translates to:
  /// **'Search events'**
  String get keyEventsSearchHint;

  /// Tooltip/label for the button at the end of the Key events search field that clears the query.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get keyEventsSearchClear;

  /// Label of the 'add soundtrack' action row at the top of the Soundtracks list.
  ///
  /// In en, this message translates to:
  /// **'Add soundtrack'**
  String get soundtracksAddLabel;

  /// Body of the confirm dialog shown before deleting a soundtrack (removes the entry and its audio file).
  ///
  /// In en, this message translates to:
  /// **'Delete this soundtrack?'**
  String get soundtracksDeleteMessage;

  /// Confirm button that deletes a soundtrack and its file.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get soundtracksDelete;

  /// Dialog message shown when an added soundtrack's derived display name is already used by another track.
  ///
  /// In en, this message translates to:
  /// **'A soundtrack with this name already exists'**
  String get soundtracksNameNotUnique;

  /// Placeholder hint in the search field at the top of the Soundtracks section; filtering matches the track name.
  ///
  /// In en, this message translates to:
  /// **'Search soundtracks'**
  String get soundtracksSearchHint;

  /// Tooltip/label for the button at the end of the Soundtracks search field that clears the query.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get soundtracksSearchClear;

  /// Button that opens the image picker on the location edit form.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get imagesPickLabel;

  /// Tooltip on the empty + tile that picks an image to add in the Images section.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get imagesAddTooltip;

  /// Body of the confirm dialog shown before deleting an image.
  ///
  /// In en, this message translates to:
  /// **'Delete this image?'**
  String get imagesDeleteMessage;

  /// Confirm button that deletes an image.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get imagesDelete;

  /// Primary button on the Images add form that commits the picked image.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get imagesAddButton;

  /// Label of the required, unique name field on the NPC edit form.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get npcsNameLabel;

  /// Label of the description field on the NPC edit form.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get npcsDescriptionLabel;

  /// Label of the backstory field on the NPC edit form.
  ///
  /// In en, this message translates to:
  /// **'Backstory'**
  String get npcsBackstoryLabel;

  /// Empty-state label of the full-image picker on the NPC edit form.
  ///
  /// In en, this message translates to:
  /// **'Full image'**
  String get npcsFullImageLabel;

  /// Empty-state label of the icon-image picker on the NPC edit form.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get npcsIconLabel;

  /// Header of the crop step for an NPC's full image.
  ///
  /// In en, this message translates to:
  /// **'Crop full image'**
  String get npcsCropFull;

  /// Header of the crop step for an NPC's icon (cropped from the full image).
  ///
  /// In en, this message translates to:
  /// **'Crop icon'**
  String get npcsCropIcon;

  /// NPC tile context-menu item that duplicates the NPC.
  ///
  /// In en, this message translates to:
  /// **'Clone'**
  String get npcsClone;

  /// NPC tile context-menu item / confirm button that deletes the NPC.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get npcsDelete;

  /// Body of the confirm dialog shown before deleting an NPC.
  ///
  /// In en, this message translates to:
  /// **'Delete this NPC?'**
  String get npcsDeleteMessage;

  /// Dialog message shown when an NPC's name is already used by another NPC.
  ///
  /// In en, this message translates to:
  /// **'An NPC with this name already exists'**
  String get npcsNameNotUnique;

  /// Placeholder hint in the search field at the top of the NPC section.
  ///
  /// In en, this message translates to:
  /// **'Search NPCs'**
  String get npcsSearchHint;

  /// Tooltip/label for the button that clears the NPC search query.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get npcsSearchClear;

  /// Adventure tile context-menu item that duplicates the adventure into a new project.
  ///
  /// In en, this message translates to:
  /// **'Clone'**
  String get adventureClone;

  /// Adventure tile context-menu item / confirm button that deletes the adventure.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adventureDelete;

  /// Body of the confirm dialog shown before deleting an adventure from the Create grid.
  ///
  /// In en, this message translates to:
  /// **'Delete this adventure?'**
  String get adventureDeleteMessage;

  /// Tooltip/label of the add action at the top of the Scenes list.
  ///
  /// In en, this message translates to:
  /// **'Add scene'**
  String get scenesAddLabel;

  /// Placeholder hint in the search field at the top of the Scenes section.
  ///
  /// In en, this message translates to:
  /// **'Search scenes'**
  String get scenesSearchHint;

  /// Tooltip for the button that clears the Scenes search query.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get scenesSearchClear;

  /// Body of the confirm dialog shown before deleting a scene.
  ///
  /// In en, this message translates to:
  /// **'Delete this scene?'**
  String get scenesDeleteMessage;

  /// Confirm button that deletes a scene.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get scenesDelete;

  /// Dialog message shown when a scene's name is already used by another scene.
  ///
  /// In en, this message translates to:
  /// **'A scene with this name already exists'**
  String get scenesNameNotUnique;

  /// Label of the scene name field in the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sceneNameLabel;

  /// Label of the full-width narration (description) field in the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Narration'**
  String get sceneNarrationLabel;

  /// Divider label for the NPC section of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'NPC'**
  String get sceneSectionNpc;

  /// Divider label for the Notes section of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get sceneSectionNotes;

  /// Play view rail item (last) opening the GM notes grid for the current scene.
  ///
  /// In en, this message translates to:
  /// **'GM Notes'**
  String get playGmNotes;

  /// Title of the add-GM-note form / tooltip of the add tile in the play view's GM Notes grid.
  ///
  /// In en, this message translates to:
  /// **'Add GM note'**
  String get playGmNoteAdd;

  /// Checkbox on the add-GM-note form: when checked the note is added to every scene, not just the current one.
  ///
  /// In en, this message translates to:
  /// **'Global note'**
  String get playGmNoteGlobal;

  /// Body of the confirmation dialog when deleting a GM note from the play view's GM Notes grid.
  ///
  /// In en, this message translates to:
  /// **'Deleting this GM note removes it from every scene. This cannot be undone.'**
  String get playGmNoteDeleteMessage;

  /// Tooltip of the play view's NPC tile button that greys out (deactivates) the NPC; committed as npcs[].state == inactive on the next scene navigation.
  ///
  /// In en, this message translates to:
  /// **'Deactivate NPC'**
  String get playNpcDeactivate;

  /// Play view rail item (7th Sea 2nd Edition only, ALWAYS the last rail item) opening the Villains grid: every Villain-kind NPC in the whole adventure, regardless of scene attachment. The label spells out "(global)" since this is the one rail item that is not scene-scoped.
  ///
  /// In en, this message translates to:
  /// **'Villains (global)'**
  String get playVillains;

  /// Divider label for the Key events section of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Key events'**
  String get sceneSectionKeyEvents;

  /// Divider label for the Images section of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get sceneSectionImages;

  /// Divider label for the Soundtracks section of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Soundtracks'**
  String get sceneSectionAudio;

  /// Divider label for the Paths multi-select of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Paths'**
  String get sceneSectionPaths;

  /// Label of the button that opens the notes picker in the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Add notes'**
  String get sceneAddNotes;

  /// Placeholder label on the soundtrack button when none is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose soundtrack'**
  String get sceneChooseSoundtrack;

  /// App bar title of the scene NPC picker.
  ///
  /// In en, this message translates to:
  /// **'Select NPCs'**
  String get scenePickNpcTitle;

  /// App bar title of the scene notes picker.
  ///
  /// In en, this message translates to:
  /// **'Select notes'**
  String get scenePickNotesTitle;

  /// App bar title of the scene key events picker.
  ///
  /// In en, this message translates to:
  /// **'Select key events'**
  String get scenePickKeyEventsTitle;

  /// App bar title of the scene images picker.
  ///
  /// In en, this message translates to:
  /// **'Select images'**
  String get scenePickImagesTitle;

  /// App bar title of the scene soundtrack picker.
  ///
  /// In en, this message translates to:
  /// **'Select soundtrack'**
  String get scenePickSoundtrackTitle;

  /// Divider label for the scene-type radio in the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Scene type'**
  String get sceneSectionType;

  /// Scene-type radio: the adventure's starting scene (scene_type=start).
  ///
  /// In en, this message translates to:
  /// **'Starting scene'**
  String get sceneTypeStart;

  /// Scene-type radio: a standard scene (scene_type=standard).
  ///
  /// In en, this message translates to:
  /// **'Standard scene'**
  String get sceneTypeStandard;

  /// Scene-type radio: a recurring scene (scene_type=recurring).
  ///
  /// In en, this message translates to:
  /// **'Recurring scene'**
  String get sceneTypeRecurring;

  /// Scene-type radio: an ending scene (scene_type=end).
  ///
  /// In en, this message translates to:
  /// **'Ending scene'**
  String get sceneTypeEnd;

  /// Divider label and button label for the Next scenes section of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Next scenes'**
  String get sceneSectionNextScenes;

  /// App bar title of the next-scenes picker.
  ///
  /// In en, this message translates to:
  /// **'Select next scenes'**
  String get scenePickNextScenesTitle;

  /// Generic OK button shown in form dialogs (e.g. the name-not-unique alerts).
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get dialogOk;

  /// Generic Close button that dismisses a detail/info dialog (e.g. the NPC info window).
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get dialogClose;

  /// Play view rail item that pauses the session / exits the preview.
  ///
  /// In en, this message translates to:
  /// **'Pause session'**
  String get playPauseSession;

  /// Play view button that starts an improvised scene (hidden on ending scenes).
  ///
  /// In en, this message translates to:
  /// **'Ad-hoc scene'**
  String get playAdHocScene;

  /// Prep-mode play view button (first in the Next scenes row) that goes back to the scene the player arrived from.
  ///
  /// In en, this message translates to:
  /// **'Previous scene'**
  String get playPreviousScene;

  /// Replay view button that steps forward to the next scene in the finished session's recorded chronology.
  ///
  /// In en, this message translates to:
  /// **'Next scene'**
  String get playNextScene;

  /// Gameplay button on an end scene: saves progress, archives the playthrough to Finished, and returns Home.
  ///
  /// In en, this message translates to:
  /// **'Finish adventure'**
  String get playFinishAdventure;

  /// Play view button (near the Next scenes row) that opens the split dialog to divide the focused track into two tracks.
  ///
  /// In en, this message translates to:
  /// **'Split party'**
  String get playSplitParty;

  /// Title of the split dialog where the GM picks which player-characters move to the new track.
  ///
  /// In en, this message translates to:
  /// **'Split party'**
  String get playSplitTitle;

  /// Instruction above the player checkboxes in the split dialog (at least one moves, at least one stays).
  ///
  /// In en, this message translates to:
  /// **'Choose the players who move to the new track:'**
  String get playSplitAssignHint;

  /// Confirm button of the split dialog; enabled once at least one player is selected and at least one is left behind.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get playSplitConfirm;

  /// Tooltip of a picture-in-picture track thumbnail: tapping it makes that track the focused (full-screen) one.
  ///
  /// In en, this message translates to:
  /// **'Switch focus'**
  String get playPipSwitchFocus;

  /// Title of the dialog that names a new ad-hoc (improvised) scene before starting it.
  ///
  /// In en, this message translates to:
  /// **'Ad-hoc scene'**
  String get playAdHocTitle;

  /// Label of the name field in the ad-hoc scene dialog; required (Confirm stays disabled while blank).
  ///
  /// In en, this message translates to:
  /// **'Scene name'**
  String get playAdHocNameLabel;

  /// Confirm button of the ad-hoc scene dialog; enabled once a name is entered. Starts the improvised scene.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get playAdHocConfirm;

  /// Marker on a next-scene button (or jump target) whose scene is already occupied by another party track: following it merges the two tracks.
  ///
  /// In en, this message translates to:
  /// **'→ merge'**
  String get playMergeHint;

  /// Play view button (party split): shown when the party is split or the track is in a dead end; opens the jump-target dialog.
  ///
  /// In en, this message translates to:
  /// **'Jump to scene'**
  String get playJumpToScene;

  /// Title of the Jump-to-scene dialog listing the scenes the focused track can jump to.
  ///
  /// In en, this message translates to:
  /// **'Jump to scene'**
  String get playJumpTitle;

  /// Gameplay button on an end scene when other party tracks are still active: ends only this track (focus passes to another) instead of finishing the whole adventure.
  ///
  /// In en, this message translates to:
  /// **'End this group'**
  String get playEndTrack;

  /// Body of the gameplay Pause confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'Save progress and go to main?'**
  String get playPauseConfirm;

  /// Divider label for the Background image section at the bottom of the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Background image'**
  String get sceneSectionBackground;

  /// Title of the Background image picker opened from the scene editor.
  ///
  /// In en, this message translates to:
  /// **'Select background image'**
  String get scenePickBackgroundTitle;

  /// 7th Sea NPC wizard: title of page 1 (the kind selector).
  ///
  /// In en, this message translates to:
  /// **'NPC type'**
  String get npcSeaPageKind;

  /// 7th Sea NPC wizard: title of page 2 (details).
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get npcSeaPageDetails;

  /// 7th Sea NPC wizard next button.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get npcSeaNext;

  /// 7th Sea NPC wizard back button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get npcSeaBack;

  /// 7th Sea NPC: label of the kind (type) field.
  ///
  /// In en, this message translates to:
  /// **'NPC type'**
  String get npcSeaKindLabel;

  /// 7th Sea NPC kind: Villain.
  ///
  /// In en, this message translates to:
  /// **'Villain'**
  String get npcSeaKindVillain;

  /// 7th Sea NPC kind: Brutes, Monsters, Allies (a Strength-only NPC).
  ///
  /// In en, this message translates to:
  /// **'Brutes, Monsters, Allies'**
  String get npcSeaKindBrute;

  /// 7th Sea NPC kind: Story character (a narrative NPC with no stats).
  ///
  /// In en, this message translates to:
  /// **'Story character'**
  String get npcSeaKindMonster;

  /// 7th Sea NPC: suffix on a computed (derived) read-only field.
  ///
  /// In en, this message translates to:
  /// **'computed'**
  String get npcSeaComputed;

  /// 7th Sea NPC stat: Strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get statSeaStrength;

  /// 7th Sea NPC stat: Influence.
  ///
  /// In en, this message translates to:
  /// **'Influence'**
  String get statSeaInfluence;

  /// 7th Sea NPC stat: Villainy Rank (computed = Strength + Influence).
  ///
  /// In en, this message translates to:
  /// **'Villainy Rank'**
  String get statSeaVillainyRank;

  /// 7th Sea NPC stat: Advantages checklist.
  ///
  /// In en, this message translates to:
  /// **'Advantages'**
  String get statSeaAdvantages;

  /// 7th Sea Villain NPC stat: Schemes section title.
  ///
  /// In en, this message translates to:
  /// **'Schemes'**
  String get statSeaSchemes;

  /// 7th Sea Villain: button to add a new scheme.
  ///
  /// In en, this message translates to:
  /// **'New scheme'**
  String get npcSeaSchemeNew;

  /// 7th Sea Villain scheme dialog: the name field label.
  ///
  /// In en, this message translates to:
  /// **'Scheme name'**
  String get npcSeaSchemeName;

  /// 7th Sea Villain scheme dialog: the cost (influence) field label.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get npcSeaSchemeCost;

  /// 7th Sea Villain scheme dialog: the confirm button when adding.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get npcSeaSchemeAdd;

  /// 7th Sea Villain scheme dialog title when editing an existing scheme.
  ///
  /// In en, this message translates to:
  /// **'Edit scheme'**
  String get npcSeaSchemeEditTitle;

  /// 7th Sea Villain scheme dialog: label for the remaining influence budget.
  ///
  /// In en, this message translates to:
  /// **'Available influence'**
  String get npcSeaSchemeAvailable;

  /// 7th Sea Villain play schemes manager: right-panel title (list of purchased costs).
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get npcSeaCostsTitle;

  /// 7th Sea Villain play schemes manager: the Buy button / buy-cost dialog confirm.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get npcSeaSchemeBuy;

  /// 7th Sea Villain buy-cost dialog: the description field label.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get npcSeaCostDescription;

  /// 7th Sea Villain NPC tile badge: Strength (short label).
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get npcSeaTileStrength;

  /// 7th Sea Villain NPC tile badge: Influence (short label).
  ///
  /// In en, this message translates to:
  /// **'Influence'**
  String get npcSeaTileInfluence;

  /// 7th Sea Villain NPC tile badge: Rank (short label).
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get npcSeaTileRank;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'pl',
    'pt',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
