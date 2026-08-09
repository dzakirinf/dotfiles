#!/bin/bash
# Claude Code status line
# Reads the JSON payload Claude Code sends on stdin and renders a single
# formatted line with as much of that data as is available.
#
# Deliberately EXCLUDED: 7-day / weekly rate-limit usage & reset time.

input=$(cat)

# ---------------------------------------------------------------------------
# Colors (ANSI). These read fine against Claude Code's dimmed status-line
# rendering; DIM/GRAY are used for the lower-priority fields.
# ---------------------------------------------------------------------------
RESET=$'\033[0m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
MAGENTA=$'\033[35m'
GRAY=$'\033[90m'
BRIGHT=$'\033[97m'
BRIGHT_BLUE=$'\033[94m'
SEP="${GRAY} | ${RESET}"

# ---------------------------------------------------------------------------
# Parse the JSON payload once with python3 (a single fork, vs. one per field
# with jq) and emit shell-quoted variable assignments to eval.
# Only fields the line actually renders are emitted.
# ---------------------------------------------------------------------------
PYSCRIPT=$(cat <<'PYEOF'
import json, sys, shlex

def emit(name, value):
    if value is None:
        value = ""
    print(f"{name}={shlex.quote(str(value))}")

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}

def g(*path, default=""):
    cur = data
    for p in path:
        if isinstance(cur, dict) and p in cur:
            cur = cur[p]
        else:
            return default
    return cur if cur is not None else default

emit("model", g("model", "display_name"))
emit("output_style", g("output_style", "name"))
emit("effort", g("effort", "level"))
emit("thinking", str(g("thinking", "enabled", default=False)).lower())
emit("vim_mode", g("vim", "mode"))
emit("agent_name", g("agent", "name"))

emit("cwd", g("workspace", "current_dir") or g("cwd"))
emit("project_dir", g("workspace", "project_dir"))
added_dirs = g("workspace", "added_dirs", default=[])
emit("added_dirs", ", ".join(added_dirs) if isinstance(added_dirs, list) else added_dirs)
emit("worktree_name", g("worktree", "name") or g("workspace", "git_worktree"))

emit("repo_owner", g("workspace", "repo", "owner"))
emit("repo_name", g("workspace", "repo", "name"))

emit("used_pct", g("context_window", "used_percentage"))

emit("five_pct", g("rate_limits", "five_hour", "used_percentage"))
emit("five_reset", g("rate_limits", "five_hour", "resets_at"))
PYEOF
)
eval "$(printf '%s' "$input" | python3 -c "$PYSCRIPT")"

# Shorten $HOME to ~ for readability.
cwd_disp="$cwd"
project_disp="$project_dir"
if [ -n "$HOME" ]; then
  case "$cwd" in "$HOME"*) cwd_disp="~${cwd#$HOME}" ;; esac
  case "$project_dir" in "$HOME"*) project_disp="~${project_dir#$HOME}" ;; esac
fi

