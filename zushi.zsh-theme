# Zushi - A ZSH theme

# ---------- Config ----------

ZUSHI_PR_CACHE_TTL=${ZUSHI_PR_CACHE_TTL:-300}
ZUSHI_DURATION_THRESHOLD_MS=${ZUSHI_DURATION_THRESHOLD_MS:-300}
ZUSHI_PATH_MAX_DEPTH=${ZUSHI_PATH_MAX_DEPTH:-3}
if [[ -z "$ZUSHI_EDITOR_URL" ]]; then
  if command -v cursor &>/dev/null; then
    ZUSHI_EDITOR_URL='cursor://file%s'
  elif command -v code &>/dev/null; then
    ZUSHI_EDITOR_URL='vscode://file%s'
  elif command -v zed &>/dev/null; then
    ZUSHI_EDITOR_URL='zed://file%s'
  elif command -v idea &>/dev/null || command -v webstorm &>/dev/null; then
    ZUSHI_EDITOR_URL='jetbrains://open?file=%s'
  elif command -v subl &>/dev/null; then
    ZUSHI_EDITOR_URL='subl://open?url=file://%s'
  else
    ZUSHI_EDITOR_URL='file://%s'
  fi
fi
ZUSHI_GREETING=${ZUSHI_GREETING:-$(uname -npsr)}
ZUSHI_GH_ENABLED=${ZUSHI_GH_ENABLED:-1}

# ---------- Colors ----------

_zushi_purple='%B%F{#8957e5}'
_zushi_orange='%B%F{#ee5819}'
_zushi_yellow='%B%F{#b58900}'
_zushi_red='%B%F{#d30102}'
_zushi_green='%B%F{#859900}'
_zushi_cyan='%B%F{#2aa198}'
_zushi_white='%B%F{#fdf6e3}'
_zushi_gray='%B%F{#4f4f4f}'
_zushi_reset='%f%b'

# ---------- Links (OSC 8) ----------

_zushi_link_open=$'%{\e]8;;'
_zushi_link_mid=$'\e\\%}'
_zushi_link_close=$'%{\e]8;;\e\\%}'

# ---------- Icons ----------

_zushi_icon_dot='•'
_zushi_icon_eol='⏎'
_zushi_icon_duration='%{⏱️%2G%}'
_zushi_icon_pr='🔗'
_zushi_icon_repo='🐙'
_zushi_icon_worktree='🌳'
_zushi_icon_folder='%{🗂️%2G%}'
_zushi_icon_macos='⌘'
_zushi_icon_linux='λ'

# ---------- Helpers ----------

