# setiastrosuitepro-builder

Unofficial repository to build Flatpak bundles for [Seti Astro Suite Pro](https://github.com/setiastro/setiastrosuitepro). I liked the tool and wanted to make it easy for myself to install on Fedora 43 which comes with python 3.14. I'm not a fan of maintaining two different python versions on the same system so decided to create a flatpak that's self-contained.

## What this does

- Clones upstream source at a selected ref
- Produces a deterministic source tarball for Flatpak builds
- Generates a Flatpak manifest from a template
- Builds a Flatpak bundle via `flatpak-builder`
- Installs the application in `/app/venv` inside the Flatpak sandbox
- Installs a launcher command: `setiastrosuitepro`
- Installs a desktop entry and icon

## Prerequisites (Fedora/RHEL-like)

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

Install all at once:

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
```bash
sudo flatpak install out/setiastrosuitepro-<version>-1.flatpak
```

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
- CI queries upstream `updates.json` from `setiastro/setiastrosuitepro`.
- CI also queries the most recently published package version in this project's
  Generic Package Registry (`$PACKAGE_NAME`).
- If versions match, the scheduled pipeline exits early with `BUILD_STATUS=skipped`.
- If upstream is newer (or no package has been published yet), CI builds from
  upstream `main` with the advertised upstream version.

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

- Source scan during build using ClamAV (fail pipeline on detection).
- Final `.flatpak` bundle scan before publishing/release upload.
- Scan reports are stored as CI artifacts (`out/security/*.txt`).

Release behavior in GitHub:

- Tag-triggered runs publish to that tag's release.
- Non-tag runs publish/update a release tag named `flatpak-v<version>`.

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

## License

This repository is licensed under the GNU General Public License v3.0.
See the [LICENSE](LICENSE) file.
