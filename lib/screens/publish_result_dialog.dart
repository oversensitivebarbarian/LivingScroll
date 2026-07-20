import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/publish_validator.dart';

/// The dialog raised by the in-game Publish action. When the
/// adventure passes every publish check it shows a success message; otherwise it
/// lists each [PublishIssue] (keyed by [PublishIssue.keyId]) so the author can
/// fix the problems before publishing.
class PublishResultDialog extends StatelessWidget {
  const PublishResultDialog({
    super.key,
    required this.issues,
    this.onDownload,
    this.downloadLabel,
    this.validMessage,
    this.dismissOnDownload = false,
  });

  final List<PublishIssue> issues;

  /// The success-dialog body. Defaults to the generic "successfully exported"
  /// message; the Export-elements flow passes its own (the `.lse` is ready).
  final String? validMessage;

  /// Invoked by the success dialog's download button (saving the portable
  /// archive). Returns `true` when the file was actually saved (the user chose a
  /// destination), `false` when the save was cancelled. Only shown when both
  /// this and [downloadLabel] are set and there are no issues.
  final Future<bool> Function()? onDownload;

  /// Label of the download button (e.g. "Download .ls" / "Download .lse").
  final String? downloadLabel;

  /// When `true`, choosing a save destination dismisses the dialog automatically
  /// (the Export-elements flow). A cancelled save leaves the dialog open.
  final bool dismissOnDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (issues.isEmpty) {
      return AlertDialog(
        key: const ValueKey('publish.dialog.valid'),
        title: Text(l10n.publishValidTitle),
        content: Text(
          validMessage ?? l10n.publishValidMessage,
          key: const ValueKey('publish.dialog.valid.message'),
        ),
        actions: [
          if (onDownload != null && downloadLabel != null)
            TextButton(
              key: const ValueKey('publish.dialog.download'),
              onPressed: () async {
                final saved = await onDownload!();
                if (saved && dismissOnDownload && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(downloadLabel!),
            ),
          _closeButton(context, l10n),
        ],
      );
    }

    return AlertDialog(
      key: const ValueKey('publish.dialog.invalid'),
      title: Text(l10n.publishInvalidTitle),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final issue in issues)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.error_outline, size: 18),
                    ),
                    Expanded(
                      child: Text(
                        _message(l10n, issue),
                        key: ValueKey(issue.keyId),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [_closeButton(context, l10n)],
    );
  }

  Widget _closeButton(BuildContext context, AppLocalizations l10n) =>
      TextButton(
        key: const ValueKey('publish.dialog.close'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.dialogClose),
      );

  /// The localized message for [issue]; subjects (scene/field/NPC names) are
  /// interpolated into the placeholder messages.
  String _message(AppLocalizations l10n, PublishIssue issue) {
    final subject = issue.displaySubject ?? '';
    switch (issue.code) {
      case PublishIssueCode.adventureFieldMissing:
        return l10n.publishIssueAdventureField(subject);
      case PublishIssueCode.npcIncomplete:
        return l10n.publishIssueNpcIncomplete(subject);
      case PublishIssueCode.noteIncomplete:
        return l10n.publishIssueNoteName;
      case PublishIssueCode.noStartScene:
        return l10n.publishIssueNoStartScene;
      case PublishIssueCode.noEndScene:
        return l10n.publishIssueNoEndScene;
      case PublishIssueCode.endSceneHasNext:
        return l10n.publishIssueEndSceneHasNext(subject);
      case PublishIssueCode.nonEndSceneNoNext:
        return l10n.publishIssueSceneNoNext(subject);
      case PublishIssueCode.nonEndSceneOnlyConditionalNext:
        return l10n.publishIssueSceneOnlyConditionalNext(subject);
      case PublishIssueCode.noUnconditionalPathToEnd:
        return l10n.publishIssueNoPathToEnd;
      case PublishIssueCode.blindLoop:
        return l10n.publishIssueBlindLoop(subject);
      case PublishIssueCode.pathNoStartScene:
        return l10n.publishIssuePathNoStartScene(subject);
      case PublishIssueCode.pathNoEndScene:
        return l10n.publishIssuePathNoEndScene(subject);
      case PublishIssueCode.pathNoUnconditionalRouteToEnd:
        return l10n.publishIssuePathNoRouteToEnd(subject);
    }
  }
}
