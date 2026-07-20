# LivingScroll on Debian / Ubuntu

Applies to **Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin** and other
`apt`-based derivatives.

## Why this is needed

The Soundtracks section plays audio through `just_audio`, whose Linux backend is
**media_kit**. On Linux media_kit loads **`libmpv.so.2`** (the mpv client
library) at runtime — it is *not* bundled with the application. If `libmpv` is
missing the app crashes on start with an error like:

```
Failed to open libmpv.so.2 / libmpv.so
```

Install the mpv runtime library to fix it. **This applies to the AppImage too**
— it is not fully self-contained in this one respect: bundling `libmpv` would
mean bundling its own ~230 transitive dependencies (the full X11/Wayland/GPU-
driver and audio-backend stack), which is unsafe to ship pre-packaged (it must
match the host's actual drivers) and roughly quadruples the download size, so
the AppImage relies on the system's `libmpv2` like every other install method.

## Runtime requirements (to RUN the app)

| Package    | Provides                    | Notes                                  |
|------------|-----------------------------|----------------------------------------|
| `libmpv2`  | `libmpv.so.2` (required)    | Debian 12+ / Ubuntu 23.10+             |
| `mpv`      | mpv player + codecs         | Recommended; pulls in `libmpv` + codecs|

```bash
sudo apt update
sudo apt install -y libmpv2 mpv
```

Plus the standard GTK runtime a Flutter Linux desktop app needs (already present
on most desktops):

```bash
sudo apt install -y libgtk-3-0 libglu1-mesa
```

## Build requirements (to BUILD from source)

The Flutter Linux desktop toolchain and the mpv headers:

```bash
sudo apt update
sudo apt install -y \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev \
  libmpv-dev mpv
```

Then:

```bash
flutter pub get
flutter build linux --release
# or, for development:
flutter run -d linux
```

## Older releases (Ubuntu 22.04, Debian 11 "bullseye")

These ship only **`libmpv1`** (which provides `libmpv.so.1`), but media_kit
needs `libmpv.so.2`. Options:

1. **Preferred** — install a newer libmpv (e.g. enable backports or a PPA that
   provides `libmpv2`):
   ```bash
   sudo apt install -y libmpv2
   ```
2. **Workaround** — if only `libmpv.so.1` is available and is ABI-compatible,
   create a compatibility symlink (use at your own risk):
   ```bash
   sudo ln -s "$(/sbin/ldconfig -p | awk '/libmpv.so.1/{print $NF; exit}')" \
              /usr/local/lib/libmpv.so.2
   sudo ldconfig
   ```

## Verify

```bash
# Should list libmpv.so.2:
/sbin/ldconfig -p | grep mpv
```

If `libmpv.so.2` appears, the Soundtracks Play button will work.
