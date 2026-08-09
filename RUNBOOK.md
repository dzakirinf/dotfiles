# Setup runbook

This runbook tells you how to install these dotfiles on a machine. There are two
procedures. Select the procedure that agrees with the condition of the machine.

Before you start, select the profile for the machine. The three profiles are
personal, work1, and work2. The profile sets the hostname color in the starship
prompt. The profile also controls the work-only Claude skills. An incorrect
profile does not cause damage. To correct the profile, do the init step again.

## Procedure A: the machine does not have the repository

1. Install chezmoi and get the repository.

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init git@github.com:dzakirinff/dotfiles.git
```

The command puts the repository in `~/.local/share/chezmoi`. The command asks
for the profile. The command does not change the files in `$HOME`.

NOTE: If the command cannot connect to GitHub, this machine does not have a key
on the account. Do the procedure in "SSH access". Then do step 1 again.

2. Examine the changes.

```sh
chezmoi diff
```

3. Write the changes to `$HOME`.

```sh
chezmoi apply
```

## Procedure B: the machine has the repository

CAUTION: Obey the sequence of these steps. The file `.chezmoi.toml.tmpl` asks
for the profile. The machine gets this file in step 1. If you do step 4 before
step 2, the hostname color is purple.

1. Get the new files from GitHub.

```sh
chezmoi git pull -- --ff-only
```

2. Set the profile. Replace `work2` with the correct profile.

```sh
chezmoi init --promptString profile=work2
```

The option `--promptString` gives the answer to the prompt. Use the same command
to correct an incorrect profile.

3. Examine the changes.

```sh
chezmoi diff
```

4. Write the changes to `$HOME`.

```sh
chezmoi apply
```

## Steps for the two procedures

Do these steps after the apply step.

The apply step puts the status line script at `~/.claude/statusline-command.sh`.
Claude Code does not use the script until you configure it. The repository does
not contain `~/.claude/settings.json`, because the hooks in that file refer to
internal scripts on work machines. Add this key to that file:

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

NOTE: If Claude Code does not show a status line, replace `~` with the full path
of your home directory. The `~` character is correct only if Claude Code runs
the command in a shell.

The starship configuration needs the starship program. The tracked `.bashrc`
starts starship. You must install the starship program on each machine.

## SSH access

Do this procedure only on a machine that pushes changes to GitHub. A machine
that only receives the dotfiles does not need this procedure.

Give each machine a different key on the GitHub account. If you lose a machine,
you revoke one key. You keep the other keys.

Some machines use a work account as the default GitHub identity. On these
machines, add this alias to `~/.ssh/config`:

```
Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_personal
    IdentitiesOnly yes
```

The line `IdentitiesOnly yes` is necessary. Without this line, ssh sends all
available keys. GitHub can then accept the work key.

Then set the remote to the alias.

```sh
chezmoi cd
git remote set-url origin github-personal:dzakirinff/dotfiles.git
```

A machine that uses the personal account as the default does not need the alias.
On such a machine, use `git@github.com:dzakirinff/dotfiles.git`.

## Verification

Do these three checks after the apply step.

```sh
chezmoi execute-template '{{ .profile }}'
chezmoi diff
chezmoi managed
```

The first command shows the profile of this machine. The second command shows no
output if the files in `$HOME` are the same as the files in the repository. The
third command shows the managed files.

Then open a new shell and examine the hostname color:

- Orange is work1.
- Cyan is work2.
- Purple is personal.

Start Claude Code. The status line must show a model name, the git status, and a
context bar.

## Faults

If `chezmoi diff` shows changes that you do not expect, a person changed the
file in `$HOME` and not in the repository. You have two options:

- `chezmoi apply` replaces the file in `$HOME` with the file from the repository.
- `chezmoi add <path>` copies the file from `$HOME` into the repository.

Select the correct option before you run a command.

If a template error refers to `profile`, the file
`~/.config/chezmoi/chezmoi.toml` is absent or defective. Do step 2 of procedure
B again.
