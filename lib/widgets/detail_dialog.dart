import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A read-only DETAIL dialog sized to 80% of the window HEIGHT, its shorter side
/// (WIDTH) keeping ISO format-A proportions (1:√2 => width = height / √2). Holds
/// an optional [title] and the FULL, scrollable [body], with a single OK button
/// that closes it. SHARED by the launch screen's start-scene detail and the play
/// view's GM-note detail so the two are the same dialog.
///
/// Keys: [rootKey] on the sized box, [titleKey] / [bodyKey] on the texts, [okKey]
/// on the OK button.
Future<void> showDetailDialog(
  BuildContext context, {
  required String rootKey,
  String? title,
  String? titleKey,
  required String body,
  required String bodyKey,
  required String okKey,
}) {
  final windowSize = MediaQuery.sizeOf(context);
  final height = windowSize.height * 0.8;
  // Format A short:long = 1 : √2; the height is the long edge.
  final width = math.min(height / math.sqrt2, windowSize.width - 48);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      final text = Theme.of(ctx).textTheme;
      return Dialog(
        child: SizedBox(
          key: ValueKey(rootKey),
          height: height,
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title,
                    key: titleKey == null ? null : ValueKey(titleKey),
                    style: text.titleLarge,
                  ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      body,
                      key: ValueKey(bodyKey),
                      style: text.bodyLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: ValueKey(okKey),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.dialogOk),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
