# dotfiles

Personal dotfiles, managed with [chezmoi](https://chezmoi.io). Per-machine
values get templated.

## Install

On a machine that does not have the repo yet:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init https://github.com/dzakirinf/dotfiles.git
chezmoi diff      # review before applying
chezmoi apply
```

`init` clones into `~/.local/share/chezmoi` and asks three questions.

On a machine that already has the repo, pull and re-run `init` first. Templates
fail on a machine whose `chezmoi.toml` predates the prompts.

```sh
chezmoi git pull -- --ff-only
chezmoi init --promptString profile=work2   # personal, work1 or work2
chezmoi diff
chezmoi apply
```

The answers land in `~/.config/chezmoi/chezmoi.toml`, which is not tracked.

| Value | Prompt | What reads it |
| --- | --- | --- |
| `profile` | `personal`, `work1` or `work2` | Sets the starship hostname color, though the hostname module is currently disabled. |
| `orgAmber` | GitHub owner, blank if none | Gates the amber org bar in starship and the amber dot in the Claude status line. |
| `orgBlue` | GitHub owner, blank if none | Gates the blue org bar and the blue dot. |

Both org names stay machine-local, and are stored rather than derived from the
hostname, so neither an org name nor a work hostname reaches this repo.

`profile` falls back to `personal` when unset. The org values have no fallback,
which is why `init` comes before `apply`.

Apply only writes files. Install starship separately, and add the settings key
below to enable the status line.

Inside `~/orange-repos` or `~/blue-repos` the prompt gains that org's bar.

## Day to day

```sh
chezmoi add ~/.config/foo   # start tracking a file
chezmoi diff                # what apply would change
chezmoi apply               # write changes into $HOME
chezmoi cd                  # drop into the source repo to commit and push
```

chezmoi does not commit. `chezmoi add` copies the file into the source repo;
commit and push from there.

## Tracked

| Target | Notes |
| --- | --- |
| `~/.bashrc` | Not templated. Carries the `az` wrapper, which points `AZURE_CONFIG_DIR` at the profile for the current repo tree, plus `azo` and `azb`, which pin it to one org. |
| `~/.config/starship.toml` | Templated. Org bar first, then the default modules. `[custom.az_warn]` flags an Azure profile that does not match the repo tree. |
| `~/.config/hunk/config.toml` | Not templated. Hunk diff viewer preferences. |
| `~/.claude/statusline-command.sh` | Templated. Reads the JSON payload on stdin and prints model, effort, an org dot, repo and branch with ahead/behind counts, a context-usage bar, and the 5-hour rate limit. |

The status line script is tracked but not enabled: `~/.claude/settings.json`
stays out of this repo because its hooks point at work-only scripts. Add the key
by hand:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

## Never tracked

`.chezmoiignore` enforces most of this. `~/.claude/settings.json` and
`~/.claude/hooks` are still missing from it.

- Credentials and history: `~/.ssh`, `~/.aws`, `~/.azure`, `~/.azure-profiles`,
  `~/.config/gh`, `~/.docker`, `~/.gnupg`, `~/.npmrc`, `~/.terraform.d`,
  `~/.git-credentials`, `~/.netrc`, Claude Code's `.credentials.json` and
  `~/.claude.json`, and shell history.
- Machine-local identity: `~/.config/chezmoi`, which holds the profile and the
  two org names, and `~/.gitconfig`, which carries a per-machine email and
  credential helper.
- Anything naming an employer's internal services, infrastructure, or ticketing,
  including the work-only Claude skills under `~/.claude/skills` and
  `~/.claude/settings.json`.
- Hook scripts, plugins, and anything else its own installer rewrites.
- Caches, and the session archive at `~/.claude/projects`, which grows without
  bound.

## Troubleshooting

If `chezmoi diff` shows unexpected changes, a file was edited in `$HOME` instead
of the repo. Decide which version is right before running `apply` (the repo
wins) or `chezmoi add <path>` (`$HOME` wins).

If a template fails with `map has no entry for key "orgAmber"`, this machine's
`chezmoi.toml` predates the org prompts. Run the `init` line from Install.

If Claude Code shows no status line, replace `~` in the settings command with
the absolute home path; the command is not always run through a shell.
