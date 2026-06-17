# dotfiles Agent Contract

This repo is the machine bootstrap surface for laptop and Spark.

## Role

- Own shell, terminal, tmux, Git, prompt, and machine-level install/sync glue.
- Install shared Codex and Claude runtime defaults by calling
  `~/github/fhh-toolkit/runtimes/*/sync-config.sh` when the toolkit exists.
- Do not store agent credentials, auth files, cache state, sessions, memories,
  telemetry, or generated hook trust state here.
- Do not inline shared skills or project rules here. Put shared agent content
  in `~/github/fhh-toolkit`; put repo-specific contracts in the owning repo.

## Canonical surface

- Laptop and Spark should share the `$HOME/github/` layout.
- Treat `~/github/fos` and its siblings (`fhh-toolkit`, `dotfiles`,
  `fos-workbench`, `job-searching`) as the default work surface.
- Top-level duplicates such as `~/fos` are transition clones unless a task
  explicitly names them.

## Editing rules

- Keep Stow packages at the repo root and update `install.sh` plus `README.md`
  when adding managed files.
- Preserve local-only machine state; back up before replacing existing files.
- Do not run destructive syncs over dirty remote dotfiles checkouts.

## Verification

Run focused checks after changes:

```sh
bash -n install.sh sync.sh
git diff --check
```

## Task creation

This repo has no active backlog. If real work queues up, adopt the FHH
task-creation standard (GitHub Issues + triage labels + Sandcastle Issue
Loop): `../fhh-toolkit/knowledge/playbooks/sandcastle-issue-loop.md`. Do not
invent a local ticket or planning system.

## Structure (post-Stow, 2026-06-18)

Dotfile CONTENT is now chezmoi-managed (source: `~/github/fleet-provisioning/home/dot_*`),
not Stow. This repo keeps only `install.sh`'s tool installers + the laptop's wezterm.
Do NOT re-enable Stow in install.sh — it deletes chezmoi's files fleet-wide.
Full agent reference: `fhh-toolkit/knowledge/playbooks/fleet-machine-structure.md`.
