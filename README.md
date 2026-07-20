# LivingScroll

LivingScroll is an offline-first authoring and play tool for tabletop-RPG
adventures. Write a branching adventure — scenes, NPCs, notes, images, audio,
key events, story paths — then run it live at the table, pause and resume
across sessions, and split the party into parallel tracks when the group
divides. Everything lives on disk as plain, versioned JSON plus media files;
there is no server and no account.

## Features

- **Adventure authoring** — scenes with branching "next scene" links, NPCs,
  notes (rich text), images, background music/soundtracks, key events, and
  colour-coded story paths.
- **System-aware NPCs** — a built-in stat-block template per game system
  (7th Sea 2nd Edition, or a system-agnostic "Basic" template), with
  validated per-system fields.
- **Play mode** — run a live session, track checked key events and active/
  inactive NPCs, take GM notes, and resume exactly where you left off.
- **Party split** — when the group divides, run parallel in-memory tracks
  (split / focus+picture-in-picture / merge / dead-end / track-end) without
  losing the shared session state.
- **Replay** — step back through a finished session's full history for
  review or a do-over.
- **Export to LaTeX** — turn a finished adventure into a compilable LaTeX
  handbook (plain `book` layout, no vendored templates or fonts — just the
  standard packages any TeX distribution ships).
- **Eight languages** — English, German, French, Portuguese, Spanish, Polish,
  Chinese, Japanese, with automatic light/dark theming.
- **Runs everywhere** — Windows, Linux, and Android from one codebase
  (Flutter); a portable `.ls` archive format moves adventures between
  machines.

## Getting started

LivingScroll is built with [Flutter](https://flutter.dev). To run it from
source:

```sh
flutter pub get
flutter run
```

Platform-specific build notes (system packages, installers):

- [README.Windows.md](README.Windows.md) — building the Windows desktop app
  and its Inno Setup installer.
- [README.Debian.md](README.Debian.md) — runtime dependencies on
  Debian/Ubuntu-family Linux.
- [README.RedHat.md](README.RedHat.md) — runtime dependencies on
  Fedora/RHEL-family Linux.

Prebuilt Windows installers, Linux AppImages, and Android APKs are published
on the [Releases](../../releases) page for every tagged version.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to run the test suite and the
pull-request/CI workflow.

## License

MIT — see [LICENSE](LICENSE).
