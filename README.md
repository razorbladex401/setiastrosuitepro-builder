# setiastrosuitepro-builder

Wrapper repository to build Flatpak bundles for [Seti Astro Suite Pro](https://github.com/setiastro/setiastrosuitepro).

## What this does

- Clones upstream source at a selected ref
- Produces a deterministic source tarball for Flatpak builds
- Generates a Flatpak manifest from a template
- Builds a Flatpak bundle via `flatpak-builder`
- Installs the application in `/app/venv` inside the Flatpak sandbox
- Installs a launcher command: `setiastrosuitepro`
- Installs a desktop entry and icon

## Why a wrapper Flatpak

The upstream project is a large Poetry-based Python GUI app with many binary
Python dependencies and a strict Python 3.12 requirement for acceleration.
Flatpak gives us a controlled userspace, avoids host-Python drift, and is a
better fit for shipping a self-contained desktop app than host-coupled RPMs.

The repository still contains the earlier RPM packaging files, but the current
CI flow is Flatpak-first.

## Prerequisites (Fedora/RHEL-like)

```bash
sudo dnf install -y \
  flatpak \
  flatpak-builder \
  git sed tar which
```

## Build

From this wrapper repo root:

```bash
chmod +x scripts/*.sh packaging/setiastrosuitepro-flatpak-launcher.sh
./scripts/build_flatpak.sh --ref main
```

Optional explicit version/release:

```bash
./scripts/build_flatpak.sh \
  --ref v1.15.2.post2 \
  --version 1.15.2.post2 \
  --release 1 \
  --branch stable
```

Artifacts are copied to:

- `out/flatpak/`

## Notes

- `flatpak-builder` downloads the Flatpak SDK/runtime from Flathub on first use.
- The app itself runs inside `/app/venv`, and the Flatpak manifest patches the
  upstream acceleration runtime so its user-scoped venv is created with
  `--copies` instead of symlinking back to the host Python.
- Linux upstream currently selects `onnxruntime-gpu`; usable GPU acceleration in
  Flatpak still depends on host driver integration and Flatpak runtime support.

## GitLab CI/CD

This repository includes a pipeline in `.gitlab-ci.yml` with two stages:

- `build_flatpak`: builds a Flatpak bundle, stores it as an artifact, and (for tags)
  uploads it to the GitLab Generic Package Registry.
- `release_flatpak`: creates a GitLab Release for the tag and attaches a link to the
  uploaded Flatpak bundle.

### Scheduled build behavior

- Pipelines started by `schedule` do a release check before building.
- CI queries the latest upstream GitHub release tag from
  `setiastro/setiastrosuitepro`.
- CI also queries the most recently published package version in this project's
  Generic Package Registry (`$PACKAGE_NAME`).
- If versions match, the scheduled pipeline exits early with `BUILD_STATUS=skipped`.
- If upstream is newer (or no package has been published yet), CI builds that
  upstream release tag automatically.

Pipelines started by `web`, `push`, merge requests, or tags still run a build
whenever triggered.

### Triggering a release build

Push a tag:

```bash
git tag v1.15.2.post2
git push origin v1.15.2.post2
```

The tag pipeline will publish:

- Flatpak bundle link in the GitLab Release

### Optional CI variables

- `UPSTREAM_REF`: upstream git ref to build (default: `main`)
- `PACKAGE_RELEASE`: Flatpak bundle release component (default: GitLab `CI_PIPELINE_IID`)
- `FLATPAK_BRANCH`: Flatpak branch name (default: `stable`)
