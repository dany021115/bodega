# Spec · Rules, real checks and delivery

Requirements DN1..DN7. **(USER)** marks what only the user can do: play a game, which opens windows (`.claude/CLAUDE.md`, "Working here"). Agents run Wine headless only, and install runtimes headless, since their installers run silently.

## DN1 · The project's rules
`.claude/CLAUDE.md` shall say, beside the line on `fixes_data.dart`, that Bodega's own per-game fixes live in `packages/engine/lib/bodega_fixes_data.dart`, hand-written, each with how and when it was verified, and that Microsoft's installers are downloaded from Microsoft's servers at the user's click, checked against the pinned SHA-256, and never stored in the repo or the packages. `.claude/rules/architecture.md` shall name the `dependencies.dart` part and `DependenciesBloc` as an install that outlives the page.
- **Check:** `git diff <base> -- .claude` shows those lines.

## DN2 · No installer in git or in the packages
- **Given** the branch, **when** `git ls-files | grep -iE '\.(exe|msi|cab)$'` runs, **then** it prints only files that were there before (`git diff --stat <base>` adds none), and `tool/package_linux.sh`'s and `tool/package_macos.sh`'s outputs gain no installer.
- **Check:** that command and `git diff --stat <base>`.

## DN3 · Version
The change is a feature: the version is one minor above `main`'s when the branch starts (`1.8.0` if pull request #20 brought `1.7.0`), raised once, in the branch's first commit.
- **Check:** `tool/version.sh check` before each commit, output in `verify.md`.

## DN4 · A real install, headless (agent)
In a scratch bottle made for it (never the user's `Games`), the agent installs `vcrun2008 x86` with `build/bodega deps install`, then checks that `windows/winsxs/x86_microsoft.vc90.crt_…_9.0.30729.6161_*/msvcr90.dll` carries no Wine mark, that `user.reg` holds the five overrides under `[Software\\Wine\\DllOverrides]`, and that `deps list` says installed; then the same for `vcrun2022 x86` and `x64`; then deletes the scratch bottle after `bodega stop`.
- **Check:** the commands and their output in `verify.md`.

## DN5 · Blur in a new bottle (USER)
In a new bottle, the user adds Blur with "Add program", accepts the dialog's recommended Visual C++ 2008, and plays at least 45 minutes. Pass: no "Program Error Details" window and no `msvcr90` in the run's log.
- **Check:** the user's account and the log's name in `verify.md`.

## DN6 · Need for Speed from Bodega (USER)
With `Reverb=1` put back in the game's file, the user opens the Games bottle's panel, applies the NFS13 setting, plays at least 3 minutes, and hears no stutter; the run's log (with `BODEGA_WINEDEBUG=fixme-all,warn+dsound`) has at most 10 "Overwriting mixing position" lines.
- **Check:** the user's account and the count in `verify.md`.

## DN7 · Delivery
The work stays uncommitted in the branch's working tree for the user to read and run; `../dependencies-commit.sh`, beside the repo, commits the bump, M1, M2 and M3's docs in four commits, stops if a check fails, runs `tool/version.sh check` before each code commit, pushes nothing, and has English messages with no AI attribution.
- **Check:** `bash -n ../dependencies-commit.sh`; the user runs it.
