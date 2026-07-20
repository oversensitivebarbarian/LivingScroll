// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'Accueil';

  @override
  String get homeActiveSessions => 'Sessions actives';

  @override
  String get homeMore => 'Plus';

  @override
  String get homeCreateAdventure => 'Créer une nouvelle aventure';

  @override
  String get navCreate => 'Créer';

  @override
  String get navLibrary => 'Bibliothèque';

  @override
  String get libraryAdventures => 'Aventures';

  @override
  String get librarySaves => 'Sauvegardes';

  @override
  String get libraryProjects => 'Projets';

  @override
  String get libraryFinished => 'Terminées';

  @override
  String get libraryImport => 'Importer une aventure';

  @override
  String get libraryImportDone => 'Aventure importée';

  @override
  String get libraryImportDuplicate => 'Déjà dans la bibliothèque';

  @override
  String get libraryImportInvalid => 'Fichier d\'aventure invalide';

  @override
  String get libraryCopyAsProject => 'Copier comme projet';

  @override
  String get libraryAdventurePlay => 'Jouer';

  @override
  String get launchGroupNameLabel => 'Nom du groupe';

  @override
  String get launchPlayersLabel => 'Joueurs';

  @override
  String get launchAddPlayer => 'Ajouter un joueur';

  @override
  String get launchPlayerNameHint => 'Nom du joueur';

  @override
  String get launchRemovePlayer => 'Retirer le joueur';

  @override
  String get launchLastSceneLabel => 'Reprend à';

  @override
  String get launchDryRun => 'Mode préparation';

  @override
  String get launchImportProgress => 'Importer la progression';

  @override
  String get launchImportProgressEmpty =>
      'Aucune partie terminée dont importer la progression.';

  @override
  String get launchReplace => 'Remplacer';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'L’aventure $adventure pour le groupe $group est déjà commencée. La remplacer effacera toute la progression.';
  }

  @override
  String get libraryCopyDone => 'Copié dans les projets';

  @override
  String get libraryExportLatex => 'Exporter vers LaTeX';

  @override
  String get libraryExportLatexDone => 'Document LaTeX exporté';

  @override
  String get libraryExportLatexError =>
      'Impossible d\'exporter l\'aventure vers LaTeX';

  @override
  String get latexChapterScenes => 'Scènes';

  @override
  String get latexChapterNpcs => 'PNJ';

  @override
  String get latexChapterPaths => 'Chemins';

  @override
  String get latexNarration => 'Narration';

  @override
  String get latexNotes => 'Notes';

  @override
  String get latexImages => 'Images';

  @override
  String get latexNextScenes => 'Scènes suivantes';

  @override
  String get latexShortDescription => 'Description courte';

  @override
  String get latexBackstory => 'Histoire';

  @override
  String get latexVisibleWhen => 'Visible quand';

  @override
  String get latexStats => 'Stats';

  @override
  String get latexSceneTypeStart => 'scène d\'ouverture';

  @override
  String get latexSceneTypeStandard => 'scène standard';

  @override
  String get latexSceneTypeRecurring => 'scène récurrente';

  @override
  String get latexSceneTypeEnd => 'scène de fin';

  @override
  String latexPageReferenceTemplate(Object page) {
    return 'page $page';
  }

  @override
  String get librarySaveDeleteMessage =>
      'Supprimer cette sauvegarde effacera toute la progression de la partie en cours.';

  @override
  String get libraryFinishedDeleteMessage =>
      'Supprimer cette session terminée est définitif — elle ne pourra pas être récupérée.';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navMap => 'Carte';

  @override
  String get sceneMapAllPaths => 'Tous les chemins';

  @override
  String get sceneMapEmpty => 'Aucune scène à cartographier pour l\'instant.';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get settingsLanguageLabel => 'Langue';

  @override
  String get settingsLanguageSystemDefault => 'Par défaut du système';

  @override
  String get settingsDisplayModeLabel => 'Mode d\'affichage';

  @override
  String get settingsModeLight => 'Clair';

  @override
  String get settingsModeDark => 'Sombre';

  @override
  String get settingsModeAuto => 'Automatique';

  @override
  String get settingsSave => 'Enregistrer';

  @override
  String get settingsMusicLabel => 'Musique';

  @override
  String get settingsAutoplayLabel => 'Lecture automatique';

  @override
  String get settingsBuildSectionLabel => 'Compilation';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsBuildNumberLabel => 'Numéro de build';

  @override
  String get unsavedTitle => 'Modifications non enregistrées';

  @override
  String get unsavedMessage =>
      'Vous avez des modifications non enregistrées. Les enregistrer avant de quitter ?';

  @override
  String get unsavedAbandon => 'Abandonner';

  @override
  String get unsavedCancel => 'Annuler';

  @override
  String get librarySaveEdit => 'Modifier';

  @override
  String get createNewCoverLabel => 'Ajouter une couverture';

  @override
  String get createNewTitleLabel => 'Titre';

  @override
  String get createNewVersionLabel => 'Version';

  @override
  String get createNewSystemLabel => 'Système';

  @override
  String get createNewSystemHint => 'Sélectionner un système';

  @override
  String get createNewAuthorLabel => 'Auteur';

  @override
  String get createNewDescriptionLabel => 'Description';

  @override
  String get createNewLanguageLabel => 'Langue';

  @override
  String get createNewLanguageUnset => 'Non spécifié';

  @override
  String get createNewContentWarningsLabel => 'Avertissements de contenu';

  @override
  String get createNewLicenseLabel => 'Licence';

  @override
  String get createNewImport => 'Importer des données';

  @override
  String get createNewCreate => 'Créer';

  @override
  String get createNewImportInvalid =>
      'Le fichier sélectionné n\'est pas une aventure valide.';

  @override
  String get createNewImportSuccess => 'Contenu importé';

  @override
  String get importSelectTitle => 'Sélectionner les données à importer';

  @override
  String get importConfirm => 'Importer';

  @override
  String get importDone => 'Données importées';

  @override
  String get importNothing =>
      'Aucun élément à importer. Déjà existant ou incompatible avec le système';

  @override
  String get gameGmNotes => 'Notes du MJ';

  @override
  String get coverCropTitle => 'Recadrer la couverture';

  @override
  String get coverCropConfirm => 'Recadrer';

  @override
  String get coverCropCancel => 'Annuler';

  @override
  String get gameScenes => 'Scènes';

  @override
  String get gameNpcs => 'PNJ';

  @override
  String get gameNotes => 'Notes';

  @override
  String get gameKeyEvents => 'Événements clés';

  @override
  String get gameImages => 'Images';

  @override
  String get gameSoundtracks => 'Bandes-son';

  @override
  String get gamePaths => 'Chemins';

  @override
  String get gamePublish => 'Exporter';

  @override
  String get gameExportPart => 'Exporter des éléments';

  @override
  String get publishValidTitle => 'Exporté';

  @override
  String get publishValidMessage => 'L’aventure a été exportée avec succès.';

  @override
  String get publishElementsReady =>
      'Le fichier d’éléments est prêt à être téléchargé.';

  @override
  String get publishInvalidTitle => 'Publication impossible pour l’instant';

  @override
  String get publishDownloadLs => 'Télécharger le .ls';

  @override
  String get publishDownloadLse => 'Télécharger le .lse';

  @override
  String get libraryDuplicateTitle => 'Déjà dans la bibliothèque';

  @override
  String get libraryDuplicateMessage =>
      'Une aventure avec le même titre, version, système, auteur et langue est déjà dans votre bibliothèque. L\'écraser ?';

  @override
  String get libraryOverwrite => 'Écraser';

  @override
  String publishIssueAdventureField(String field) {
    return 'Le paramètre d’aventure « $field » est requis.';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'Le PNJ « $name » doit avoir un nom et les deux portraits.';
  }

  @override
  String get publishIssueNoteName => 'Une note n’a pas de nom ou de contenu.';

  @override
  String get publishIssueNoStartScene =>
      'Il doit y avoir au moins une scène de départ.';

  @override
  String get publishIssueNoEndScene =>
      'Il doit y avoir au moins une scène de fin.';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return 'La scène de fin « $name » ne doit pas avoir de scène suivante.';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'La scène « $name » doit avoir une scène suivante.';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'La scène « $name » doit avoir au moins une scène suivante toujours disponible.';
  }

  @override
  String get publishIssueNoPathToEnd =>
      'Aucun chemin de scènes toujours disponibles ne mène d’une scène de départ à une scène de fin.';

  @override
  String publishIssueBlindLoop(String name) {
    return 'La scène \"$name\" forme une boucle sans issue : une autre scène y revient après qu’elle a déjà été visitée. Définissez-la comme récurrente pour permettre d’y revenir.';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'Le chemin « $name » doit avoir une scène de départ.';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'Le chemin « $name » doit avoir une scène de fin.';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'Parmi les propres scènes du chemin « $name », aucun parcours de scènes toujours disponibles ne mène de sa scène de départ à sa scène de fin.';
  }

  @override
  String get gameAdventureSettings => 'Paramètres de l\'aventure';

  @override
  String get pathEditNameLabel => 'Nom du chemin';

  @override
  String get pathNameRequired =>
      'Ce chemin est utilisé par une scène, il doit donc avoir un nom';

  @override
  String get visibilityRulesTitle => 'Règles de visibilité';

  @override
  String get visibilityRulesAnd => 'Toutes remplies';

  @override
  String get visibilityRulesOr => 'Une suffit';

  @override
  String get visibilityRulesAlwaysVisible => 'Toujours visible';

  @override
  String get visibilityRulesNoEvents => 'Ajoutez d\'abord des événements clés';

  @override
  String get notesAddLabel => 'Ajouter une note';

  @override
  String get notesNameLabel => 'Nom de la note';

  @override
  String get notesContentLabel => 'Contenu';

  @override
  String get notesInsertImage => 'Insérer une image';

  @override
  String get notesImagePickTitle => 'Insérer une image';

  @override
  String get notesImagePickEmpty => 'Aucune image disponible';

  @override
  String get notesImagePickGroupImages => 'Images';

  @override
  String get notesImagePickGroupNpcs => 'PNJ';

  @override
  String get notesDeleteMessage => 'Supprimer cette note ?';

  @override
  String get notesDelete => 'Supprimer';

  @override
  String get notesNameNotUnique => 'Le titre de la note doit être unique';

  @override
  String get notesSearchHint => 'Rechercher des notes';

  @override
  String get notesSearchClear => 'Effacer la recherche';

  @override
  String get keyEventsNameLabel => 'Nom de l\'événement';

  @override
  String get keyEventsDeleteMessage =>
      'Supprimer cet événement ? Toutes les références à celui-ci seront supprimées.';

  @override
  String get keyEventsDelete => 'Supprimer';

  @override
  String get keyEventsNameNotUnique =>
      'Le nom de l\'événement doit être unique';

  @override
  String get keyEventsSearchHint => 'Rechercher des événements';

  @override
  String get keyEventsSearchClear => 'Effacer la recherche';

  @override
  String get soundtracksAddLabel => 'Ajouter une bande-son';

  @override
  String get soundtracksDeleteMessage => 'Supprimer cette bande-son ?';

  @override
  String get soundtracksDelete => 'Supprimer';

  @override
  String get soundtracksNameNotUnique =>
      'Une bande-son portant ce nom existe déjà';

  @override
  String get soundtracksSearchHint => 'Rechercher des bandes-son';

  @override
  String get soundtracksSearchClear => 'Effacer la recherche';

  @override
  String get imagesPickLabel => 'Choisir une image';

  @override
  String get imagesAddTooltip => 'Ajouter une image';

  @override
  String get imagesDeleteMessage => 'Supprimer cette image ?';

  @override
  String get imagesDelete => 'Supprimer';

  @override
  String get imagesAddButton => 'Ajouter';

  @override
  String get npcsNameLabel => 'Nom';

  @override
  String get npcsDescriptionLabel => 'Description';

  @override
  String get npcsBackstoryLabel => 'Histoire';

  @override
  String get npcsFullImageLabel => 'Image complète';

  @override
  String get npcsIconLabel => 'Icône';

  @override
  String get npcsCropFull => 'Recadrer l\'image complète';

  @override
  String get npcsCropIcon => 'Recadrer l\'icône';

  @override
  String get npcsClone => 'Cloner';

  @override
  String get npcsDelete => 'Supprimer';

  @override
  String get npcsDeleteMessage => 'Supprimer ce PNJ ?';

  @override
  String get npcsNameNotUnique => 'Un PNJ portant ce nom existe déjà';

  @override
  String get npcsSearchHint => 'Rechercher des PNJ';

  @override
  String get npcsSearchClear => 'Effacer la recherche';

  @override
  String get adventureClone => 'Cloner';

  @override
  String get adventureDelete => 'Supprimer';

  @override
  String get adventureDeleteMessage => 'Supprimer cette aventure ?';

  @override
  String get scenesAddLabel => 'Ajouter une scène';

  @override
  String get scenesSearchHint => 'Rechercher des scènes';

  @override
  String get scenesSearchClear => 'Effacer la recherche';

  @override
  String get scenesDeleteMessage => 'Supprimer cette scène ?';

  @override
  String get scenesDelete => 'Supprimer';

  @override
  String get scenesNameNotUnique => 'Une scène portant ce nom existe déjà';

  @override
  String get sceneNameLabel => 'Nom';

  @override
  String get sceneNarrationLabel => 'Narration';

  @override
  String get sceneSectionNpc => 'PNJ';

  @override
  String get sceneSectionNotes => 'Notes';

  @override
  String get playGmNotes => 'Notes MJ';

  @override
  String get playGmNoteAdd => 'Ajouter une note MJ';

  @override
  String get playGmNoteGlobal => 'Note globale';

  @override
  String get playGmNoteDeleteMessage =>
      'Supprimer cette note de MJ la retire de chaque scène. Cette action est irréversible.';

  @override
  String get playNpcDeactivate => 'Désactiver le PNJ';

  @override
  String get playVillains => 'Vilains (global)';

  @override
  String get sceneSectionKeyEvents => 'Événements clés';

  @override
  String get sceneSectionImages => 'Images';

  @override
  String get sceneSectionAudio => 'Bandes-son';

  @override
  String get sceneSectionPaths => 'Chemins';

  @override
  String get sceneAddNotes => 'Ajouter des notes';

  @override
  String get sceneChooseSoundtrack => 'Choisir une bande-son';

  @override
  String get scenePickNpcTitle => 'Sélectionner des PNJ';

  @override
  String get scenePickNotesTitle => 'Sélectionner des notes';

  @override
  String get scenePickKeyEventsTitle => 'Sélectionner des événements clés';

  @override
  String get scenePickImagesTitle => 'Sélectionner des images';

  @override
  String get scenePickSoundtrackTitle => 'Sélectionner une bande-son';

  @override
  String get sceneSectionType => 'Type de scène';

  @override
  String get sceneTypeStart => 'Scène de départ';

  @override
  String get sceneTypeStandard => 'Scène standard';

  @override
  String get sceneTypeRecurring => 'Scène récurrente';

  @override
  String get sceneTypeEnd => 'Scène finale';

  @override
  String get sceneSectionNextScenes => 'Scènes suivantes';

  @override
  String get scenePickNextScenesTitle => 'Sélectionner les scènes suivantes';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => 'Fermer';

  @override
  String get playPauseSession => 'Mettre en pause';

  @override
  String get playAdHocScene => 'Scène ad hoc';

  @override
  String get playPreviousScene => 'Scène précédente';

  @override
  String get playNextScene => 'Scène suivante';

  @override
  String get playFinishAdventure => 'Terminer l’aventure';

  @override
  String get playSplitParty => 'Diviser le groupe';

  @override
  String get playSplitTitle => 'Diviser le groupe';

  @override
  String get playSplitAssignHint =>
      'Choisissez les joueurs du nouveau groupe :';

  @override
  String get playSplitConfirm => 'Diviser';

  @override
  String get playPipSwitchFocus => 'Changer de focus';

  @override
  String get playAdHocTitle => 'Scène ad hoc';

  @override
  String get playAdHocNameLabel => 'Nom de la scène';

  @override
  String get playAdHocConfirm => 'Commencer';

  @override
  String get playMergeHint => '→ fusionner';

  @override
  String get playJumpToScene => 'Aller à une scène';

  @override
  String get playJumpTitle => 'Aller à une scène';

  @override
  String get playEndTrack => 'Terminer ce groupe';

  @override
  String get playPauseConfirm =>
      'Enregistrer la progression et aller au menu principal ?';

  @override
  String get sceneSectionBackground => 'Image d’arrière-plan';

  @override
  String get scenePickBackgroundTitle => 'Sélectionner l’image d’arrière-plan';

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
