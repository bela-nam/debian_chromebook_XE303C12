# AGENTS.md

Builds a Debian armhf (32-bit ARM) OS image for a Samsung ARM Chromebook XE303C12 (Exynos 5250) via Docker + QEMU binfmt + debootstrap. Shell + Make only — no package manager, no test suite. Heavily based on Kali's ARM build scripts.

## Layout

- `scripts/docker_build.sh` — build entrypoint (also the `.buildbot` command). Takes **no arguments**; always builds trixie. Copies `Dockerfile.trixie` → `Dockerfile`, builds the image, runs it `--privileged`, copies `configs/` + `scripts/` in, runs `build.sh` inside, copies `release/` out. Runs `docker system prune -f -a` (wipes unused host Docker images — don't run casually).
- `scripts/Dockerfile.trixie` — the real Dockerfile (`debian:trixie-slim`). `scripts/Dockerfile` is **generated** (copied by `docker_build.sh`, gitignored) — never edit it directly; edit `Dockerfile.trixie`.
- `scripts/build.sh` — runs **inside** the privileged container: fails unless Debian trixie; cross-compiles armhf kernel (linux-source-6.12, `arm-linux-gnueabihf-`), debootstraps armhf rootfs, third-stage chroot (packages incl. apt `firmware-*`, `root:toor`), packages kernel via `vbutil_kernel`, emits `release/xe303c12.zip` + kernel `.deb`s.
- `scripts/install.sh` — target-side: interactive device picker via `lsblk` as normal user (escalates with sudo), or root mode to install/update on `/dev/mmcblk0p1` or full install on a device argument. GPT layout: kernel slots A/B + data partition.
- `configs/6.12` — kernel `.config` for the trixie build, keyed by kernel `major.minor` via `/configs/$version`.

## Commands

- `make` = `check` + `run`.
- `make check` — the only verification: `shfmt -d` + `shellcheck` on `build.sh`, `docker_build.sh`, `install.sh` (in Docker: `mvdan/shfmt`, `koalaman/shellcheck`).
- `make format` — autofix with `shfmt -w`.
- `make run` — full image build; **the Makefile swallows failures (`|| true`)** — check that `release/xe303c12.zip` and the kernel `.debs` exist, or run `bash scripts/docker_build.sh` directly for a real exit code.

## Build pipeline notes (`scripts/build.sh`, inside privileged container)

- Fails early unless the container is Debian trixie.
- Kernel version from `make kernelversion`; `version = major.minor` selects `/configs/$version`; `make olddefconfig` → `make bindeb-pkg -j$(nproc)` → `make dtbs`; DTBs under `arch/arm/boot/dts/samsung/`.
- binfmt: `mount binfmt_misc`, register `qemu-arm`, `update-binfmts --enable qemu-arm`.
- Rootfs via `debootstrap --arch=armhf trixie debian_root ...`; apt sources pinned to trixie (+ `-security`).
- Third stage (chroot): sets `root:toor`, installs packages + apt `firmware-*`, enables SSH host key regeneration.
- Kernel install branch: empty `$kernel_version` → install `linux-image-armmp`; else `apt-get install /*.deb` from the cross-built debs.
- Kernel image: `kernel-exynos.its` with FDTs (exynos5250-snow, -rev5, -spring; default conf@1), `vbutil_kernel --arch arm --pack` → `/kernel_usb.bin` (USB boot: `root=PARTUUID=%U/PARTNROFF=2`) and `/kernel_emmc_ext4.bin` (eMMC: `root=/dev/mmcblk0p3`).
- Emits `release/xe303c12.zip` (kernel + rootfs + install scripts) and kernel `.deb`s.

## Gotchas

- Docker required; container runs `--privileged` with a 16 GB memory cap and needs `binfmt_misc` for qemu-arm. Builds are long.
- Only trixie is supported; the release↔kernel coupling is hardcoded in three places: a `Dockerfile.<codename>` (matching `linux-source-<kernel>`), the release guard / kernel extraction / apt sources in `build.sh`, and a `configs/<major>.<minor>` kernel config.
- Device firmware comes from the apt `firmware-*` packages installed in the third stage (no manual firmware fetching — the old `git.ti.com` step was removed; those files are for TI Sitara boards, not this Exynos 5250).
- The `ti_hecc.c` CAN driver is not compiled (recent gcc failure); reflected in `configs/6.12`.
- Resulting image's default credentials: `root` / `toor`.
- Known issue: do not `reboot` after install (black screen bug) — see `Readme.rst`.

## Sources of truth

- Executable sources beat prose: `scripts/*.sh`, `scripts/Dockerfile.trixie`, and the `Makefile` win over `Readme.rst` and CI docs; keep this file in sync when commands change.

## CI

- `.github/workflows/publish.yml` triggers on **tag push**: runs `make check` then `make run`, uploads `release/*` as release artifacts.