_zushi_truncate_path() {
  local path="$1" prefix=''
  if [[ "$path" == /* ]]; then
    prefix='/'
    path="${path#/}"
  fi
  local segs=("${(@s:/:)path}")
  local n=${#segs[@]}
  if [[ $n -gt $ZUSHI_PATH_MAX_DEPTH ]]; then
    local keep=$(( ZUSHI_PATH_MAX_DEPTH - 1 ))
    echo "${prefix}${(j:/:)segs[1,$keep]}/.../${segs[$n]}"
  else
    echo "${prefix}${path}"
  fi
}

# ---------- Command timer ----------

_zushi_preexec() {
  _zushi_cmd_start=$EPOCHREALTIME
}

# ---------- Build prompt (called before each prompt) ----------

_zushi_precmd() {
  local exit_code=$?

  # Capture and clear duration in parent shell
  _zushi_elapsed=''
  if [[ -n $_zushi_cmd_start ]]; then
    local elapsed_raw=$(( EPOCHREALTIME - _zushi_cmd_start ))
    local elapsed_ms=$(( ${elapsed_raw%.*} * 1000 + ${${elapsed_raw#*.}:0:3} ))
    unset _zushi_cmd_start
    if [[ $elapsed_ms -ge $ZUSHI_DURATION_THRESHOLD_MS ]]; then
      _zushi_elapsed=$elapsed_raw
    fi
  fi

  # Cache git state
  _zushi_is_repo=0
  _zushi_branch=''
  _zushi_on_branch=0
  _zushi_is_dirty=0
  _zushi_is_staged=0
  _zushi_is_stashed=0
  _zushi_has_untracked=0
  _zushi_root_folder=''
  _zushi_main_root=''
  _zushi_detached_ref=''
  _zushi_upstream=''
  _zushi_ahead=0
  _zushi_behind=0

  local rev_parse_output
  rev_parse_output=$(command git rev-parse --git-dir --show-toplevel --path-format=absolute --git-common-dir 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    local rev_parse_lines=("${(@f)rev_parse_output}")
    _zushi_root_folder="${rev_parse_lines[2]}"
    _zushi_main_root="${rev_parse_lines[3]%/.git}"
    _zushi_is_repo=1

    local status_output
    status_output=$(command git status --porcelain=v2 --branch 2>/dev/null)

    # Parse branch info
    local head_line=${(M)${(f)status_output}:#\# branch.head *}
    local head_name=${head_line#\# branch.head }
    if [[ "$head_name" == "(detached)" ]]; then
      _zushi_on_branch=0
      _zushi_detached_ref=$(command git show-ref --head --abbrev | awk '{print substr($0,1,7)}' | head -n1)
    else
      _zushi_on_branch=1
      _zushi_branch="$head_name"
    fi

    # Parse upstream
    local upstream_line=${(M)${(f)status_output}:#\# branch.upstream *}
    _zushi_upstream=${upstream_line#\# branch.upstream }

    # Parse ahead/behind
    local ab_line=${(M)${(f)status_output}:#\# branch.ab *}
    if [[ -n "$ab_line" ]]; then
      _zushi_ahead=${${ab_line#\# branch.ab +}%% *}
      _zushi_behind=${${ab_line##* -}%% *}
    fi

    # Parse file statuses
    local line
    for line in ${(f)status_output}; do
      case "$line" in
        \?\ *) _zushi_has_untracked=1 ;;
        1\ [MTADRC][MTADRCU]\ *|2\ [MTADRC][MTADRCU]\ *) _zushi_is_staged=1; _zushi_is_dirty=1 ;;
        1\ [MTADRC].\ *|2\ [MTADRC].\ *) _zushi_is_staged=1 ;;
        1\ .[MTADRCU]\ *|2\ .[MTADRCU]\ *) _zushi_is_dirty=1 ;;
      esac
      [[ $_zushi_is_dirty -eq 1 && $_zushi_is_staged -eq 1 && $_zushi_has_untracked -eq 1 ]] && break
    done

    # Stash
    command git rev-parse --verify --quiet refs/stash &>/dev/null && _zushi_is_stashed=1
  fi

  # Cache PR info per branch with TTL
  if [[ $_zushi_gh_available -eq 1 && $_zushi_is_repo -eq 1 && $_zushi_on_branch -eq 1 ]]; then
    local pr_age=$(( EPOCHSECONDS - ${_zushi_pr_timestamp:-0} ))
    if [[ "$_zushi_branch" != "$_zushi_pr_branch" || $pr_age -ge $ZUSHI_PR_CACHE_TTL ]]; then
      _zushi_pr_branch="$_zushi_branch"
      _zushi_pr_timestamp=$EPOCHSECONDS
      _zushi_pr_info=''
      local result
      if result=$(command gh pr view --json number,url,state,isDraft --jq '"#\(.number) \(.url) \(.state) \(.isDraft)"' 2>/dev/null); then
        _zushi_pr_info="$result"
      fi
    fi
  else
    _zushi_pr_branch=''
    _zushi_pr_info=''
  fi

  local prompt_parts=()

  # SSH indicator
  if [[ -n "$SSH_CLIENT" ]]; then
    prompt_parts+="${_zushi_red}(${_zushi_cyan}${_zushi_ssh_user}${_zushi_red}:${_zushi_cyan}${_zushi_ssh_host}${_zushi_red}) ${_zushi_reset}"
  fi

  # Git info
  if [[ $_zushi_is_repo -eq 1 ]]; then
    if [[ $_zushi_is_stashed -eq 1 ]]; then
      prompt_parts+="${_zushi_orange}${_zushi_icon_dot}${_zushi_reset}"
    else
      prompt_parts+=" "
    fi

    if [[ $_zushi_is_staged -eq 1 && ( $_zushi_is_dirty -eq 1 || $_zushi_has_untracked -eq 1 ) ]]; then
      prompt_parts+="${_zushi_yellow}${_zushi_icon_dot}${_zushi_reset}"
    elif [[ $_zushi_is_dirty -eq 1 ]]; then
      prompt_parts+="${_zushi_white}${_zushi_icon_dot}${_zushi_reset}"
    elif [[ $_zushi_is_staged -eq 1 ]]; then
      prompt_parts+="${_zushi_green}${_zushi_icon_dot}${_zushi_reset}"
    elif [[ $_zushi_has_untracked -eq 1 ]]; then
      prompt_parts+="${_zushi_gray}${_zushi_icon_dot}${_zushi_reset}"
    else
      prompt_parts+=" "
    fi
    prompt_parts+=" "

    if [[ $_zushi_on_branch -eq 1 ]]; then
      prompt_parts+="${_zushi_yellow}${_zushi_branch}${_zushi_reset}"
    else
      prompt_parts+="${_zushi_gray}${_zushi_detached_ref}${_zushi_reset}"
    fi

    if [[ $_zushi_ahead -gt 0 || $_zushi_behind -gt 0 ]] && [[ "$_zushi_upstream" != */"${_zushi_branch}" ]]; then
      prompt_parts+=" ${_zushi_orange}${_zushi_upstream}${_zushi_reset}"
    fi
    [[ $_zushi_ahead -gt 0 ]] && prompt_parts+="${_zushi_white} +${_zushi_ahead}${_zushi_reset}"
    [[ $_zushi_behind -gt 0 ]] && prompt_parts+="${_zushi_white} -${_zushi_behind}${_zushi_reset}"

    prompt_parts+=" "
  fi

  # Prompt symbol
  if [[ $exit_code -eq 0 ]]; then
    prompt_parts+="${_zushi_red}${_zushi_symbol} ${_zushi_reset}"
  else
    prompt_parts+="${_zushi_gray}${_zushi_symbol} ${_zushi_reset}"
  fi

  PROMPT="${(j..)prompt_parts}"

  # --- Right prompt ---
  local rparts=()

  # Duration
  if [[ -n $_zushi_elapsed ]]; then
    local elapsed_int=${_zushi_elapsed%.*}
    local elapsed_frac=${_zushi_elapsed#*.}
    local dur
    if [[ $elapsed_int -ge 3600 ]]; then
      dur="$(( elapsed_int / 3600 ))h$(( (elapsed_int % 3600) / 60 ))m$(( elapsed_int % 60 ))s"
    elif [[ $elapsed_int -ge 60 ]]; then
      dur="$(( elapsed_int / 60 ))m$(( elapsed_int % 60 ))s"
    elif [[ $elapsed_int -ge 1 ]]; then
      dur="${elapsed_int}.${elapsed_frac:0:1}s"
    else
      dur="$(( ${elapsed_frac:0:3} ))ms"
    fi
    rparts+="${_zushi_icon_duration} ${_zushi_orange}${dur}${_zushi_reset}"
  fi

  # PR info
  if [[ -n "$_zushi_pr_info" ]]; then
    local pr_parts=("${(@s: :)_zushi_pr_info}")
    local pr_color="$_zushi_cyan"
    case "${pr_parts[3]}" in
      MERGED) pr_color="$_zushi_purple" ;;
      CLOSED) pr_color="$_zushi_red" ;;
      *) [[ "${pr_parts[4]}" == "true" ]] && pr_color="$_zushi_gray" ;;
    esac
    rparts+="${_zushi_icon_pr} ${_zushi_link_open}${pr_parts[2]}${_zushi_link_mid}${pr_color}${pr_parts[1]}${_zushi_reset}${_zushi_link_close}"
  fi

  # Current directory
  if [[ $_zushi_is_repo -eq 1 ]]; then
    local real_pwd=${PWD:A}
    local root_name="${_zushi_root_folder##*/}"
    local subdir="${real_pwd#${_zushi_root_folder:A}}"
    local icon="$_zushi_icon_repo"
    [[ "$_zushi_root_folder" != "$_zushi_main_root" ]] && icon="$_zushi_icon_worktree"

    local editor_url="${ZUSHI_EDITOR_URL/\%s/$_zushi_root_folder}"

    local cwd_part="${icon} ${_zushi_link_open}${editor_url}${_zushi_link_mid}${_zushi_yellow}${root_name}${_zushi_reset}${_zushi_link_close}"
    if [[ -n "$subdir" ]]; then
      cwd_part+="${_zushi_gray}${_zushi_link_open}file://${real_pwd}${_zushi_link_mid}$(_zushi_truncate_path "$subdir")${_zushi_reset}${_zushi_link_close}"
    fi
    rparts+="$cwd_part"
  else
    local cwd="${PWD/#$HOME/~}"
    cwd=$(_zushi_truncate_path "$cwd")
    rparts+="${_zushi_icon_folder} ${_zushi_link_open}file://${PWD}${_zushi_link_mid}${_zushi_gray}${cwd}${_zushi_reset}${_zushi_link_close}"
  fi

  RPROMPT="${(j. .)rparts}"
}

# ---------- Greeting ----------

_zushi_greeting() {
  [[ -n "$ZUSHI_GREETING" ]] && print -P "${_zushi_gray}${ZUSHI_GREETING}${_zushi_reset}"
}

# ---------- Setup ----------

setopt PROMPT_SUBST
PROMPT_EOL_MARK="${_zushi_gray}${_zushi_icon_eol}${_zushi_reset}"
zmodload zsh/datetime
autoload -Uz add-zsh-hook
add-zsh-hook preexec _zushi_preexec
add-zsh-hook precmd _zushi_precmd

if [[ -n "$SSH_CLIENT" ]]; then
  _zushi_ssh_user=$(whoami)
  _zushi_ssh_host=$(hostname -s)
fi

_zushi_gh_available=0
if [[ $ZUSHI_GH_ENABLED -eq 1 ]] && command -v gh &>/dev/null && command gh auth status &>/dev/null; then
  _zushi_gh_available=1
fi

case "$(uname -s)" in
  Darwin) _zushi_symbol="$_zushi_icon_macos" ;;
  *)      _zushi_symbol="$_zushi_icon_linux" ;;
esac

_zushi_greeting