fmt_time() {
  local ts="$1"
  [ -z "$ts" ] && return
  date -d "@$ts" "+%H:%M" 2>/dev/null || date -r "$ts" "+%H:%M" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Git info (live, from the working directory) — locks are skipped so this
# never blocks/contends with a running git operation.
# ---------------------------------------------------------------------------
git_dir="$cwd"
[ -z "$git_dir" ] && git_dir="$project_dir"
branch=""
dirty=""
ahead=""
behind=""
is_git_repo=""
repo_root=""
if [ -n "$git_dir" ] && git -C "$git_dir" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  is_git_repo="1"
  repo_root=$(git -C "$git_dir" --no-optional-locks rev-parse --show-toplevel 2>/dev/null)
  branch=$(git -C "$git_dir" --no-optional-locks branch --show-current 2>/dev/null)
  # Detached HEAD (rebase, bisect, checked-out tag/SHA) has no current branch;
  # fall back to the short SHA so this field is never silently blank.
  if [ -z "$branch" ]; then
    short_sha=$(git -C "$git_dir" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
    [ -n "$short_sha" ] && branch="@${short_sha}"
  fi
  if [ -n "$(git -C "$git_dir" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    dirty="dirty"
  else
    dirty="clean"
  fi
  ab=$(git -C "$git_dir" --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  if [ -n "$ab" ]; then
    behind=$(printf '%s' "$ab" | awk '{print $1}')
    ahead=$(printf '%s' "$ab" | awk '{print $2}')
  fi
fi

# ---------------------------------------------------------------------------
# Assemble the line, piece by piece, skipping anything that isn't present.
# ---------------------------------------------------------------------------
parts=()

# -- Model + effort together, space-separated, no pipe between them --
identity=""
[ -n "$model" ] && identity="${BOLD}${CYAN}${model}${RESET}"
if [ -n "$effort" ]; then
  identity="${identity}${identity:+ }${YELLOW}${effort}${RESET}"
fi
[ -n "$identity" ] && parts+=("$identity")

# -- Style / thinking / vim / agent (secondary, muted) --
if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
  parts+=("${DIM}style:${output_style}${RESET}")
fi
[ "$thinking" = "false" ] && parts+=("${YELLOW}no-think${RESET}")
[ -n "$vim_mode" ] && parts+=("${GREEN}[${vim_mode}]${RESET}")
[ -n "$agent_name" ] && parts+=("${MAGENTA}agent:${agent_name}${RESET}")

# -- Directory (only when not inside a git repo; git line covers that case) / worktree --
if [ -z "$is_git_repo" ]; then
  dir_disp="$cwd_disp"
  if [ -n "$project_disp" ] && [ "$cwd_disp" != "$project_disp" ]; then
    dir_disp="${cwd_disp}${BRIGHT} (root:${project_disp})${RESET}"
  fi
  [ -n "$dir_disp" ] && parts+=("${BRIGHT_BLUE}${dir_disp}${RESET}")
fi
[ -n "$added_dirs" ] && parts+=("${DIM}+dirs:${added_dirs}${RESET}")
[ -n "$worktree_name" ] && parts+=("${DIM}wt:${worktree_name}${RESET}")

# -- Git repo / branch / dirty-clean / ahead-behind / PR --
# workspace.repo is only populated when an origin remote exists, so fall back
# to the working-tree directory name; otherwise a local-only repo renders as a
# bare branch with no indication of which repo it belongs to.
repo_disp=""
if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
  repo_disp="${repo_owner}/${repo_name}"
elif [ -n "$repo_root" ]; then
  repo_disp=$(basename "$repo_root")
fi
git_disp=""
if [ -n "$repo_disp" ] || [ -n "$branch" ]; then
  git_disp="$repo_disp"
  [ -n "$branch" ] && git_disp="${git_disp}${git_disp:+:}${branch}"
  [ -n "$dirty" ] && git_disp="${git_disp} (${dirty})"
  [ -n "$ahead" ] && [ "$ahead" != "0" ] && git_disp="${git_disp} ↑${ahead}"
  [ -n "$behind" ] && [ "$behind" != "0" ] && git_disp="${git_disp} ↓${behind}"
fi
if [ -n "$git_disp" ]; then
  if [ "$dirty" = "dirty" ]; then
    parts+=("${RED}${git_disp}${RESET}")
  else
    parts+=("${GREEN}${git_disp}${RESET}")
  fi
fi

# -- Context window as a bar (muted label, colored fill by usage) --
# used_percentage arrives pre-computed and pre-rounded by Claude Code as
# (input + cache_creation + cache_read) / context_window_size, clamped 0-100.
if [ -n "$used_pct" ]; then
  used_i=$(printf '%.0f' "$used_pct" 2>/dev/null)
  bar_len=10
  filled=$(( (used_i * bar_len + 50) / 100 ))
  [ "$filled" -gt "$bar_len" ] && filled=$bar_len
  [ "$filled" -lt 0 ] && filled=0
  empty=$(( bar_len - filled ))
  bar_color="$GREEN"
  if [ "$used_i" -ge 80 ]; then
    bar_color="$RED"
  elif [ "$used_i" -ge 50 ]; then
    bar_color="$YELLOW"
  fi
  bar=""
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  parts+=("${bar_color}[${bar}]${RESET}${BRIGHT} ${used_i}%${RESET}")
fi
# -- 5-hour rate limit only (7-day intentionally excluded) --
if [ -n "$five_pct" ]; then
  five_i=$(printf '%.0f' "$five_pct" 2>/dev/null)
  reset_hm=$(fmt_time "$five_reset")
  if [ -n "$reset_hm" ]; then
    parts+=("${YELLOW}5h:${five_i}%${RESET}${BRIGHT} (resets ${reset_hm})${RESET}")
  else
    parts+=("${YELLOW}5h:${five_i}%${RESET}")
  fi
fi

# ---------------------------------------------------------------------------
# Join with a muted separator and print.
# ---------------------------------------------------------------------------
output=""
for p in "${parts[@]}"; do
  if [ -z "$output" ]; then
    output="$p"
  else
    output="${output}${SEP}${p}"
  fi
done

printf '%s\n' "$output"
