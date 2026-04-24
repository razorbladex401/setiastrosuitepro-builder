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
  python3.12 \
  python3.12-devel \
  python3-pip \
  desktop-file-utils \
  hicolor-icon-theme \
  gcc gcc-c++ make
```

## Build

From this wrapper repo root:

```bash
chmod +x scripts/*.sh packaging/setiastrosuitepro-launcher.sh
./scripts/build_rpm.sh --ref main --python-bin python3.12
```

Optional explicit version/release:

```bash
./scripts/build_rpm.sh --ref v1.15.2.post2 --version 1.15.2.post2 --release 1

# Explicitly target the side-by-side Fedora python3.12 packages
./scripts/build_rpm.sh \
  --ref v1.15.2.post2 \
  --version 1.15.2.post2 \
  --release 1 \
  --python-bin python3.12 \
  --python-package python3.12 \
  --python-devel-package python3.12-devel \
  --python-pip-package python3-pip
```

Artifacts are copied to:

- `out/RPMS/`
- `out/SRPMS/`

## Notes

- Build needs internet access for pip dependency resolution unless you provide
  an internal package mirror/cache.
- The wrapper can target a side-by-side Python such as `python3.12` instead of
  Fedora's default `python3`. The packaged virtualenv still depends on that
  host Python ABI/package being installed at runtime.
- Linux upstream currently selects `onnxruntime-gpu`; runtime still depends on
  host GPU/CUDA compatibility.
- This wrapper does not attempt strict Fedora packaging guidelines for Python
  dependency unbundling.
- The RPM spec disables default debuginfo/strip post-processing because the
  bundled virtualenv contains many vendor ELF binaries that are not safe for
  Fedora's automatic `find-debuginfo`/`eu-strip` pipeline.

## GitLab CI/CD

This repository includes a pipeline in `.gitlab-ci.yml` with two stages:

- `build_rpm`: builds SRPM and binary RPM, stores artifacts, and (for tags)
  uploads both files to GitLab Generic Package Registry.
- `release_rpm`: creates a GitLab Release for the tag and attaches links to the
  uploaded RPM files.

### Triggering a release build

Push a tag:

```bash
git tag v1.15.2.post2
git push origin v1.15.2.post2
```

The tag pipeline will publish:

- Binary RPM link in the GitLab Release
- Source RPM link in the GitLab Release

### Optional CI variables

- `UPSTREAM_REF`: upstream git ref to build (default: `main`)
- `RPM_RELEASE`: RPM release component (default: GitLab `CI_PIPELINE_IID`)
- `PYTHON_BIN`: Python executable used to create the venv (default in CI: `python3.12`)
- `PYTHON_PACKAGE`: runtime/build package name for that Python (default in CI: `python3.12`)
- `PYTHON_DEVEL_PACKAGE`: development package for that Python (default in CI: `python3.12-devel`)
- `PYTHON_PIP_PACKAGE`: pip package for that Python (default in CI: `python3-pip`)
