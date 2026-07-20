# Contributing

## Running the app

```sh
flutter pub get
flutter run
```

## Running the tests

```sh
flutter analyze
flutter test test/
```

Integration tests live in `integration_test/` and are executable specs — one
file per user-facing navigation path. Run them **one file at a time** (a
directory-wide run fails to load in this project):

```sh
flutter test integration_test/<name>_test.dart -d linux
```

On a headless machine, run them under Xvfb:

```sh
xvfb-run -a -s "-screen 0 1920x1080x24" flutter test integration_test/<name>_test.dart -d linux
```

## Pull requests

- Target `main`. The `CI / test` check (`flutter analyze` + the full unit and
  integration suite) must pass before a PR can merge — `main` is a protected
  branch, no exceptions.
- Keep changes focused; a PR that touches unrelated code is harder to review
  and to revert if something breaks.

## Releases

A release is cut by pushing a version tag (`vX.Y.Z`) that matches the
`version:` in `pubspec.yaml` — this triggers the release workflow, which
builds a Windows installer, a Linux AppImage, and an Android APK and attaches
them to a GitHub Release for that tag. See
[docs/CI_SETUP.md](docs/CI_SETUP.md) for the one-time repository setup this
depends on.

## Public source layout

This repository excludes a few internal, ALL-CAPS directories (design specs,
navigation specs, layout specs, task notes, reference material) that back
this project's own AI-assisted development workflow — they aren't needed to
build, test, or contribute to the app itself. `scripts/export_public.sh`
documents exactly what is excluded and why.
