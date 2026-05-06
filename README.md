# setiastrosuitepro-builder

Unofficial repository to build Flatpak bundles for [Seti Astro Suite Pro](https://github.com/setiastro/setiastrosuitepro). I liked the tool and wanted to make it easy for myself to install on Fedora 43. Originally was going to create an RPM build process but that comes with it's own dependencies and issues so I settled with a flatpak. Flatpaks are isolated sandboxes which means the host os needs very little to get them running.

## What this does

- Clones upstream source at a selected ref
- Produces a deterministic source tarball for Flatpak builds
- Generates a Flatpak manifest from a template
- Builds a Flatpak bundle via `flatpak-builder`
- Installs the application in `/app/venv` inside the Flatpak sandbox
- Installs a launcher command: `setiastrosuitepro`
- Installs a desktop entry and icon

## Flatpak Contents & Dependencies

### System Libraries (Flatpak Modules)

- **krb5 (Kerberos 5) 1.21.3** — Authentication library, built from source and included in the Flatpak

### Flatpak Runtime & Base

- **org.freedesktop.Platform 24.08** — Core OS libraries bundled in Flatpak
- **org.freedesktop.Sdk 24.08** — Development tools for building
- **Python 3.12** — Application runtime environment

### Python Packages (Bundled in Flatpak venv)

The Flatpak includes 100+ Python packages installed via pip into `/app/venv`:

**Core Scientific/Numeric:** 
- numpy 2.2.6, scipy 1.16.3, matplotlib 3.10.8, plotly 6.5.0, pandas 2.3.3, dask 2025.12.0, dask-image 2025.11.0

**Astronomy:** 
- astropy 7.2.0, astroquery 0.4.11, photutils 2.3.0, sep 1.4.1, astroalign 2.6.2, reproject 0.19.0, skyfield 1.53, jplephem 2.23, GaiaXPy 2.1.4, lightkurve 2.5.1

**Machine Learning/Neural Networks:** 
- onnx 1.20.0, onnxruntime-gpu 1.23.2 (Linux), numba 0.63.1, autograd 1.8.0

**Image Processing:** 
- opencv-python-headless 4.12.0.88, Pillow 12.0.0, rawpy 0.25.1, xisf 0.9.5, imagecodecs 2025.11.11, imageio 2.37.2, tifffile 2025.12.12, exifread 3.5.1

**GUI:** 
- PyQt6 6.10.1, pyqtgraph 0.14.0

**Networking:** 
- requests 2.32.5, aiohttp 3.13.2, aiobotocore 2.26.0

**Compression:** 
- lz4 4.4.5, zstandard

**Utilities:** 
- psutil 7.1.3, py-cpuinfo 9.0.0, pytz 2025.2, tzlocal 5.3.1, cloudpickle 3.1.2, fsspec 2025.12.0, and transitive dependencies

## Prerequisites (Linux)

The build script checks for the following commands at startup and will exit with
an error if any are missing:

| Package | Provides | Purpose |
|---|---|---|
| `flatpak` | `flatpak` | Install SDK/runtime, create bundle |
| `flatpak-builder` | `flatpak-builder` | Build the Flatpak sandbox |
| `git` | `git` | Clone upstream source |
| `sed` | `sed` | Template substitution in manifest |
| `grep` | `grep` | Version extraction from pyproject.toml |
| `curl` | `curl` | Fetch upstream `updates.json` at build time |
| `jq` | `jq` | Parse JSON from `updates.json` |

Install all at once on Fedora and other RPM-based distros:

```bash
sudo dnf install -y \
  flatpak \
  flatpak-builder \
  git \
  sed \
  grep \
  curl \
  jq
```

Install all at once on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y \
  flatpak \
  flatpak-builder \
  git \
  sed \
  grep \
  curl \
  jq
```


## Build

From this wrapper repo root:

```bash
chmod +x scripts/*.sh packaging/setiastrosuitepro-flatpak-launcher.sh
./scripts/build_flatpak.sh --ref main
```

Optional explicit version/release:

Versions can be found at the official Set Astro Suite Pro repo.

```bash
./scripts/build_flatpak.sh \
  --ref v1.15.3.post2 \
  --version 1.15.3.post2 \
  --release 1 \
  --branch stable
```

Artifacts are copied to:

- `out/flatpak/`

## Install

### Flatpak Repository (Recommended)

Add the Razorbladex401 Flatpak remote and install:

```bash
flatpak remote-add --if-not-exists razorbladex401 \
  https://razorbladex401.github.io/setiastrosuitepro-builder/com.razorbladex401.SetiAstroSuitePro.flatpakrepo

flatpak install setiastro com.razorbladex401.SetiAstroSuitePro
```

The remote is GPG-signed for security. Updates are automatically available via `flatpak update`.


## Notes

- `flatpak-builder` downloads the Flatpak SDK/runtime from Flathub on first use.
- The app itself runs inside `/app/venv`, and the Flatpak manifest patches the
  upstream acceleration runtime so its user-scoped venv is created with
  `--copies` instead of symlinking back to the host Python.
- Linux upstream currently selects `onnxruntime-gpu`; usable GPU acceleration in
  Flatpak still depends on host driver integration and Flatpak runtime support.
- The Flatpak manifest fetches `updates.json` at build time and patches the installed
  `APP_VERSION` string to match the upstream version, keeping the packaged app's
  version report synchronized with what CI built.
- The launcher script sets persistent storage paths for downloaded models and caches:
  - `XDG_DATA_HOME`, `XDG_CACHE_HOME` → user writable app data/cache directories
  - `HF_HOME`, `TRANSFORMERS_CACHE`, `TORCH_HOME`, `NUMBA_CACHE_DIR` → model caches
  - This avoids "No space left on device" errors when the app downloads ML models
    at runtime within the sandbox.

## Pipeline behavior

Build pipelines are triggered by source code, configuration, and tag changes but
**skip automatically** when only documentation (`.md`) or license files are updated.
This keeps CI resources focused on actual build changes.

Push and pull request workflows also skip on documentation-only updates.

## GitLab CI/CD

This repository includes a pipeline in `.gitlab-ci.yml` with two stages:

- `build_flatpak`: builds a Flatpak bundle, stores it as an artifact, and (for tags)
  uploads it to the GitLab Generic Package Registry.
- `release_flatpak`: creates a GitLab Release for the tag and attaches a link to the
  uploaded Flatpak bundle.

### Scheduled build behavior

- Pipelines started by `schedule` do a release check before building.
- CI queries upstream `updates.json` from `setiastro/setiastrosuitepro`.
- CI also queries the most recently published package version in this project's
  Generic Package Registry (`$PACKAGE_NAME`).
- If versions match, the scheduled pipeline exits early with `BUILD_STATUS=skipped`.
- If upstream is newer (or no package has been published yet), CI builds from
  upstream `main` with the advertised upstream version.
- **Tag-triggered pipelines bypass version checks** and always build, regardless of
  whether the version has been previously built.

Pipelines started by `web`, `push`, merge requests, or tags still run a build
whenever triggered.

## GitHub Actions CI/CD

This repository also includes a GitHub Actions workflow:

- `.github/workflows/build-flatpak.yml`

It mirrors the GitLab build flow:

- Triggers on push, pull request, tag, manual dispatch, and schedule.
- Scheduled runs compare upstream `updates.json` version with published GitHub
  Releases (`flatpak-v<version>` tags) and skip if already built.
- Builds use the same `scripts/build_flatpak.sh` wrapper.
- Non-PR runs publish the resulting `.flatpak` bundle to GitHub Release assets.

Security scanning in CI (best-practice two-stage gate):

- Source code scan during build using ClamAV (fail pipeline on detection).
- Final `.flatpak` bundle scan before publishing/release upload.
- Scan reports are stored as CI artifacts (`out/security/*.txt`).
- ClamAV updates are managed by stopping the background `clamav-freshclam` service
  before manual signature updates, avoiding log file lock conflicts on shared runners.

Release behavior in GitHub:

- Tag-triggered runs publish to that tag's release.
- Non-tag branch/push runs publish/update a release named `flatpak-v<version>`,
  where `<version>` is extracted from the built bundle filename.
- GitHub Release assets contain the `.flatpak` bundle and security scan reports.

### Triggering a release build

Push a tag to trigger a tagged release:

```bash
git tag v1.15.2.post2
git push origin v1.15.2.post2
```

Both GitLab and GitHub pipelines will publish the Flatpak bundle to their
respective release assets. The release is tagged and versioned based on the
upstream version detected or explicitly provided via `--version` in the build script.

### Optional CI variables

- `UPSTREAM_REF`: upstream git ref to build (default: `main`). In scheduled builds,
  this is automatically set to `main` after version checks; in manual/tag builds, it
  can be overridden to build from a specific ref or tag.
- `PACKAGE_RELEASE`: Flatpak bundle release component (default: build date in `YYYYMMDD` format, UTC). Included in the bundle filename for differentiation. Can be overridden manually for reruns or local builds.
- `FLATPAK_BRANCH`: Flatpak branch name (default: `stable`). Used by `flatpak-builder`
  to determine the final bundle branch.

## Acknowledgments & Attribution

This wrapper and build infrastructure includes or depends on the following projects:

- **[Seti Astro Suite Pro](https://github.com/setiastro/setiastrosuitepro)** — The original application, licensed under GNU General Public License v3.0. This project builds and packages the upstream source into a Flatpak.

- **[Flatpak](https://flatpak.org/)** — Application sandboxing and distribution framework (LGPL-2.1+). Core technology enabling self-contained deployment.

- **[Freedesktop](https://www.freedesktop.org/)** and **[Flathub](https://flathub.org/)** — Runtime and SDK distributions; base platform libraries.

- **[ClamAV](https://www.clamav.net/)** — Open-source antivirus engine (GPL-2.0) used in CI/CD security scanning stages.

- **Python and bundled packages** — The 100+ Python packages listed in "Flatpak Contents & Dependencies" retain their original licenses (MIT, BSD, Apache-2.0, GPL, and others). See `requirements.txt` in the upstream repository for the complete dependency tree and license information.

- **Build tooling** — `flatpak-builder`, `jq`, `curl`, `sed`, and standard GNU/Linux utilities.

## License

This repository is licensed under the GNU General Public License v3.0.
See the [LICENSE](LICENSE) file.

