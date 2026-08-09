# dotfiles

Personal dotfiles, managed with [chezmoi](https://chezmoi.io).

This repo is small on purpose and grows one file at a time. A file belongs here
only if it is the same on every machine and contains nothing secret. If
something needs per-machine values, it gets templated once that need actually
shows up.

## Bootstrap a new machine

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init git@github.com:dzakirinff/dotfiles.git
chezmoi diff      # read this before trusting it
chezmoi apply
```

[RUNBOOK.md](RUNBOOK.md) has the full procedure, including the different steps
for a machine that already has the repo and needs to catch up.

There is no `--apply` on `init` on purpose. Clone and apply in one step and the
first time you see what lands in `$HOME` is after it has already landed.

Two things that will bite otherwise.

The clone URL above is not the one in `git remote -v`. On the work machine the
default GitHub identity is a work account, so pushing this repo needs an
explicit override: a `github-personal` host alias in that machine's
`~/.ssh/config`, pinned with `IdentitiesOnly yes` so it uses the personal key
and nothing else. That alias is local to that machine and only exists because of
the account collision. Every other machine already defaults to the personal
account, so plain `git@github.com:` works.

Each machine also needs its own SSH key on the GitHub account. Then losing one
laptop means revoking one key instead of rotating every key everywhere.

## Machine profiles

`init` asks one question: is this box `personal`, `work1`, or `work2`. The
answer goes into `~/.config/chezmoi/chezmoi.toml`, which stays local and out of
git, and templates read it as `.profile`. Machines identify themselves that way
so the repo never has to name a work hostname to recognise one.

Two things read the profile today. The starship hostname color is orange on
work1, cyan on work2, and purple on personal, so a glance at the prompt says
which box you are typing into. The work-only Claude skills are excluded on
personal machines, where they are useless without the matching Jira and VPN.

Templates fall back to `personal` when the value is missing, so a machine set up
before this existed still renders rather than failing. To set the value on such
a machine without waiting for a prompt:

```sh
chezmoi init --promptString profile=work2
```

Adding a fourth machine means picking a name here and adding one line to
`private_dot_config/starship.toml.tmpl`.

## Day to day

```sh
chezmoi add ~/.config/foo   # start tracking a file
chezmoi diff                # what apply would change
chezmoi apply               # write changes into $HOME
chezmoi cd                  # drop into the source repo to commit and push
```

chezmoi does not commit anything for you. `chezmoi add` only copies a file into
the source directory, which is an ordinary git repo you still have to commit and
push yourself.

## What is tracked

| Target | Notes |
| --- | --- |
| `~/.bashrc` | Identical on every machine, with no work-specific content. |
| `~/.config/starship.toml` | Prompt config, templated. Shows the hostname unconditionally, which is the point when you hop between four boxes, colored by machine profile. |
| `~/.claude/statusline-command.sh` | Claude Code status line. Reads the JSON payload on stdin and prints model, effort, git state, a context-usage bar, and the 5-hour rate limit. |

The status line script is tracked but not switched on. `~/.claude/settings.json`
points hooks at work-only helper scripts, so it stays out of this repo, and a
new machine needs the key added by hand:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

## What is never tracked

`.chezmoiignore` enforces this list, so `chezmoi add` refuses these paths
instead of leaving it to memory.

- Credentials and history: `~/.ssh/`, `~/.aws`, `~/.netrc`, `~/.config/gh`,
  Claude Code's `.credentials.json`, and shell history.
- `~/.gitconfig`, which carries a per-machine email and credential helper. It
  stays out until templating it is worth the trouble.
- Anything naming an employer's internal services, infrastructure, or
  ticketing. Separate machines, separate employers, and none of it belongs in a
  personal repo. `~/.claude/settings.json` falls here: its hook commands point
  at work-only scripts. Claude Code rewrites that file on its own anyway, so
  tracking it would mean a standing diff.
- Hook scripts, plugins, and anything else its own installer rewrites on update.
  Tracking those creates a permanent phantom diff between chezmoi and whatever
  installed them.
- Caches and regenerable state. `~/.claude/projects` alone is ~190MB of session
  transcripts.

`README.md` is ignored too. It is repo documentation, and without an ignore rule
chezmoi would treat it as a file belonging in `$HOME`.
