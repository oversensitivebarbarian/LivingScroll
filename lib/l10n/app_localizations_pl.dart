// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'Start';

  @override
  String get homeActiveSessions => 'Aktywne sesje';

  @override
  String get homeMore => 'Więcej';

  @override
  String get homeCreateAdventure => 'Utwórz nową przygodę';

  @override
  String get navCreate => 'Utwórz';

  @override
  String get navLibrary => 'Biblioteka';

  @override
  String get libraryAdventures => 'Przygody';

  @override
  String get librarySaves => 'Zapisy';

  @override
  String get libraryProjects => 'Projekty';

  @override
  String get libraryFinished => 'Ukończone';

  @override
  String get libraryImport => 'Importuj przygodę';

  @override
  String get libraryImportDone => 'Zaimportowano przygodę';

  @override
  String get libraryImportDuplicate => 'Już w bibliotece';

  @override
  String get libraryImportInvalid => 'Nieprawidłowy plik przygody';

  @override
  String get libraryCopyAsProject => 'Kopiuj jako projekt';

  @override
  String get libraryAdventurePlay => 'Zagraj';

  @override
  String get launchGroupNameLabel => 'Nazwa grupy';

  @override
  String get launchPlayersLabel => 'Gracze';

  @override
  String get launchAddPlayer => 'Dodaj gracza';

  @override
  String get launchPlayerNameHint => 'Nazwa gracza';

  @override
  String get launchRemovePlayer => 'Usuń gracza';

  @override
  String get launchLastSceneLabel => 'Wznawia w';

  @override
  String get launchDryRun => 'Tryb przygotowania';

  @override
  String get launchImportProgress => 'Import postępu';

  @override
  String get launchImportProgressEmpty =>
      'Brak zakończonych gier, z których można zaimportować postęp.';

  @override
  String get launchReplace => 'Zastąp';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'Przygoda $adventure dla grupy $group jest już rozpoczęta. Jeśli ją zastąpisz, zostanie utracony cały postęp gry.';
  }

  @override
  String get libraryCopyDone => 'Skopiowano do projektów';

  @override
  String get libraryExportLatex => 'Eksportuj do LaTeX';

  @override
  String get libraryExportLatexDone => 'Wyeksportowano dokument LaTeX';

  @override
  String get libraryExportLatexError =>
      'Nie udało się wyeksportować przygody do LaTeX';

  @override
  String get latexChapterScenes => 'Sceny';

  @override
  String get latexChapterNpcs => 'Bohaterowie niezależni';

  @override
  String get latexChapterPaths => 'Ścieżki';

  @override
  String get latexNarration => 'Narracja';

  @override
  String get latexNotes => 'Notatki';

  @override
  String get latexImages => 'Obrazy';

  @override
  String get latexNextScenes => 'Kolejne sceny';

  @override
  String get latexShortDescription => 'Krótki opis';

  @override
  String get latexBackstory => 'Historia';

  @override
  String get latexVisibleWhen => 'Widoczne gdy';

  @override
  String get latexStats => 'Statystyki';

  @override
  String get latexSceneTypeStart => 'scena początkowa';

  @override
  String get latexSceneTypeStandard => 'scena zwykła';

  @override
  String get latexSceneTypeRecurring => 'scena powtarzająca się';

  @override
  String get latexSceneTypeEnd => 'scena końcowa';

  @override
  String latexPageReferenceTemplate(Object page) {
    return 'strona $page';
  }

  @override
  String get librarySaveDeleteMessage =>
      'Usunięcie tego zapisu spowoduje utratę całego postępu trwającej rozgrywki.';

  @override
  String get libraryFinishedDeleteMessage =>
      'Usunięcie tej zakończonej sesji jest bezpowrotne — nie będzie można jej odzyskać.';

  @override
  String get navSettings => 'Ustawienia';

  @override
  String get navMap => 'Mapa';

  @override
  String get sceneMapAllPaths => 'Wszystkie ścieżki';

  @override
  String get sceneMapEmpty => 'Brak scen do pokazania na mapie.';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get settingsLanguageLabel => 'Język';

  @override
  String get settingsLanguageSystemDefault => 'Domyślny systemowy';

  @override
  String get settingsDisplayModeLabel => 'Tryb wyświetlania';

  @override
  String get settingsModeLight => 'Jasny';

  @override
  String get settingsModeDark => 'Ciemny';

  @override
  String get settingsModeAuto => 'Automatyczny';

  @override
  String get settingsSave => 'Zapisz';

  @override
  String get settingsMusicLabel => 'Muzyka';

  @override
  String get settingsAutoplayLabel => 'Autoodtwarzanie';

  @override
  String get settingsBuildSectionLabel => 'Kompilacja';

  @override
  String get settingsVersionLabel => 'Wersja';

  @override
  String get settingsBuildNumberLabel => 'Numer kompilacji';

  @override
  String get unsavedTitle => 'Niezapisane zmiany';

  @override
  String get unsavedMessage =>
      'Masz niezapisane zmiany. Zapisać je przed wyjściem?';

  @override
  String get unsavedAbandon => 'Porzuć';

  @override
  String get unsavedCancel => 'Anuluj';

  @override
  String get librarySaveEdit => 'Edytuj';

  @override
  String get createNewCoverLabel => 'Dodaj okładkę';

  @override
  String get createNewTitleLabel => 'Tytuł';

  @override
  String get createNewVersionLabel => 'Wersja';

  @override
  String get createNewSystemLabel => 'System';

  @override
  String get createNewSystemHint => 'Wybierz system';

  @override
  String get createNewAuthorLabel => 'Autor';

  @override
  String get createNewDescriptionLabel => 'Opis';

  @override
  String get createNewLanguageLabel => 'Język';

  @override
  String get createNewLanguageUnset => 'Nie określono';

  @override
  String get createNewContentWarningsLabel => 'Ostrzeżenia o treści';

  @override
  String get createNewLicenseLabel => 'Licencja';

  @override
  String get createNewImport => 'Importuj dane';

  @override
  String get createNewCreate => 'Utwórz';

  @override
  String get createNewImportInvalid =>
      'Wybrany plik nie jest prawidłową przygodą.';

  @override
  String get createNewImportSuccess => 'Zaimportowano zawartość';

  @override
  String get importSelectTitle => 'Wybierz dane do importu';

  @override
  String get importConfirm => 'Importuj';

  @override
  String get importDone => 'Zaimportowano dane';

  @override
  String get importNothing =>
      'Brak elementów do zaimportowania. Już istnieją lub są niezgodne z systemem';

  @override
  String get gameGmNotes => 'Notatki MG';

  @override
  String get coverCropTitle => 'Przytnij okładkę';

  @override
  String get coverCropConfirm => 'Przytnij';

  @override
  String get coverCropCancel => 'Anuluj';

  @override
  String get gameScenes => 'Sceny';

  @override
  String get gameNpcs => 'NPC';

  @override
  String get gameNotes => 'Notatki';

  @override
  String get gameKeyEvents => 'Kluczowe wydarzenia';

  @override
  String get gameImages => 'Obrazy';

  @override
  String get gameSoundtracks => 'Ścieżki dźwiękowe';

  @override
  String get gamePaths => 'Ścieżki';

  @override
  String get gamePublish => 'Eksportuj';

  @override
  String get gameExportPart => 'Eksportuj elementy';

  @override
  String get publishValidTitle => 'Wyeksportowano';

  @override
  String get publishValidMessage =>
      'Przygoda została pomyślnie wyeksportowana.';

  @override
  String get publishElementsReady => 'Plik elements gotowy do pobrania.';

  @override
  String get publishInvalidTitle => 'Nie można jeszcze opublikować';

  @override
  String get publishDownloadLs => 'Pobierz plik .ls';

  @override
  String get publishDownloadLse => 'Pobierz plik .lse';

  @override
  String get libraryDuplicateTitle => 'Już w bibliotece';

  @override
  String get libraryDuplicateMessage =>
      'Przygoda o tym samym tytule, wersji, systemie, autorze i języku jest już w bibliotece. Nadpisać?';

  @override
  String get libraryOverwrite => 'Nadpisz';

  @override
  String publishIssueAdventureField(String field) {
    return 'Ustawienie przygody \"$field\" jest wymagane.';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'NPC \"$name\" musi mieć nazwę i oba obrazy postaci.';
  }

  @override
  String get publishIssueNoteName => 'Notatka nie ma nazwy lub treści.';

  @override
  String get publishIssueNoStartScene =>
      'Musi istnieć co najmniej jedna scena startowa.';

  @override
  String get publishIssueNoEndScene =>
      'Musi istnieć co najmniej jedna scena końcowa.';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return 'Scena końcowa \"$name\" nie może mieć następnej sceny.';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'Scena \"$name\" musi mieć następną scenę.';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'Scena \"$name\" musi mieć co najmniej jedną zawsze dostępną następną scenę.';
  }

  @override
  String get publishIssueNoPathToEnd =>
      'Żadna ścieżka zawsze dostępnych scen nie prowadzi od sceny startowej do końcowej.';

  @override
  String publishIssueBlindLoop(String name) {
    return 'Scena \"$name\" tworzy ślepą pętlę: inna scena wraca do niej po tym, jak została już odwiedzona. Ustaw ją jako powracającą (recurring), aby umożliwić powrót.';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'Ścieżka \"$name\" musi mieć scenę startową.';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'Ścieżka \"$name\" musi mieć scenę końcową.';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'Wśród własnych scen ścieżki \"$name\" nie ma trasy zawsze dostępnych scen prowadzącej od jej sceny startowej do końcowej.';
  }

  @override
  String get gameAdventureSettings => 'Ustawienia przygody';

  @override
  String get pathEditNameLabel => 'Nazwa ścieżki';

  @override
  String get pathNameRequired =>
      'Ta ścieżka jest używana przez scenę, więc musi mieć nazwę';

  @override
  String get visibilityRulesTitle => 'Reguły widoczności';

  @override
  String get visibilityRulesAnd => 'Wszystkie spełnione';

  @override
  String get visibilityRulesOr => 'Dowolne spełnione';

  @override
  String get visibilityRulesAlwaysVisible => 'Zawsze widoczne';

  @override
  String get visibilityRulesNoEvents => 'Najpierw dodaj kluczowe wydarzenia';

  @override
  String get notesAddLabel => 'Dodaj notatkę';

  @override
  String get notesNameLabel => 'Nazwa notatki';

  @override
  String get notesContentLabel => 'Treść';

  @override
  String get notesInsertImage => 'Wstaw obraz';

  @override
  String get notesImagePickTitle => 'Wstaw obraz';

  @override
  String get notesImagePickEmpty => 'Brak dostępnych obrazów';

  @override
  String get notesImagePickGroupImages => 'Obrazy';

  @override
  String get notesImagePickGroupNpcs => 'NPC';

  @override
  String get notesDeleteMessage => 'Usunąć tę notatkę?';

  @override
  String get notesDelete => 'Usuń';

  @override
  String get notesNameNotUnique => 'Tytuł notatki musi być unikalny';

  @override
  String get notesSearchHint => 'Szukaj notatek';

  @override
  String get notesSearchClear => 'Wyczyść wyszukiwanie';

  @override
  String get keyEventsNameLabel => 'Nazwa wydarzenia';

  @override
  String get keyEventsDeleteMessage =>
      'Usunąć to wydarzenie? Wszystkie odwołania do niego zostaną usunięte.';

  @override
  String get keyEventsDelete => 'Usuń';

  @override
  String get keyEventsNameNotUnique => 'Nazwa wydarzenia musi być unikalna';

  @override
  String get keyEventsSearchHint => 'Szukaj wydarzeń';

  @override
  String get keyEventsSearchClear => 'Wyczyść wyszukiwanie';

  @override
  String get soundtracksAddLabel => 'Dodaj ścieżkę dźwiękową';

  @override
  String get soundtracksDeleteMessage => 'Usunąć tę ścieżkę dźwiękową?';

  @override
  String get soundtracksDelete => 'Usuń';

  @override
  String get soundtracksNameNotUnique =>
      'Ścieżka dźwiękowa o tej nazwie już istnieje';

  @override
  String get soundtracksSearchHint => 'Szukaj ścieżek dźwiękowych';

  @override
  String get soundtracksSearchClear => 'Wyczyść wyszukiwanie';

  @override
  String get imagesPickLabel => 'Wybierz obraz';

  @override
  String get imagesAddTooltip => 'Dodaj obraz';

  @override
  String get imagesDeleteMessage => 'Usunąć ten obraz?';

  @override
  String get imagesDelete => 'Usuń';

  @override
  String get imagesAddButton => 'Dodaj';

  @override
  String get npcsNameLabel => 'Nazwa';

  @override
  String get npcsDescriptionLabel => 'Opis';

  @override
  String get npcsBackstoryLabel => 'Historia';

  @override
  String get npcsFullImageLabel => 'Pełny obraz';

  @override
  String get npcsIconLabel => 'Ikona';

  @override
  String get npcsCropFull => 'Przytnij pełny obraz';

  @override
  String get npcsCropIcon => 'Przytnij ikonę';

  @override
  String get npcsClone => 'Klonuj';

  @override
  String get npcsDelete => 'Usuń';

  @override
  String get npcsDeleteMessage => 'Usunąć tego NPC?';

  @override
  String get npcsNameNotUnique => 'NPC o tej nazwie już istnieje';

  @override
  String get npcsSearchHint => 'Szukaj NPC';

  @override
  String get npcsSearchClear => 'Wyczyść wyszukiwanie';

  @override
  String get adventureClone => 'Klonuj';

  @override
  String get adventureDelete => 'Usuń';

  @override
  String get adventureDeleteMessage => 'Usunąć tę przygodę?';

  @override
  String get scenesAddLabel => 'Dodaj scenę';

  @override
  String get scenesSearchHint => 'Szukaj scen';

  @override
  String get scenesSearchClear => 'Wyczyść wyszukiwanie';

  @override
  String get scenesDeleteMessage => 'Usunąć tę scenę?';

  @override
  String get scenesDelete => 'Usuń';

  @override
  String get scenesNameNotUnique => 'Scena o tej nazwie już istnieje';

  @override
  String get sceneNameLabel => 'Nazwa';

  @override
  String get sceneNarrationLabel => 'Narracja';

  @override
  String get sceneSectionNpc => 'NPC';

  @override
  String get sceneSectionNotes => 'Notatki';

  @override
  String get playGmNotes => 'Notatki MG';

  @override
  String get playGmNoteAdd => 'Dodaj notatkę MG';

  @override
  String get playGmNoteGlobal => 'Notatka globalna';

  @override
  String get playGmNoteDeleteMessage =>
      'Usunięcie tej notatki MG usuwa ją ze wszystkich scen. Tej operacji nie można cofnąć.';

  @override
  String get playNpcDeactivate => 'Dezaktywuj NPC';

  @override
  String get playVillains => 'Złoczyńcy (wszyscy)';

  @override
  String get sceneSectionKeyEvents => 'Kluczowe wydarzenia';

  @override
  String get sceneSectionImages => 'Obrazy';

  @override
  String get sceneSectionAudio => 'Ścieżki dźwiękowe';

  @override
  String get sceneSectionPaths => 'Ścieżki';

  @override
  String get sceneAddNotes => 'Dodaj notatki';

  @override
  String get sceneChooseSoundtrack => 'Wybierz ścieżkę dźwiękową';

  @override
  String get scenePickNpcTitle => 'Wybierz NPC';

  @override
  String get scenePickNotesTitle => 'Wybierz notatki';

  @override
  String get scenePickKeyEventsTitle => 'Wybierz kluczowe wydarzenia';

  @override
  String get scenePickImagesTitle => 'Wybierz obrazy';

  @override
  String get scenePickSoundtrackTitle => 'Wybierz ścieżkę dźwiękową';

  @override
  String get sceneSectionType => 'Typ sceny';

  @override
  String get sceneTypeStart => 'Scena początkowa';

  @override
  String get sceneTypeStandard => 'Scena standardowa';

  @override
  String get sceneTypeRecurring => 'Scena powracająca';

  @override
  String get sceneTypeEnd => 'Scena końcowa';

  @override
  String get sceneSectionNextScenes => 'Następne sceny';

  @override
  String get scenePickNextScenesTitle => 'Wybierz następne sceny';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => 'Zamknij';

  @override
  String get playPauseSession => 'Wstrzymaj sesję';

  @override
  String get playAdHocScene => 'Scena ad-hoc';

  @override
  String get playPreviousScene => 'Poprzednia scena';

  @override
  String get playNextScene => 'Następna scena';

  @override
  String get playFinishAdventure => 'Zakończ przygodę';

  @override
  String get playSplitParty => 'Rozdziel drużynę';

  @override
  String get playSplitTitle => 'Rozdziel drużynę';

  @override
  String get playSplitAssignHint =>
      'Wybierz graczy, którzy przechodzą na nowy tor:';

  @override
  String get playSplitConfirm => 'Rozdziel';

  @override
  String get playPipSwitchFocus => 'Przełącz fokus';

  @override
  String get playAdHocTitle => 'Scena ad-hoc';

  @override
  String get playAdHocNameLabel => 'Nazwa sceny';

  @override
  String get playAdHocConfirm => 'Rozpocznij';

  @override
  String get playMergeHint => '→ zbieg';

  @override
  String get playJumpToScene => 'Skocz do sceny';

  @override
  String get playJumpTitle => 'Skocz do sceny';

  @override
  String get playEndTrack => 'Zakończ tę grupę';

  @override
  String get playPauseConfirm => 'Zapisać postęp i przejść do menu głównego?';

  @override
  String get sceneSectionBackground => 'Obraz tła';

  @override
  String get scenePickBackgroundTitle => 'Wybierz obraz tła';

  @override
  String get npcSeaPageKind => 'Typ BN';

  @override
  String get npcSeaPageDetails => 'Szczegóły';

  @override
  String get npcSeaNext => 'Dalej';

  @override
  String get npcSeaBack => 'Wstecz';

  @override
  String get npcSeaKindLabel => 'Typ BN';

  @override
  String get npcSeaKindVillain => 'Złoczyńca';

  @override
  String get npcSeaKindBrute => 'Łotry, Potwory, Sojusznicy';

  @override
  String get npcSeaKindMonster => 'Postać fabularna';

  @override
  String get npcSeaComputed => 'obliczane';

  @override
  String get statSeaStrength => 'Siła';

  @override
  String get statSeaInfluence => 'Wpływy';

  @override
  String get statSeaVillainyRank => 'Ranga Nikczemności';

  @override
  String get statSeaAdvantages => 'Atuty';

  @override
  String get statSeaSchemes => 'Intrygi';

  @override
  String get npcSeaSchemeNew => 'Nowa intryga';

  @override
  String get npcSeaSchemeName => 'Nazwa intrygi';

  @override
  String get npcSeaSchemeCost => 'Koszt';

  @override
  String get npcSeaSchemeAdd => 'Dodaj';

  @override
  String get npcSeaSchemeEditTitle => 'Edytuj intrygę';

  @override
  String get npcSeaSchemeAvailable => 'Dostępny wpływ';

  @override
  String get npcSeaCostsTitle => 'Koszty';

  @override
  String get npcSeaSchemeBuy => 'Kup';

  @override
  String get npcSeaCostDescription => 'Opis';

  @override
  String get npcSeaTileStrength => 'Siła';

  @override
  String get npcSeaTileInfluence => 'Wpływ';

  @override
  String get npcSeaTileRank => 'Ranga';
}
