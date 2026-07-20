// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'Start';

  @override
  String get homeActiveSessions => 'Aktive Sitzungen';

  @override
  String get homeMore => 'Mehr';

  @override
  String get homeCreateAdventure => 'Neues Abenteuer erstellen';

  @override
  String get navCreate => 'Erstellen';

  @override
  String get navLibrary => 'Bibliothek';

  @override
  String get libraryAdventures => 'Abenteuer';

  @override
  String get librarySaves => 'Spielstände';

  @override
  String get libraryProjects => 'Projekte';

  @override
  String get libraryFinished => 'Abgeschlossen';

  @override
  String get libraryImport => 'Abenteuer importieren';

  @override
  String get libraryImportDone => 'Abenteuer importiert';

  @override
  String get libraryImportDuplicate => 'Bereits in der Bibliothek';

  @override
  String get libraryImportInvalid => 'Keine gültige Abenteuerdatei';

  @override
  String get libraryCopyAsProject => 'Als Projekt kopieren';

  @override
  String get libraryAdventurePlay => 'Spielen';

  @override
  String get launchGroupNameLabel => 'Gruppenname';

  @override
  String get launchPlayersLabel => 'Spieler';

  @override
  String get launchAddPlayer => 'Spieler hinzufügen';

  @override
  String get launchPlayerNameHint => 'Spielername';

  @override
  String get launchRemovePlayer => 'Spieler entfernen';

  @override
  String get launchLastSceneLabel => 'Fortsetzung bei';

  @override
  String get launchDryRun => 'Vorbereitungsmodus';

  @override
  String get launchImportProgress => 'Fortschritt importieren';

  @override
  String get launchImportProgressEmpty =>
      'Keine abgeschlossenen Spiele, aus denen Fortschritt importiert werden kann.';

  @override
  String get launchReplace => 'Ersetzen';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'Das Abenteuer $adventure für Gruppe $group ist bereits gestartet. Wenn du es ersetzt, geht der gesamte Spielfortschritt verloren.';
  }

  @override
  String get libraryCopyDone => 'In Projekte kopiert';

  @override
  String get libraryExportLatex => 'Nach LaTeX exportieren';

  @override
  String get libraryExportLatexDone => 'LaTeX-Dokument exportiert';

  @override
  String get libraryExportLatexError =>
      'Das Abenteuer konnte nicht nach LaTeX exportiert werden';

  @override
  String get latexChapterScenes => 'Szenen';

  @override
  String get latexChapterNpcs => 'NSCs';

  @override
  String get latexChapterPaths => 'Pfade';

  @override
  String get latexNarration => 'Erzählung';

  @override
  String get latexNotes => 'Notizen';

  @override
  String get latexImages => 'Bilder';

  @override
  String get latexNextScenes => 'Nächste Szenen';

  @override
  String get latexShortDescription => 'Kurzbeschreibung';

  @override
  String get latexBackstory => 'Hintergrund';

  @override
  String get latexVisibleWhen => 'Sichtbar wenn';

  @override
  String get latexStats => 'Werte';

  @override
  String get latexSceneTypeStart => 'Startszene';

  @override
  String get latexSceneTypeStandard => 'Standardszene';

  @override
  String get latexSceneTypeRecurring => 'Wiederkehrende Szene';

  @override
  String get latexSceneTypeEnd => 'Endszene';

  @override
  String latexPageReferenceTemplate(Object page) {
    return 'Seite $page';
  }

  @override
  String get librarySaveDeleteMessage =>
      'Das Löschen dieses Spielstands verwirft den gesamten Fortschritt der laufenden Partie.';

  @override
  String get libraryFinishedDeleteMessage =>
      'Das Löschen dieser abgeschlossenen Sitzung ist endgültig — sie kann nicht wiederhergestellt werden.';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navMap => 'Karte';

  @override
  String get sceneMapAllPaths => 'Alle Pfade';

  @override
  String get sceneMapEmpty => 'Noch keine Szenen für die Karte.';

  @override
  String get menuTooltip => 'Menü';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get settingsLanguageSystemDefault => 'Systemstandard';

  @override
  String get settingsDisplayModeLabel => 'Anzeigemodus';

  @override
  String get settingsModeLight => 'Hell';

  @override
  String get settingsModeDark => 'Dunkel';

  @override
  String get settingsModeAuto => 'Automatisch';

  @override
  String get settingsSave => 'Speichern';

  @override
  String get settingsMusicLabel => 'Musik';

  @override
  String get settingsAutoplayLabel => 'Automatische Wiedergabe';

  @override
  String get settingsBuildSectionLabel => 'Build';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsBuildNumberLabel => 'Build-Nummer';

  @override
  String get unsavedTitle => 'Nicht gespeicherte Änderungen';

  @override
  String get unsavedMessage =>
      'Sie haben nicht gespeicherte Änderungen. Vor dem Verlassen speichern?';

  @override
  String get unsavedAbandon => 'Verwerfen';

  @override
  String get unsavedCancel => 'Abbrechen';

  @override
  String get librarySaveEdit => 'Bearbeiten';

  @override
  String get createNewCoverLabel => 'Titelbild hinzufügen';

  @override
  String get createNewTitleLabel => 'Titel';

  @override
  String get createNewVersionLabel => 'Version';

  @override
  String get createNewSystemLabel => 'System';

  @override
  String get createNewSystemHint => 'System auswählen';

  @override
  String get createNewAuthorLabel => 'Autor';

  @override
  String get createNewDescriptionLabel => 'Beschreibung';

  @override
  String get createNewLanguageLabel => 'Sprache';

  @override
  String get createNewLanguageUnset => 'Nicht angegeben';

  @override
  String get createNewContentWarningsLabel => 'Inhaltswarnungen';

  @override
  String get createNewLicenseLabel => 'Lizenz';

  @override
  String get createNewImport => 'Daten importieren';

  @override
  String get createNewCreate => 'Erstellen';

  @override
  String get createNewImportInvalid =>
      'Die ausgewählte Datei ist kein gültiges Abenteuer.';

  @override
  String get createNewImportSuccess => 'Inhalt importiert';

  @override
  String get importSelectTitle => 'Daten zum Importieren auswählen';

  @override
  String get importConfirm => 'Importieren';

  @override
  String get importDone => 'Daten importiert';

  @override
  String get importNothing =>
      'Keine Elemente zum Importieren. Entweder bereits vorhanden oder nicht mit dem System kompatibel';

  @override
  String get gameGmNotes => 'SL-Notizen';

  @override
  String get coverCropTitle => 'Titelbild zuschneiden';

  @override
  String get coverCropConfirm => 'Zuschneiden';

  @override
  String get coverCropCancel => 'Abbrechen';

  @override
  String get gameScenes => 'Szenen';

  @override
  String get gameNpcs => 'NSCs';

  @override
  String get gameNotes => 'Notizen';

  @override
  String get gameKeyEvents => 'Schlüsselereignisse';

  @override
  String get gameImages => 'Bilder';

  @override
  String get gameSoundtracks => 'Soundtracks';

  @override
  String get gamePaths => 'Pfade';

  @override
  String get gamePublish => 'Exportieren';

  @override
  String get gameExportPart => 'Elemente exportieren';

  @override
  String get publishValidTitle => 'Exportiert';

  @override
  String get publishValidMessage =>
      'Das Abenteuer wurde erfolgreich exportiert.';

  @override
  String get publishElementsReady =>
      'Die Elemente-Datei steht zum Download bereit.';

  @override
  String get publishInvalidTitle => 'Noch nicht veröffentlichbar';

  @override
  String get publishDownloadLs => '.ls herunterladen';

  @override
  String get publishDownloadLse => '.lse herunterladen';

  @override
  String get libraryDuplicateTitle => 'Bereits in der Bibliothek';

  @override
  String get libraryDuplicateMessage =>
      'Ein Abenteuer mit demselben Titel, Version, System, Autor und Sprache ist bereits in deiner Bibliothek. Überschreiben?';

  @override
  String get libraryOverwrite => 'Überschreiben';

  @override
  String publishIssueAdventureField(String field) {
    return 'Abenteuer-Einstellung \"$field\" ist erforderlich.';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'NSC \"$name\" benötigt einen Namen und beide Porträtbilder.';
  }

  @override
  String get publishIssueNoteName =>
      'Einer Notiz fehlt der Name oder der Inhalt.';

  @override
  String get publishIssueNoStartScene =>
      'Es muss mindestens eine Startszene geben.';

  @override
  String get publishIssueNoEndScene =>
      'Es muss mindestens eine Endszene geben.';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return 'Endszene \"$name\" darf keine Folgeszene haben.';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'Szene \"$name\" muss eine Folgeszene haben.';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'Szene \"$name\" muss mindestens eine immer verfügbare Folgeszene haben.';
  }

  @override
  String get publishIssueNoPathToEnd =>
      'Kein Pfad aus immer verfügbaren Szenen führt von einer Startszene zu einer Endszene.';

  @override
  String publishIssueBlindLoop(String name) {
    return 'Szene \"$name\" ist eine Sackgassen-Schleife: Eine andere Szene führt zu ihr zurück, nachdem sie bereits besucht wurde. Mache sie zu einer wiederkehrenden Szene, um die Rückkehr zu erlauben.';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'Pfad \"$name\" muss eine Startszene haben.';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'Pfad \"$name\" muss eine Endszene haben.';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'Innerhalb der eigenen Szenen von Pfad \"$name\" führt kein Weg aus immer verfügbaren Szenen von dessen Startszene zu dessen Endszene.';
  }

  @override
  String get gameAdventureSettings => 'Abenteuer-Einstellungen';

  @override
  String get pathEditNameLabel => 'Pfadname';

  @override
  String get pathNameRequired =>
      'Dieser Pfad wird von einer Szene verwendet und benötigt daher einen Namen';

  @override
  String get visibilityRulesTitle => 'Sichtbarkeitsregeln';

  @override
  String get visibilityRulesAnd => 'Alle erfüllt';

  @override
  String get visibilityRulesOr => 'Beliebige erfüllt';

  @override
  String get visibilityRulesAlwaysVisible => 'Immer sichtbar';

  @override
  String get visibilityRulesNoEvents => 'Zuerst Schlüsselereignisse hinzufügen';

  @override
  String get notesAddLabel => 'Notiz hinzufügen';

  @override
  String get notesNameLabel => 'Notizname';

  @override
  String get notesContentLabel => 'Inhalt';

  @override
  String get notesInsertImage => 'Bild einfügen';

  @override
  String get notesImagePickTitle => 'Bild einfügen';

  @override
  String get notesImagePickEmpty => 'Keine Bilder verfügbar';

  @override
  String get notesImagePickGroupImages => 'Bilder';

  @override
  String get notesImagePickGroupNpcs => 'NSCs';

  @override
  String get notesDeleteMessage => 'Diese Notiz löschen?';

  @override
  String get notesDelete => 'Löschen';

  @override
  String get notesNameNotUnique => 'Der Notizname muss eindeutig sein';

  @override
  String get notesSearchHint => 'Notizen durchsuchen';

  @override
  String get notesSearchClear => 'Suche löschen';

  @override
  String get keyEventsNameLabel => 'Ereignisname';

  @override
  String get keyEventsDeleteMessage =>
      'Dieses Ereignis löschen? Alle Verweise darauf werden entfernt.';

  @override
  String get keyEventsDelete => 'Löschen';

  @override
  String get keyEventsNameNotUnique => 'Der Ereignisname muss eindeutig sein';

  @override
  String get keyEventsSearchHint => 'Ereignisse durchsuchen';

  @override
  String get keyEventsSearchClear => 'Suche löschen';

  @override
  String get soundtracksAddLabel => 'Soundtrack hinzufügen';

  @override
  String get soundtracksDeleteMessage => 'Diesen Soundtrack löschen?';

  @override
  String get soundtracksDelete => 'Löschen';

  @override
  String get soundtracksNameNotUnique =>
      'Ein Soundtrack mit diesem Namen existiert bereits';

  @override
  String get soundtracksSearchHint => 'Soundtracks durchsuchen';

  @override
  String get soundtracksSearchClear => 'Suche löschen';

  @override
  String get imagesPickLabel => 'Bild auswählen';

  @override
  String get imagesAddTooltip => 'Bild hinzufügen';

  @override
  String get imagesDeleteMessage => 'Dieses Bild löschen?';

  @override
  String get imagesDelete => 'Löschen';

  @override
  String get imagesAddButton => 'Hinzufügen';

  @override
  String get npcsNameLabel => 'Name';

  @override
  String get npcsDescriptionLabel => 'Beschreibung';

  @override
  String get npcsBackstoryLabel => 'Hintergrund';

  @override
  String get npcsFullImageLabel => 'Vollständiges Bild';

  @override
  String get npcsIconLabel => 'Symbol';

  @override
  String get npcsCropFull => 'Vollständiges Bild zuschneiden';

  @override
  String get npcsCropIcon => 'Symbol zuschneiden';

  @override
  String get npcsClone => 'Klonen';

  @override
  String get npcsDelete => 'Löschen';

  @override
  String get npcsDeleteMessage => 'Diesen NSC löschen?';

  @override
  String get npcsNameNotUnique => 'Ein NSC mit diesem Namen existiert bereits';

  @override
  String get npcsSearchHint => 'NSCs durchsuchen';

  @override
  String get npcsSearchClear => 'Suche löschen';

  @override
  String get adventureClone => 'Klonen';

  @override
  String get adventureDelete => 'Löschen';

  @override
  String get adventureDeleteMessage => 'Dieses Abenteuer löschen?';

  @override
  String get scenesAddLabel => 'Szene hinzufügen';

  @override
  String get scenesSearchHint => 'Szenen suchen';

  @override
  String get scenesSearchClear => 'Suche löschen';

  @override
  String get scenesDeleteMessage => 'Diese Szene löschen?';

  @override
  String get scenesDelete => 'Löschen';

  @override
  String get scenesNameNotUnique =>
      'Eine Szene mit diesem Namen existiert bereits';

  @override
  String get sceneNameLabel => 'Name';

  @override
  String get sceneNarrationLabel => 'Erzählung';

  @override
  String get sceneSectionNpc => 'NSC';

  @override
  String get sceneSectionNotes => 'Notizen';

  @override
  String get playGmNotes => 'GM-Notizen';

  @override
  String get playGmNoteAdd => 'GM-Notiz hinzufügen';

  @override
  String get playGmNoteGlobal => 'Globale Notiz';

  @override
  String get playGmNoteDeleteMessage =>
      'Das Löschen dieser MG-Notiz entfernt sie aus jeder Szene. Das kann nicht rückgängig gemacht werden.';

  @override
  String get playNpcDeactivate => 'NSC deaktivieren';

  @override
  String get playVillains => 'Schurken (global)';

  @override
  String get sceneSectionKeyEvents => 'Schlüsselereignisse';

  @override
  String get sceneSectionImages => 'Bilder';

  @override
  String get sceneSectionAudio => 'Soundtracks';

  @override
  String get sceneSectionPaths => 'Pfade';

  @override
  String get sceneAddNotes => 'Notizen hinzufügen';

  @override
  String get sceneChooseSoundtrack => 'Soundtrack wählen';

  @override
  String get scenePickNpcTitle => 'NSCs auswählen';

  @override
  String get scenePickNotesTitle => 'Notizen auswählen';

  @override
  String get scenePickKeyEventsTitle => 'Schlüsselereignisse auswählen';

  @override
  String get scenePickImagesTitle => 'Bilder auswählen';

  @override
  String get scenePickSoundtrackTitle => 'Soundtrack auswählen';

  @override
  String get sceneSectionType => 'Szenentyp';

  @override
  String get sceneTypeStart => 'Startszene';

  @override
  String get sceneTypeStandard => 'Standardszene';

  @override
  String get sceneTypeRecurring => 'Wiederkehrende Szene';

  @override
  String get sceneTypeEnd => 'Endszene';

  @override
  String get sceneSectionNextScenes => 'Nächste Szenen';

  @override
  String get scenePickNextScenesTitle => 'Nächste Szenen auswählen';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => 'Schließen';

  @override
  String get playPauseSession => 'Sitzung pausieren';

  @override
  String get playAdHocScene => 'Ad-hoc-Szene';

  @override
  String get playPreviousScene => 'Vorherige Szene';

  @override
  String get playNextScene => 'Nächste Szene';

  @override
  String get playFinishAdventure => 'Abenteuer beenden';

  @override
  String get playSplitParty => 'Gruppe teilen';

  @override
  String get playSplitTitle => 'Gruppe teilen';

  @override
  String get playSplitAssignHint => 'Wähle die Spieler für die neue Gruppe:';

  @override
  String get playSplitConfirm => 'Teilen';

  @override
  String get playPipSwitchFocus => 'Fokus wechseln';

  @override
  String get playAdHocTitle => 'Ad-hoc-Szene';

  @override
  String get playAdHocNameLabel => 'Szenenname';

  @override
  String get playAdHocConfirm => 'Starten';

  @override
  String get playMergeHint => '→ zusammenführen';

  @override
  String get playJumpToScene => 'Zu Szene springen';

  @override
  String get playJumpTitle => 'Zu Szene springen';

  @override
  String get playEndTrack => 'Diese Gruppe beenden';

  @override
  String get playPauseConfirm => 'Fortschritt speichern und zum Hauptmenü?';

  @override
  String get sceneSectionBackground => 'Hintergrundbild';

  @override
  String get scenePickBackgroundTitle => 'Hintergrundbild auswählen';

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
