// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => 'Início';

  @override
  String get homeActiveSessions => 'Sessões ativas';

  @override
  String get homeMore => 'Mais';

  @override
  String get homeCreateAdventure => 'Criar nova aventura';

  @override
  String get navCreate => 'Criar';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get libraryAdventures => 'Aventuras';

  @override
  String get librarySaves => 'Salvos';

  @override
  String get libraryProjects => 'Projetos';

  @override
  String get libraryFinished => 'Concluídas';

  @override
  String get libraryImport => 'Importar aventura';

  @override
  String get libraryImportDone => 'Aventura importada';

  @override
  String get libraryImportDuplicate => 'Já está na biblioteca';

  @override
  String get libraryImportInvalid => 'Arquivo de aventura inválido';

  @override
  String get libraryCopyAsProject => 'Copiar como projeto';

  @override
  String get libraryAdventurePlay => 'Jogar';

  @override
  String get launchGroupNameLabel => 'Nome do grupo';

  @override
  String get launchPlayersLabel => 'Jogadores';

  @override
  String get launchAddPlayer => 'Adicionar jogador';

  @override
  String get launchPlayerNameHint => 'Nome do jogador';

  @override
  String get launchRemovePlayer => 'Remover jogador';

  @override
  String get launchLastSceneLabel => 'Continua em';

  @override
  String get launchDryRun => 'Modo de preparação';

  @override
  String get launchImportProgress => 'Importar progresso';

  @override
  String get launchImportProgressEmpty =>
      'Não há jogos concluídos dos quais importar progresso.';

  @override
  String get launchReplace => 'Substituir';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return 'A aventura $adventure para o grupo $group já foi iniciada. Substituí-la apagará todo o progresso.';
  }

  @override
  String get libraryCopyDone => 'Copiado para projetos';

  @override
  String get libraryExportLatex => 'Exportar para LaTeX';

  @override
  String get libraryExportLatexDone => 'Documento LaTeX exportado';

  @override
  String get libraryExportLatexError =>
      'Não foi possível exportar a aventura para LaTeX';

  @override
  String get latexChapterScenes => 'Cenas';

  @override
  String get latexChapterNpcs => 'NPCs';

  @override
  String get latexChapterPaths => 'Caminhos';

  @override
  String get latexNarration => 'Narração';

  @override
  String get latexNotes => 'Notas';

  @override
  String get latexImages => 'Imagens';

  @override
  String get latexNextScenes => 'Próximas cenas';

  @override
  String get latexShortDescription => 'Descrição breve';

  @override
  String get latexBackstory => 'História';

  @override
  String get latexVisibleWhen => 'Visível quando';

  @override
  String get latexStats => 'Estatísticas';

  @override
  String get latexSceneTypeStart => 'cena inicial';

  @override
  String get latexSceneTypeStandard => 'cena padrão';

  @override
  String get latexSceneTypeRecurring => 'cena recorrente';

  @override
  String get latexSceneTypeEnd => 'cena final';

  @override
  String latexPageReferenceTemplate(Object page) {
    return 'página $page';
  }

  @override
  String get librarySaveDeleteMessage =>
      'Excluir este save apagará todo o progresso do jogo em andamento.';

  @override
  String get libraryFinishedDeleteMessage =>
      'Excluir esta sessão concluída é permanente — não poderá ser recuperada.';

  @override
  String get navSettings => 'Configurações';

  @override
  String get navMap => 'Mapa';

  @override
  String get sceneMapAllPaths => 'Todos os caminhos';

  @override
  String get sceneMapEmpty => 'Ainda não há cenas para o mapa.';

  @override
  String get menuTooltip => 'Menu';

  @override
  String get settingsLanguageLabel => 'Idioma';

  @override
  String get settingsLanguageSystemDefault => 'Padrão do sistema';

  @override
  String get settingsDisplayModeLabel => 'Modo de exibição';

  @override
  String get settingsModeLight => 'Claro';

  @override
  String get settingsModeDark => 'Escuro';

  @override
  String get settingsModeAuto => 'Automático';

  @override
  String get settingsSave => 'Salvar';

  @override
  String get settingsMusicLabel => 'Música';

  @override
  String get settingsAutoplayLabel => 'Reprodução automática';

  @override
  String get settingsBuildSectionLabel => 'Compilação';

  @override
  String get settingsVersionLabel => 'Versão';

  @override
  String get settingsBuildNumberLabel => 'Número de compilação';

  @override
  String get unsavedTitle => 'Alterações não salvas';

  @override
  String get unsavedMessage =>
      'Você tem alterações não salvas. Salvar antes de sair?';

  @override
  String get unsavedAbandon => 'Descartar';

  @override
  String get unsavedCancel => 'Cancelar';

  @override
  String get librarySaveEdit => 'Editar';

  @override
  String get createNewCoverLabel => 'Adicionar capa';

  @override
  String get createNewTitleLabel => 'Título';

  @override
  String get createNewVersionLabel => 'Versão';

  @override
  String get createNewSystemLabel => 'Sistema';

  @override
  String get createNewSystemHint => 'Selecionar um sistema';

  @override
  String get createNewAuthorLabel => 'Autor';

  @override
  String get createNewDescriptionLabel => 'Descrição';

  @override
  String get createNewLanguageLabel => 'Idioma';

  @override
  String get createNewLanguageUnset => 'Não especificado';

  @override
  String get createNewContentWarningsLabel => 'Avisos de conteúdo';

  @override
  String get createNewLicenseLabel => 'Licença';

  @override
  String get createNewImport => 'Importar dados';

  @override
  String get createNewCreate => 'Criar';

  @override
  String get createNewImportInvalid =>
      'O arquivo selecionado não é uma aventura válida.';

  @override
  String get createNewImportSuccess => 'Conteúdo importado';

  @override
  String get importSelectTitle => 'Selecionar dados para importar';

  @override
  String get importConfirm => 'Importar';

  @override
  String get importDone => 'Dados importados';

  @override
  String get importNothing =>
      'Nenhum elemento para importar. Já existe ou não é compatível com o sistema';

  @override
  String get gameGmNotes => 'Notas do mestre';

  @override
  String get coverCropTitle => 'Recortar capa';

  @override
  String get coverCropConfirm => 'Recortar';

  @override
  String get coverCropCancel => 'Cancelar';

  @override
  String get gameScenes => 'Cenas';

  @override
  String get gameNpcs => 'NPCs';

  @override
  String get gameNotes => 'Notas';

  @override
  String get gameKeyEvents => 'Eventos-chave';

  @override
  String get gameImages => 'Imagens';

  @override
  String get gameSoundtracks => 'Trilhas sonoras';

  @override
  String get gamePaths => 'Caminhos';

  @override
  String get gamePublish => 'Exportar';

  @override
  String get gameExportPart => 'Exportar elementos';

  @override
  String get publishValidTitle => 'Exportado';

  @override
  String get publishValidMessage => 'A aventura foi exportada com sucesso.';

  @override
  String get publishElementsReady =>
      'O arquivo de elementos está pronto para download.';

  @override
  String get publishInvalidTitle => 'Ainda não é possível publicar';

  @override
  String get publishDownloadLs => 'Baixar .ls';

  @override
  String get publishDownloadLse => 'Baixar .lse';

  @override
  String get libraryDuplicateTitle => 'Já está na biblioteca';

  @override
  String get libraryDuplicateMessage =>
      'Uma aventura com o mesmo título, versão, sistema, autor e idioma já está na sua biblioteca. Substituir?';

  @override
  String get libraryOverwrite => 'Substituir';

  @override
  String publishIssueAdventureField(String field) {
    return 'A configuração da aventura \"$field\" é obrigatória.';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'O NPC \"$name\" precisa de um nome e das duas imagens de retrato.';
  }

  @override
  String get publishIssueNoteName => 'Uma nota está sem nome ou sem conteúdo.';

  @override
  String get publishIssueNoStartScene =>
      'Deve haver pelo menos uma cena inicial.';

  @override
  String get publishIssueNoEndScene => 'Deve haver pelo menos uma cena final.';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return 'A cena final \"$name\" não pode ter uma cena seguinte.';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return 'A cena \"$name\" precisa de uma cena seguinte.';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return 'A cena \"$name\" precisa de pelo menos uma cena seguinte sempre disponível.';
  }

  @override
  String get publishIssueNoPathToEnd =>
      'Nenhum caminho de cenas sempre disponíveis leva de uma cena inicial a uma cena final.';

  @override
  String publishIssueBlindLoop(String name) {
    return 'A cena \"$name\" é um laço sem saída: outra cena retorna a ela depois de já ter sido visitada. Torne-a recorrente para permitir o retorno.';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return 'O caminho \"$name\" deve ter uma cena inicial.';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return 'O caminho \"$name\" deve ter uma cena final.';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return 'Dentro das próprias cenas do caminho \"$name\", nenhum caminho de cenas sempre disponíveis leva da sua cena inicial à sua cena final.';
  }

  @override
  String get gameAdventureSettings => 'Configurações da aventura';

  @override
  String get pathEditNameLabel => 'Nome do caminho';

  @override
  String get pathNameRequired =>
      'Este caminho é usado por uma cena, por isso precisa de um nome';

  @override
  String get visibilityRulesTitle => 'Regras de visibilidade';

  @override
  String get visibilityRulesAnd => 'Todas cumpridas';

  @override
  String get visibilityRulesOr => 'Qualquer cumprida';

  @override
  String get visibilityRulesAlwaysVisible => 'Sempre visível';

  @override
  String get visibilityRulesNoEvents => 'Adicione eventos-chave primeiro';

  @override
  String get notesAddLabel => 'Adicionar nota';

  @override
  String get notesNameLabel => 'Nome da nota';

  @override
  String get notesContentLabel => 'Conteúdo';

  @override
  String get notesInsertImage => 'Inserir imagem';

  @override
  String get notesImagePickTitle => 'Inserir imagem';

  @override
  String get notesImagePickEmpty => 'Nenhuma imagem disponível';

  @override
  String get notesImagePickGroupImages => 'Imagens';

  @override
  String get notesImagePickGroupNpcs => 'NPCs';

  @override
  String get notesDeleteMessage => 'Excluir esta nota?';

  @override
  String get notesDelete => 'Excluir';

  @override
  String get notesNameNotUnique => 'O título da nota deve ser único';

  @override
  String get notesSearchHint => 'Pesquisar notas';

  @override
  String get notesSearchClear => 'Limpar pesquisa';

  @override
  String get keyEventsNameLabel => 'Nome do evento';

  @override
  String get keyEventsDeleteMessage =>
      'Excluir este evento? Todas as referências a ele serão removidas.';

  @override
  String get keyEventsDelete => 'Excluir';

  @override
  String get keyEventsNameNotUnique => 'O nome do evento deve ser único';

  @override
  String get keyEventsSearchHint => 'Pesquisar eventos';

  @override
  String get keyEventsSearchClear => 'Limpar pesquisa';

  @override
  String get soundtracksAddLabel => 'Adicionar trilha sonora';

  @override
  String get soundtracksDeleteMessage => 'Excluir esta trilha sonora?';

  @override
  String get soundtracksDelete => 'Excluir';

  @override
  String get soundtracksNameNotUnique =>
      'Já existe uma trilha sonora com este nome';

  @override
  String get soundtracksSearchHint => 'Pesquisar trilhas sonoras';

  @override
  String get soundtracksSearchClear => 'Limpar pesquisa';

  @override
  String get imagesPickLabel => 'Escolher imagem';

  @override
  String get imagesAddTooltip => 'Adicionar imagem';

  @override
  String get imagesDeleteMessage => 'Excluir esta imagem?';

  @override
  String get imagesDelete => 'Excluir';

  @override
  String get imagesAddButton => 'Adicionar';

  @override
  String get npcsNameLabel => 'Nome';

  @override
  String get npcsDescriptionLabel => 'Descrição';

  @override
  String get npcsBackstoryLabel => 'História';

  @override
  String get npcsFullImageLabel => 'Imagem completa';

  @override
  String get npcsIconLabel => 'Ícone';

  @override
  String get npcsCropFull => 'Recortar imagem completa';

  @override
  String get npcsCropIcon => 'Recortar ícone';

  @override
  String get npcsClone => 'Clonar';

  @override
  String get npcsDelete => 'Excluir';

  @override
  String get npcsDeleteMessage => 'Excluir este NPC?';

  @override
  String get npcsNameNotUnique => 'Já existe um NPC com este nome';

  @override
  String get npcsSearchHint => 'Pesquisar NPCs';

  @override
  String get npcsSearchClear => 'Limpar pesquisa';

  @override
  String get adventureClone => 'Clonar';

  @override
  String get adventureDelete => 'Excluir';

  @override
  String get adventureDeleteMessage => 'Excluir esta aventura?';

  @override
  String get scenesAddLabel => 'Adicionar cena';

  @override
  String get scenesSearchHint => 'Pesquisar cenas';

  @override
  String get scenesSearchClear => 'Limpar pesquisa';

  @override
  String get scenesDeleteMessage => 'Excluir esta cena?';

  @override
  String get scenesDelete => 'Excluir';

  @override
  String get scenesNameNotUnique => 'Já existe uma cena com este nome';

  @override
  String get sceneNameLabel => 'Nome';

  @override
  String get sceneNarrationLabel => 'Narração';

  @override
  String get sceneSectionNpc => 'NPC';

  @override
  String get sceneSectionNotes => 'Notas';

  @override
  String get playGmNotes => 'Notas do GM';

  @override
  String get playGmNoteAdd => 'Adicionar nota do GM';

  @override
  String get playGmNoteGlobal => 'Nota global';

  @override
  String get playGmNoteDeleteMessage =>
      'Excluir esta nota do Mestre a remove de todas as cenas. Isso não pode ser desfeito.';

  @override
  String get playNpcDeactivate => 'Desativar NPC';

  @override
  String get playVillains => 'Vilões (global)';

  @override
  String get sceneSectionKeyEvents => 'Eventos-chave';

  @override
  String get sceneSectionImages => 'Imagens';

  @override
  String get sceneSectionAudio => 'Trilhas sonoras';

  @override
  String get sceneSectionPaths => 'Caminhos';

  @override
  String get sceneAddNotes => 'Adicionar notas';

  @override
  String get sceneChooseSoundtrack => 'Escolher trilha sonora';

  @override
  String get scenePickNpcTitle => 'Selecionar NPCs';

  @override
  String get scenePickNotesTitle => 'Selecionar notas';

  @override
  String get scenePickKeyEventsTitle => 'Selecionar eventos-chave';

  @override
  String get scenePickImagesTitle => 'Selecionar imagens';

  @override
  String get scenePickSoundtrackTitle => 'Selecionar trilha sonora';

  @override
  String get sceneSectionType => 'Tipo de cena';

  @override
  String get sceneTypeStart => 'Cena inicial';

  @override
  String get sceneTypeStandard => 'Cena padrão';

  @override
  String get sceneTypeRecurring => 'Cena recorrente';

  @override
  String get sceneTypeEnd => 'Cena final';

  @override
  String get sceneSectionNextScenes => 'Próximas cenas';

  @override
  String get scenePickNextScenesTitle => 'Selecionar próximas cenas';

  @override
  String get dialogOk => 'OK';

  @override
  String get dialogClose => 'Fechar';

  @override
  String get playPauseSession => 'Pausar sessão';

  @override
  String get playAdHocScene => 'Cena ad-hoc';

  @override
  String get playPreviousScene => 'Cena anterior';

  @override
  String get playNextScene => 'Próxima cena';

  @override
  String get playFinishAdventure => 'Concluir aventura';

  @override
  String get playSplitParty => 'Dividir o grupo';

  @override
  String get playSplitTitle => 'Dividir o grupo';

  @override
  String get playSplitAssignHint => 'Escolha os jogadores do novo grupo:';

  @override
  String get playSplitConfirm => 'Dividir';

  @override
  String get playPipSwitchFocus => 'Mudar o foco';

  @override
  String get playAdHocTitle => 'Cena ad hoc';

  @override
  String get playAdHocNameLabel => 'Nome da cena';

  @override
  String get playAdHocConfirm => 'Iniciar';

  @override
  String get playMergeHint => '→ juntar';

  @override
  String get playJumpToScene => 'Saltar para cena';

  @override
  String get playJumpTitle => 'Saltar para cena';

  @override
  String get playEndTrack => 'Encerrar este grupo';

  @override
  String get playPauseConfirm =>
      'Salvar o progresso e ir para o menu principal?';

  @override
  String get sceneSectionBackground => 'Imagem de fundo';

  @override
  String get scenePickBackgroundTitle => 'Selecionar imagem de fundo';

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
