// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'Inicio';

  @override
  String get homeActiveSessions => 'Sesiones activas';

  @override
  String get homeMore => 'Más';

  @override
  String get homeCreateAdventure => 'Crear nueva aventura';

  @override
  String get navCreate => 'Crear';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get libraryAdventures => 'Aventuras';

  @override
  String get librarySaves => 'Guardados';

  @override
  String get libraryProjects => 'Proyectos';

  @override
  String get libraryFinished => 'Terminadas';

  @override
  String get libraryImport => 'Importar aventura';

  @override
  String get libraryImportDone => 'Aventura importada';

  @override
  String get libraryImportDuplicate => 'Ya está en la biblioteca';

  @override
  String get libraryImportInvalid => 'Archivo de aventura no válido';

  @override
  String get libraryCopyAsProject => 'Copiar como proyecto';

  @override
  String get libraryAdventurePlay => 'Jugar';

  @override
  String get launchGroupNameLabel => 'Nombre del grupo';

  @override
  String get launchPlayersLabel => 'Jugadores';

  @override
  String get launchAddPlayer => 'Añadir jugador';

  @override
  String get launchPlayerNameHint => 'Nombre del jugador';

  @override
  String get launchRemovePlayer => 'Quitar jugador';

  @override
  String get launchLastSceneLabel => 'Continúa en';

  @override
  String get launchDryRun => 'Modo de preparación';

  @override
  String get launchImportProgress => 'Importar progreso';

  @override
  String get launchImportProgressEmpty =>
      'No hay partidas terminadas de las que importar progreso.';

  @override
  String get launchReplace => 'Reemplazar';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'La aventura $adventure para el grupo $group ya está iniciada. Reemplazarla perderá todo el progreso.';
  }

  @override
  String get libraryCopyDone => 'Copiado a proyectos';

  @override
  String get libraryExportLatex => 'Exportar a LaTeX';

  @override
  String get libraryExportLatexDone => 'Documento LaTeX exportado';

  @override
  String get libraryExportLatexError =>
      'No se pudo exportar la aventura a LaTeX';

  @override
  String get latexChapterScenes => 'Escenas';

  @override
  String get latexChapterNpcs => 'PNJ';

  @override
  String get latexChapterPaths => 'Rutas';

  @override
  String get latexNarration => 'Narración';

  @override
  String get latexNotes => 'Notas';

  @override
  String get latexImages => 'Imágenes';

  @override
  String get latexNextScenes => 'Escenas siguientes';

  @override
  String get latexShortDescription => 'Descripción breve';

  @override
  String get latexBackstory => 'Historia';

  @override
  String get latexVisibleWhen => 'Visible cuando';

  @override
  String get latexStats => 'Estadísticas';

  @override
  String get latexSceneTypeStart => 'escena inicial';

  @override
  String get latexSceneTypeStandard => 'escena estándar';

  @override
  String get latexSceneTypeRecurring => 'escena recurrente';

  @override
  String get latexSceneTypeEnd => 'escena final';

  @override
  String latexPageReferenceTemplate(Object page) {
    return 'página $page';
  }

  @override
  String get librarySaveDeleteMessage =>
      'Eliminar esta partida guardada perderá todo el progreso del juego en curso.';

  @override
  String get libraryFinishedDeleteMessage =>
      'Eliminar esta sesión finalizada es permanente — no se podrá recuperar.';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navMap => 'Mapa';

  @override
  String get sceneMapAllPaths => 'Todas las rutas';

  @override
  String get sceneMapEmpty => 'Aún no hay escenas para el mapa.';

  @override
  String get menuTooltip => 'Menú';

  @override
  String get settingsLanguageLabel => 'Idioma';

  @override
  String get settingsLanguageSystemDefault => 'Predeterminado del sistema';

  @override
  String get settingsDisplayModeLabel => 'Modo de visualización';

  @override
  String get settingsModeLight => 'Claro';

  @override
  String get settingsModeDark => 'Oscuro';

  @override
  String get settingsModeAuto => 'Automático';

  @override
  String get settingsSave => 'Guardar';

  @override
  String get settingsMusicLabel => 'Música';

  @override
  String get settingsAutoplayLabel => 'Reproducción automática';

  @override
  String get settingsBuildSectionLabel => 'Compilación';

  @override
  String get settingsVersionLabel => 'Versión';

  @override
  String get settingsBuildNumberLabel => 'Número de compilación';

  @override
  String get unsavedTitle => 'Cambios sin guardar';

  @override
  String get unsavedMessage =>
      'Tienes cambios sin guardar. ¿Guardarlos antes de salir?';

  @override
  String get unsavedAbandon => 'Descartar';

  @override
  String get unsavedCancel => 'Cancelar';

  @override
  String get librarySaveEdit => 'Editar';

  @override
  String get createNewCoverLabel => 'Añadir portada';

  @override
  String get createNewTitleLabel => 'Título';

  @override
  String get createNewVersionLabel => 'Versión';

  @override
  String get createNewSystemLabel => 'Sistema';

  @override
  String get createNewSystemHint => 'Seleccionar un sistema';

  @override
  String get createNewAuthorLabel => 'Autor';

  @override
  String get createNewDescriptionLabel => 'Descripción';

  @override
  String get createNewLanguageLabel => 'Idioma';

  @override
  String get createNewLanguageUnset => 'Sin especificar';

  @override
  String get createNewContentWarningsLabel => 'Advertencias de contenido';

  @override
  String get createNewLicenseLabel => 'Licencia';

  @override
  String get createNewImport => 'Importar datos';

  @override
  String get createNewCreate => 'Crear';

  @override
  String get createNewImportInvalid =>
      'El archivo seleccionado no es una aventura válida.';

  @override
  String get createNewImportSuccess => 'Contenido importado';

  @override
  String get importSelectTitle => 'Seleccionar datos para importar';

  @override
  String get importConfirm => 'Importar';

  @override
  String get importDone => 'Datos importados';

  @override
  String get importNothing =>
      'No hay elementos para importar. Ya existen o no son compatibles con el sistema';

  @override
  String get gameGmNotes => 'Notas del DJ';

  @override
  String get coverCropTitle => 'Recortar portada';

  @override
  String get coverCropConfirm => 'Recortar';

  @override
  String get coverCropCancel => 'Cancelar';

  @override
  String get gameScenes => 'Escenas';

  @override
  String get gameNpcs => 'PNJ';

  @override
  String get gameNotes => 'Notas';

  @override
  String get gameKeyEvents => 'Eventos clave';

  @override
  String get gameImages => 'Imágenes';

  @override
  String get gameSoundtracks => 'Bandas sonoras';

  @override
  String get gamePaths => 'Rutas';

  @override
  String get gamePublish => 'Exportar';

  @override
  String get gameExportPart => 'Exportar elementos';

  @override
  String get publishValidTitle => 'Exportado';

  @override
  String get publishValidMessage => 'La aventura se exportó correctamente.';

  @override
  String get publishElementsReady =>
      'El archivo de elementos está listo para descargar.';

  @override
  String get publishInvalidTitle => 'Aún no se puede publicar';

  @override
  String get publishDownloadLs => 'Descargar .ls';

  @override
  String get publishDownloadLse => 'Descargar .lse';

  @override
  String get libraryDuplicateTitle => 'Ya está en la biblioteca';

  @override
  String get libraryDuplicateMessage =>
      'Una aventura con el mismo título, versión, sistema, autor e idioma ya está en tu biblioteca. ¿Sobrescribir?';

  @override
  String get libraryOverwrite => 'Sobrescribir';

  @override
  String publishIssueAdventureField(String field) {
    return 'El ajuste de aventura \"$field\" es obligatorio.';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'El PNJ \"$name\" necesita un nombre y ambas imágenes de retrato.';
  }

  @override
  String get publishIssueNoteName =>
      'A una nota le falta el nombre o el contenido.';

  @override
  String get publishIssueNoStartScene =>
      'Debe haber al menos una escena inicial.';

  @override
  String get publishIssueNoEndScene => 'Debe haber al menos una escena final.';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return 'La escena final \"$name\" no debe tener una escena siguiente.';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'La escena \"$name\" debe tener una escena siguiente.';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'La escena \"$name\" debe tener al menos una escena siguiente siempre disponible.';
  }

  @override
  String get publishIssueNoPathToEnd =>
      'Ningún camino de escenas siempre disponibles lleva de una escena inicial a una final.';

  @override
  String publishIssueBlindLoop(String name) {
    return 'La escena \"$name\" es un bucle sin salida: otra escena vuelve a ella después de haber sido visitada. Conviértela en recurrente para permitir volver.';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'La ruta \"$name\" debe tener una escena inicial.';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'La ruta \"$name\" debe tener una escena final.';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'Dentro de las propias escenas de la ruta \"$name\", ningún camino de escenas siempre disponibles lleva de su escena inicial a su escena final.';
  }

  @override
  String get gameAdventureSettings => 'Ajustes de la aventura';

  @override
  String get pathEditNameLabel => 'Nombre de la ruta';

  @override
  String get pathNameRequired =>
      'Esta ruta la usa una escena, así que necesita un nombre';

  @override
  String get visibilityRulesTitle => 'Reglas de visibilidad';

  @override
  String get visibilityRulesAnd => 'Todas cumplidas';

  @override
  String get visibilityRulesOr => 'Cualquiera cumplida';

  @override
  String get visibilityRulesAlwaysVisible => 'Siempre visible';

  @override
  String get visibilityRulesNoEvents => 'Añade primero eventos clave';

  @override
  String get notesAddLabel => 'Añadir nota';

  @override
  String get notesNameLabel => 'Nombre de la nota';

  @override
  String get notesContentLabel => 'Contenido';

  @override
  String get notesInsertImage => 'Insertar imagen';

  @override
  String get notesImagePickTitle => 'Insertar imagen';

  @override
  String get notesImagePickEmpty => 'No hay imágenes disponibles';

  @override
  String get notesImagePickGroupImages => 'Imágenes';

  @override
  String get notesImagePickGroupNpcs => 'PNJs';

  @override
  String get notesDeleteMessage => '¿Eliminar esta nota?';

  @override
  String get notesDelete => 'Eliminar';

  @override
  String get notesNameNotUnique => 'El título de la nota debe ser único';

  @override
  String get notesSearchHint => 'Buscar notas';

  @override
  String get notesSearchClear => 'Borrar búsqueda';

  @override
  String get keyEventsNameLabel => 'Nombre del evento';

  @override
  String get keyEventsDeleteMessage =>
      '¿Eliminar este evento? Se eliminarán todas las referencias a él.';

  @override
  String get keyEventsDelete => 'Eliminar';

  @override
  String get keyEventsNameNotUnique => 'El nombre del evento debe ser único';

  @override
  String get keyEventsSearchHint => 'Buscar eventos';

  @override
  String get keyEventsSearchClear => 'Borrar búsqueda';

  @override
  String get soundtracksAddLabel => 'Añadir banda sonora';

  @override
  String get soundtracksDeleteMessage => '¿Eliminar esta banda sonora?';

  @override
  String get soundtracksDelete => 'Eliminar';

  @override
  String get soundtracksNameNotUnique =>
      'Ya existe una banda sonora con este nombre';

  @override
  String get soundtracksSearchHint => 'Buscar bandas sonoras';

  @override
  String get soundtracksSearchClear => 'Borrar búsqueda';

  @override
  String get imagesPickLabel => 'Elegir imagen';

  @override
  String get imagesAddTooltip => 'Añadir imagen';

  @override
  String get imagesDeleteMessage => '¿Eliminar esta imagen?';

  @override
  String get imagesDelete => 'Eliminar';

  @override
  String get imagesAddButton => 'Añadir';

  @override
  String get npcsNameLabel => 'Nombre';

  @override
  String get npcsDescriptionLabel => 'Descripción';

  @override
  String get npcsBackstoryLabel => 'Historia';

  @override
  String get npcsFullImageLabel => 'Imagen completa';

  @override
  String get npcsIconLabel => 'Icono';

  @override
  String get npcsCropFull => 'Recortar imagen completa';

  @override
  String get npcsCropIcon => 'Recortar icono';

  @override
  String get npcsClone => 'Clonar';

  @override
  String get npcsDelete => 'Eliminar';

  @override
  String get npcsDeleteMessage => '¿Eliminar este PNJ?';

  @override
  String get npcsNameNotUnique => 'Ya existe un PNJ con este nombre';

  @override
  String get npcsSearchHint => 'Buscar PNJ';

  @override
  String get npcsSearchClear => 'Borrar búsqueda';

  @override
  String get adventureClone => 'Clonar';

  @override
  String get adventureDelete => 'Eliminar';

  @override
  String get adventureDeleteMessage => '¿Eliminar esta aventura?';

  @override
  String get scenesAddLabel => 'Añadir escena';

  @override
  String get scenesSearchHint => 'Buscar escenas';

  @override
  String get scenesSearchClear => 'Borrar búsqueda';

  @override
  String get scenesDeleteMessage => '¿Eliminar esta escena?';

  @override
  String get scenesDelete => 'Eliminar';

  @override
  String get scenesNameNotUnique => 'Ya existe una escena con este nombre';

  @override
  String get sceneNameLabel => 'Nombre';

  @override
  String get sceneNarrationLabel => 'Narración';

  @override
  String get sceneSectionNpc => 'PNJ';

  @override
  String get sceneSectionNotes => 'Notas';

  @override
  String get playGmNotes => 'Notas del GM';

  @override
  String get playGmNoteAdd => 'Añadir nota del GM';

  @override
  String get playGmNoteGlobal => 'Nota global';

  @override
  String get playGmNoteDeleteMessage =>
      'Eliminar esta nota del DJ la quita de todas las escenas. Esto no se puede deshacer.';

  @override
  String get playNpcDeactivate => 'Desactivar PNJ';

  @override
  String get playVillains => 'Villanos (global)';

  @override
  String get sceneSectionKeyEvents => 'Eventos clave';

  @override
  String get sceneSectionImages => 'Imágenes';

  @override
  String get sceneSectionAudio => 'Bandas sonoras';

  @override
  String get sceneSectionPaths => 'Rutas';

  @override
  String get sceneAddNotes => 'Añadir notas';

  @override
  String get sceneChooseSoundtrack => 'Elegir banda sonora';

  @override
  String get scenePickNpcTitle => 'Seleccionar PNJ';

  @override
  String get scenePickNotesTitle => 'Seleccionar notas';

  @override
  String get scenePickKeyEventsTitle => 'Seleccionar eventos clave';

  @override
  String get scenePickImagesTitle => 'Seleccionar imágenes';

  @override
  String get scenePickSoundtrackTitle => 'Seleccionar banda sonora';

  @override
  String get sceneSectionType => 'Tipo de escena';

  @override
  String get sceneTypeStart => 'Escena inicial';

  @override
  String get sceneTypeStandard => 'Escena estándar';

  @override
  String get sceneTypeRecurring => 'Escena recurrente';

  @override
  String get sceneTypeEnd => 'Escena final';

  @override
  String get sceneSectionNextScenes => 'Escenas siguientes';

  @override
  String get scenePickNextScenesTitle => 'Seleccionar escenas siguientes';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => 'Cerrar';

  @override
  String get playPauseSession => 'Pausar sesión';

  @override
  String get playAdHocScene => 'Escena improvisada';

  @override
  String get playPreviousScene => 'Escena anterior';

  @override
  String get playNextScene => 'Escena siguiente';

  @override
  String get playFinishAdventure => 'Finalizar aventura';

  @override
  String get playSplitParty => 'Dividir el grupo';

  @override
  String get playSplitTitle => 'Dividir el grupo';

  @override
  String get playSplitAssignHint => 'Elige los jugadores del nuevo grupo:';

  @override
  String get playSplitConfirm => 'Dividir';

  @override
  String get playPipSwitchFocus => 'Cambiar el foco';

  @override
  String get playAdHocTitle => 'Escena improvisada';

  @override
  String get playAdHocNameLabel => 'Nombre de la escena';

  @override
  String get playAdHocConfirm => 'Comenzar';

  @override
  String get playMergeHint => '→ unir';

  @override
  String get playJumpToScene => 'Saltar a escena';

  @override
  String get playJumpTitle => 'Saltar a escena';

  @override
  String get playEndTrack => 'Terminar este grupo';

  @override
  String get playPauseConfirm => '¿Guardar el progreso e ir al menú principal?';

  @override
  String get sceneSectionBackground => 'Imagen de fondo';

  @override
  String get scenePickBackgroundTitle => 'Seleccionar imagen de fondo';

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
