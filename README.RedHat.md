# LivingScroll on Red Hat / Fedora

Applies to **Fedora, RHEL, CentOS Stream, Rocky Linux, AlmaLinux** and other
`dnf`/`yum`-based distributions.

## Why this is needed

The Soundtracks section plays audio through `just_audio`, whose Linux backend is
**media_kit**. On Linux media_kit loads **`libmpv.so.2`** (the mpv client
library) at runtime — it is *not* bundled with the application. If `libmpv` is
missing the app crashes on start with an error like:

```
Failed to open libmpv.so.2 / libmpv.so
```

Install the mpv runtime library to fix it. On Red Hat family distributions mpv
lives in the **RPM Fusion (free)** repository, which must be enabled first.

## 1. Enable RPM Fusion (one-time)

**Fedora:**

```bash
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
```

**RHEL / CentOS Stream / Rocky / AlmaLinux** (also needs EPEL):

```bash
sudo dnf install -y \
  https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm
```

## Runtime requirements (to RUN the app)

| Package          | Provides                 | Notes                          |
|------------------|--------------------------|--------------------------------|
| `mpv-libs`       | `libmpv.so.2` (required) | The runtime library            |
| `mpv`            | mpv player + codecs      | Recommended                    |

```bash
sudo dnf install -y mpv-libs mpv
```

Plus the standard GTK runtime a Flutter Linux desktop app needs (already present
on most desktops):

```bash
sudo dnf install -y gtk3 mesa-libGLU
```

## Build requirements (to BUILD from source)

The Flutter Linux desktop toolchain and the mpv headers:

```bash
sudo dnf install -y \
  clang cmake ninja-build pkgconf-pkg-config \
  gtk3-devel xz-devel \
  mpv-libs-devel mpv
```

Then:

```bash
flutter pub get
flutter build linux --release
# or, for development:
flutter run -d linux
```

## Verify

```bash
# Should list libmpv.so.2:
/sbin/ldconfig -p | grep mpv
```

If `libmpv.so.2` appears, the Soundtracks Play button will work.
