// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Living Scroll - Weave every thread';

  @override
  String get navHome => '主页';

  @override
  String get homeActiveSessions => '进行中的会话';

  @override
  String get homeMore => '更多';

  @override
  String get homeCreateAdventure => '创建新冒险';

  @override
  String get navCreate => '创建';

  @override
  String get navLibrary => '书库';

  @override
  String get libraryAdventures => '冒险';

  @override
  String get librarySaves => '存档';

  @override
  String get libraryProjects => '项目';

  @override
  String get libraryFinished => '已完成';

  @override
  String get libraryImport => '导入冒险';

  @override
  String get libraryImportDone => '冒险已导入';

  @override
  String get libraryImportDuplicate => '已在书库中';

  @override
  String get libraryImportInvalid => '不是有效的冒险文件';

  @override
  String get libraryCopyAsProject => '复制为项目';

  @override
  String get libraryAdventurePlay => '开始游戏';

  @override
  String get launchGroupNameLabel => '团队名称';

  @override
  String get launchPlayersLabel => '玩家';

  @override
  String get launchAddPlayer => '添加玩家';

  @override
  String get launchPlayerNameHint => '玩家名称';

  @override
  String get launchRemovePlayer => '移除玩家';

  @override
  String get launchLastSceneLabel => '继续于';

  @override
  String get launchDryRun => '准备模式';

  @override
  String get launchImportProgress => '导入进度';

  @override
  String get launchImportProgressEmpty => '没有可导入进度的已完成游戏。';

  @override
  String get launchReplace => '替换';

  @override
  String launchSaveExistsMessage(String adventure, String group) {
    return '团队 $group 的冒险 $adventure 已经开始。替换它将丢失所有游戏进度。';
  }

  @override
  String get libraryCopyDone => '已复制到项目';

  @override
  String get libraryExportLatex => '导出为 LaTeX';

  @override
  String get libraryExportLatexDone => '已导出 LaTeX 文档';

  @override
  String get libraryExportLatexError => '无法将冒险导出为 LaTeX';

  @override
  String get latexChapterScenes => '场景';

  @override
  String get latexChapterNpcs => 'NPC';

  @override
  String get latexChapterPaths => '路径';

  @override
  String get latexNarration => '叙述';

  @override
  String get latexNotes => '笔记';

  @override
  String get latexImages => '图片';

  @override
  String get latexNextScenes => '后续场景';

  @override
  String get latexShortDescription => '简短描述';

  @override
  String get latexBackstory => '背景故事';

  @override
  String get latexVisibleWhen => '可见条件';

  @override
  String get latexStats => '属性';

  @override
  String get latexSceneTypeStart => '起始场景';

  @override
  String get latexSceneTypeStandard => '标准场景';

  @override
  String get latexSceneTypeRecurring => '循环场景';

  @override
  String get latexSceneTypeEnd => '结束场景';

  @override
  String latexPageReferenceTemplate(Object page) {
    return '第$page页';
  }

  @override
  String get librarySaveDeleteMessage => '删除此存档将丢失正在进行的游戏的所有进度。';

  @override
  String get libraryFinishedDeleteMessage => '删除此已结束的会话是永久性的，无法恢复。';

  @override
  String get navSettings => '设置';

  @override
  String get navMap => '地图';

  @override
  String get sceneMapAllPaths => '所有路径';

  @override
  String get sceneMapEmpty => '暂无可显示在地图上的场景。';

  @override
  String get menuTooltip => '菜单';

  @override
  String get settingsLanguageLabel => '语言';

  @override
  String get settingsLanguageSystemDefault => '系统默认';

  @override
  String get settingsDisplayModeLabel => '显示模式';

  @override
  String get settingsModeLight => '浅色';

  @override
  String get settingsModeDark => '深色';

  @override
  String get settingsModeAuto => '自动';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsMusicLabel => '音乐';

  @override
  String get settingsAutoplayLabel => '自动播放';

  @override
  String get settingsBuildSectionLabel => '构建';

  @override
  String get settingsVersionLabel => '版本';

  @override
  String get settingsBuildNumberLabel => '构建编号';

  @override
  String get unsavedTitle => '未保存的更改';

  @override
  String get unsavedMessage => '您有未保存的更改。离开前要保存吗？';

  @override
  String get unsavedAbandon => '放弃';

  @override
  String get unsavedCancel => '取消';

  @override
  String get librarySaveEdit => '编辑';

  @override
  String get createNewCoverLabel => '添加封面';

  @override
  String get createNewTitleLabel => '标题';

  @override
  String get createNewVersionLabel => '版本';

  @override
  String get createNewSystemLabel => '系统';

  @override
  String get createNewSystemHint => '选择系统';

  @override
  String get createNewAuthorLabel => '作者';

  @override
  String get createNewDescriptionLabel => '描述';

  @override
  String get createNewLanguageLabel => '语言';

  @override
  String get createNewLanguageUnset => '未指定';

  @override
  String get createNewContentWarningsLabel => '内容警告';

  @override
  String get createNewLicenseLabel => '许可证';

  @override
  String get createNewImport => '导入数据';

  @override
  String get createNewCreate => '创建';

  @override
  String get createNewImportInvalid => '所选文件不是有效的冒险。';

  @override
  String get createNewImportSuccess => '已导入内容';

  @override
  String get importSelectTitle => '选择要导入的数据';

  @override
  String get importConfirm => '导入';

  @override
  String get importDone => '数据已导入';

  @override
  String get importNothing => '没有可导入的元素。已存在或与系统不兼容';

  @override
  String get gameGmNotes => 'GM 笔记';

  @override
  String get coverCropTitle => '裁剪封面';

  @override
  String get coverCropConfirm => '裁剪';

  @override
  String get coverCropCancel => '取消';

  @override
  String get gameScenes => '场景';

  @override
  String get gameNpcs => 'NPC';

  @override
  String get gameNotes => '笔记';

  @override
  String get gameKeyEvents => '关键事件';

  @override
  String get gameImages => '图片';

  @override
  String get gameSoundtracks => '配乐';

  @override
  String get gamePaths => '路径';

  @override
  String get gamePublish => '导出';

  @override
  String get gameExportPart => '导出元素';

  @override
  String get publishValidTitle => '已导出';

  @override
  String get publishValidMessage => '冒险已成功导出。';

  @override
  String get publishElementsReady => '元素文件已可下载。';

  @override
  String get publishInvalidTitle => '尚无法发布';

  @override
  String get publishDownloadLs => '下载 .ls';

  @override
  String get publishDownloadLse => '下载 .lse';

  @override
  String get libraryDuplicateTitle => '已在书库中';

  @override
  String get libraryDuplicateMessage => '书库中已存在标题、版本、系统、作者和语言相同的冒险。是否覆盖？';

  @override
  String get libraryOverwrite => '覆盖';

  @override
  String publishIssueAdventureField(String field) {
    return '冒险设置“$field”为必填项。';
  }

  @override
  String publishIssueNpcIncomplete(String name) {
    return 'NPC“$name”需要名称和两张肖像图片。';
  }

  @override
  String get publishIssueNoteName => '某条笔记缺少名称或内容。';

  @override
  String get publishIssueNoStartScene => '必须至少有一个起始场景。';

  @override
  String get publishIssueNoEndScene => '必须至少有一个结束场景。';

  @override
  String publishIssueEndSceneHasNext(String name) {
    return '结束场景“$name”不能有下一个场景。';
  }

  @override
  String publishIssueSceneNoNext(String name) {
    return '场景“$name”必须有下一个场景。';
  }

  @override
  String publishIssueSceneOnlyConditionalNext(String name) {
    return '场景“$name”必须至少有一个始终可用的下一个场景。';
  }

  @override
  String get publishIssueNoPathToEnd => '没有一条始终可用的场景路径能从起始场景通向结束场景。';

  @override
  String publishIssueBlindLoop(String name) {
    return '场景\"$name\"是死循环：另一个场景在其已被访问后又返回到它。请将其设为重复（recurring）场景以允许返回。';
  }

  @override
  String publishIssuePathNoStartScene(String name) {
    return '路径“$name”必须有一个起始场景。';
  }

  @override
  String publishIssuePathNoEndScene(String name) {
    return '路径“$name”必须有一个结束场景。';
  }

  @override
  String publishIssuePathNoRouteToEnd(String name) {
    return '在路径“$name”自身的场景中，没有一条始终可用场景组成的路线能从其起始场景通向其结束场景。';
  }

  @override
  String get gameAdventureSettings => '冒险设置';

  @override
  String get pathEditNameLabel => '路径名称';

  @override
  String get pathNameRequired => '该路径已被某个场景使用，因此必须填写名称';

  @override
  String get visibilityRulesTitle => '可见性规则';

  @override
  String get visibilityRulesAnd => '全部满足';

  @override
  String get visibilityRulesOr => '任一满足';

  @override
  String get visibilityRulesAlwaysVisible => '始终可见';

  @override
  String get visibilityRulesNoEvents => '请先添加关键事件';

  @override
  String get notesAddLabel => '添加笔记';

  @override
  String get notesNameLabel => '笔记名称';

  @override
  String get notesContentLabel => '内容';

  @override
  String get notesInsertImage => '插入图片';

  @override
  String get notesImagePickTitle => '插入图片';

  @override
  String get notesImagePickEmpty => '没有可用的图片';

  @override
  String get notesImagePickGroupImages => '图片';

  @override
  String get notesImagePickGroupNpcs => 'NPC';

  @override
  String get notesDeleteMessage => '删除此笔记？';

  @override
  String get notesDelete => '删除';

  @override
  String get notesNameNotUnique => '笔记标题必须唯一';

  @override
  String get notesSearchHint => '搜索笔记';

  @override
  String get notesSearchClear => '清除搜索';

  @override
  String get keyEventsNameLabel => '事件名称';

  @override
  String get keyEventsDeleteMessage => '删除此事件？所有对它的引用都将被移除。';

  @override
  String get keyEventsDelete => '删除';

  @override
  String get keyEventsNameNotUnique => '事件名称必须唯一';

  @override
  String get keyEventsSearchHint => '搜索事件';

  @override
  String get keyEventsSearchClear => '清除搜索';

  @override
  String get soundtracksAddLabel => '添加配乐';

  @override
  String get soundtracksDeleteMessage => '删除此配乐？';

  @override
  String get soundtracksDelete => '删除';

  @override
  String get soundtracksNameNotUnique => '已存在同名配乐';

  @override
  String get soundtracksSearchHint => '搜索配乐';

  @override
  String get soundtracksSearchClear => '清除搜索';

  @override
  String get imagesPickLabel => '选择图片';

  @override
  String get imagesAddTooltip => '添加图片';

  @override
  String get imagesDeleteMessage => '删除此图片？';

  @override
  String get imagesDelete => '删除';

  @override
  String get imagesAddButton => '添加';

  @override
  String get npcsNameLabel => '名称';

  @override
  String get npcsDescriptionLabel => '描述';

  @override
  String get npcsBackstoryLabel => '背景故事';

  @override
  String get npcsFullImageLabel => '完整图片';

  @override
  String get npcsIconLabel => '图标';

  @override
  String get npcsCropFull => '裁剪完整图片';

  @override
  String get npcsCropIcon => '裁剪图标';

  @override
  String get npcsClone => '克隆';

  @override
  String get npcsDelete => '删除';

  @override
  String get npcsDeleteMessage => '删除此NPC？';

  @override
  String get npcsNameNotUnique => '已存在同名NPC';

  @override
  String get npcsSearchHint => '搜索NPC';

  @override
  String get npcsSearchClear => '清除搜索';

  @override
  String get adventureClone => '克隆';

  @override
  String get adventureDelete => '删除';

  @override
  String get adventureDeleteMessage => '删除此冒险？';

  @override
  String get scenesAddLabel => '添加场景';

  @override
  String get scenesSearchHint => '搜索场景';

  @override
  String get scenesSearchClear => '清除搜索';

  @override
  String get scenesDeleteMessage => '删除此场景？';

  @override
  String get scenesDelete => '删除';

  @override
  String get scenesNameNotUnique => '已存在同名场景';

  @override
  String get sceneNameLabel => '名称';

  @override
  String get sceneNarrationLabel => '旁白';

  @override
  String get sceneSectionNpc => 'NPC';

  @override
  String get sceneSectionNotes => '笔记';

  @override
  String get playGmNotes => 'GM 笔记';

  @override
  String get playGmNoteAdd => '添加 GM 笔记';

  @override
  String get playGmNoteGlobal => '全局笔记';

  @override
  String get playGmNoteDeleteMessage => '删除此GM笔记会将其从每个场景中移除。此操作无法撤销。';

  @override
  String get playNpcDeactivate => '停用 NPC';

  @override
  String get playVillains => '反派（全部）';

  @override
  String get sceneSectionKeyEvents => '关键事件';

  @override
  String get sceneSectionImages => '图片';

  @override
  String get sceneSectionAudio => '配乐';

  @override
  String get sceneSectionPaths => '路径';

  @override
  String get sceneAddNotes => '添加笔记';

  @override
  String get sceneChooseSoundtrack => '选择配乐';

  @override
  String get scenePickNpcTitle => '选择NPC';

  @override
  String get scenePickNotesTitle => '选择笔记';

  @override
  String get scenePickKeyEventsTitle => '选择关键事件';

  @override
  String get scenePickImagesTitle => '选择图片';

  @override
  String get scenePickSoundtrackTitle => '选择配乐';

  @override
  String get sceneSectionType => '场景类型';

  @override
  String get sceneTypeStart => '起始场景';

  @override
  String get sceneTypeStandard => '标准场景';

  @override
  String get sceneTypeRecurring => '重复场景';

  @override
  String get sceneTypeEnd => '结束场景';

  @override
  String get sceneSectionNextScenes => '后续场景';

  @override
  String get scenePickNextScenesTitle => '选择后续场景';

  @override
  String get dialogOk => '确定';

  @override
  String get dialogClose => '关闭';

  @override
  String get playPauseSession => '暂停会话';

  @override
  String get playAdHocScene => '临时场景';

  @override
  String get playPreviousScene => '上一场景';

  @override
  String get playNextScene => '下一场景';

  @override
  String get playFinishAdventure => '结束冒险';

  @override
  String get playSplitParty => '分队';

  @override
  String get playSplitTitle => '分队';

  @override
  String get playSplitAssignHint => '选择进入新分组的玩家：';

  @override
  String get playSplitConfirm => '分队';

  @override
  String get playPipSwitchFocus => '切换焦点';

  @override
  String get playAdHocTitle => '临时场景';

  @override
  String get playAdHocNameLabel => '场景名称';

  @override
  String get playAdHocConfirm => '开始';

  @override
  String get playMergeHint => '→ 合并';

  @override
  String get playJumpToScene => '跳转到场景';

  @override
  String get playJumpTitle => '跳转到场景';

  @override
  String get playEndTrack => '结束此分组';

  @override
  String get playPauseConfirm => '保存进度并返回主菜单？';

  @override
  String get sceneSectionBackground => '背景图片';

  @override
  String get scenePickBackgroundTitle => '选择背景图片';

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
