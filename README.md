# setiastro-wrapper

Wrapper repository to build RPMs for [Seti Astro Suite Pro](https://github.com/setiastro/setiastrosuitepro).

## What this does

- Clones upstream source at a selected ref
- Produces a deterministic source tarball for rpmbuild
- Generates an RPM spec from a template
- Builds SRPM + RPM via rpmbuild
- Installs the application in `/opt/setiastrosuitepro/venv`
- Installs a launcher command: `setiastrosuitepro`
- Installs a desktop entry and icon

## Why a wrapper RPM

The upstream project is a large Poetry-based Python GUI app with many binary
Python dependencies. Packaging every dependency as distro-native RPMs is
possible but high-effort and distro-specific. This wrapper approach is faster
and practical for internal distribution.

## Prerequisites (Fedora/RHEL-like)

```bash
sudo dnf install -y \
  rpm-build \
  python3 \
  python3-devel \
  python3-pip \
  desktop-file-utils \
  hicolor-icon-theme \
  gcc gcc-c++ make
```

## Build

From this wrapper repo root:

```bash
chmod +x scripts/*.sh packaging/setiastrosuitepro-launcher.sh
./scripts/build_rpm.sh --ref main
```

Optional explicit version/release:

```bash
./scripts/build_rpm.sh --ref v1.15.2.post2 --version 1.15.2.post2 --release 1
```

Artifacts are copied to:

- `out/RPMS/`
- `out/SRPMS/`

## Notes

- Build needs internet access for pip dependency resolution unless you provide
  an internal package mirror/cache.
- Linux upstream currently selects `onnxruntime-gpu`; runtime still depends on
  host GPU/CUDA compatibility.
- This wrapper does not attempt strict Fedora packaging guidelines for Python
  dependency unbundling.
