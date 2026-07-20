# Production CI/CD setup (GitHub Actions)

This repo ships two GitHub Actions workflows:

- `.github/workflows/ci.yml` — the **full test suite** (analyze + unit/widget +
  integration). Runs on every pull request to `main` and on push to `main`.
- `.github/workflows/release.yml` — builds a **Windows installer**, a **Linux
  AppImage**, and an **Android APK**, and attaches them to a GitHub Release.
  Runs ONLY on version tags `vX.Y.Z`, and only if the tag matches
  `pubspec.yaml`'s `version:` (the `preflight` job fails the release
  otherwise) — a release is always exactly what `pubspec.yaml` says it is.

The goal: `main` is a **protected** branch that requires the full test suite
to pass before merging, and a release is a deliberate, tag-triggered action —
never a side effect of a normal push.

iOS/macOS are intentionally omitted — they need a macOS runner + a paid Apple
Developer account. Add them later (a `macos` job + signing).

Both workflows are free to run as-is on GitHub-hosted runners
(`ubuntu-latest`/`windows-latest`) — no self-hosted infrastructure needed.

---

## 1. One-time repository setup

These are manual, one-time steps in the GitHub repo's settings (none of this
can be automated without a live repo + an authenticated `gh`/API session):

1. **Push this repo to GitHub** (or push the output of
   `scripts/export_public.sh`, see `CONTRIBUTING.md`, if you want a public
   mirror separate from a private working repo).
2. **Settings → Secrets and variables → Actions → Variables**: add
   `FLUTTER_VERSION` (e.g. `3.44.2`) so both workflows pin the same Flutter
   version from one place. If unset, they fall back to a hardcoded default in
   the workflow file.
3. **Settings → Branches → Branch protection → add rule for `main`:**
   - Require pull requests before merging.
   - Require status checks to pass — select **`CI / test`** (only selectable
     **after** `ci.yml` has run at least once, so push once / open a
     throwaway PR first to make it appear in the list).
   - (recommended) Require branches to be up to date before merging, require
     at least one review approval.
4. **Android signing** (optional — without it, release APKs are debug-signed:
   installable, not Play-Store-publishable): see §2 below.

## 2. Android signing

`android/app/build.gradle.kts` reads `android/key.properties` when present
and falls back to debug signing otherwise. To sign real releases:

1. Create an upload keystore:
   `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.
2. Add repo secrets (**Settings → Secrets and variables → Actions →
   Secrets**): `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`),
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
3. That's it — the `android` job in `release.yml` decodes the keystore and
   writes `android/key.properties` automatically whenever
   `ANDROID_KEYSTORE_BASE64` is set; a fork or PR run without these secrets
   still succeeds, just debug-signed.

Never commit `key.properties` or a `.jks`/`.keystore` file — both are
gitignored.

## 3. Cutting a release

```bash
# Bump pubspec.yaml's version: line to match first, then:
git tag v1.2.0
git push origin v1.2.0
```

`release.yml` then builds the Windows installer, the Linux AppImage, and the
Android APK in parallel, and the `publish` job attaches all three to a new
GitHub Release for that tag — giving stable, versioned download URLs
(`github.com/<org>/<repo>/releases/download/v1.2.0/<file>`) with no separate
hosting needed.

## 4. Notes / known constraints

- **Integration tests** are run one file at a time under Xvfb (a
  directory-wide run fails to load in this project). They run as a Linux
  **desktop** app, so the `Test_Assets/` fixtures resolve from the checkout —
  this works on the Linux runner.
- **compileSdk 36** is forced for all Android modules in
  `android/build.gradle.kts` to reconcile plugins that pin an older
  compileSdk; the `android` job installs `platforms;android-36` to match.
- **The Linux AppImage** is built by `scripts/build_appimage.sh` using only
  `appimagetool` (MIT) — no vendored packaging framework.
- **The Windows installer** is built by `build_windows.ps1` (already used for
  local builds, see `README.Windows.md`) via Inno Setup, installed in CI with
  `choco install innosetup`.
