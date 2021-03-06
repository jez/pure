# Pure
# by Sindre Sorhus
# https://github.com/sindresorhus/pure
# MIT License

# For my own and others sanity
# git:
# %a => current action (rebase/merge)
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => shortname host
# %(?..) => prompt conditional - %(condition.true.false)


# turns seconds into human readable time
# 165392 => 1d 21h 56m 32s
prompt_pure_human_time() {
  local tmp=$1
  local days=$(( tmp / 60 / 60 / 24 ))
  local hours=$(( tmp / 60 / 60 % 24 ))
  local minutes=$(( tmp / 60 % 60 ))
  local seconds=$(( tmp % 60 ))
  (( $days > 0 )) && echo -n "${days}d "
  (( $hours > 0 )) && echo -n "${hours}h "
  (( $minutes > 0 )) && echo -n "${minutes}m "
  echo "${seconds}s"
}

# check if untracked files
prompt_pure_any_untracked() {
  return $(git ls-files -o -d --exclude-standard | sed q | wc -l)
}

# fastest possible way to check if repo is dirty
prompt_pure_git_dirty() {
  # check if we're in a git repo
  git rev-parse --is-inside-work-tree &>/dev/null || return

  if [ -n "$PROMPT_PURE_SKIP_DIRTY_CHECK" ] || {
  git diff --quiet $PROMPT_PURE_NO_SUBMODULES HEAD 2> /dev/null && \
    prompt_pure_any_untracked
  }; then
    # green. because %F{green} wouldn't work
    echo -en '\033[0;32m';
  else
    # yellow. because %F{yellow} wouldn't work
    echo -en '\033[0;33m';
  fi
}

prompt_pure_git_branch() {
  # grab the current branch and put parentheses around it
  local branch="$(git branch 2> /dev/null | grep -e "^*" | cut -c 3-)"

  # if there's a branch, wrap it in the correct color and print it
  if [ -n "$branch" ]; then
    echo -en "($branch)"'\033[0m'
  fi
}

# displays the exec time of the last command if set threshold was exceeded
prompt_pure_cmd_exec_time() {
  local stop=$EPOCHSECONDS
  local start=${cmd_timestamp:-$stop}
  integer elapsed=$stop-$start
  (($elapsed > ${PURE_CMD_MAX_EXEC_TIME:=5})) && prompt_pure_human_time $elapsed
}

prompt_pure_preexec() {
  cmd_timestamp=$EPOCHSECONDS

  # shows the current dir and executed command in the title when a process is active
  print -Pn "\e]0;"
  #echo -nE "$PWD:t: $2"
  #echo -nE "$2"
  print -Pn "\a"
}

# string length ignoring ansi escapes
prompt_pure_string_length() {
  echo ${#${(S%%)1//(\%([KF1]|)\{*\}|\%[Bbkf])}}
}

prompt_pure_precmd() {
  # shows the full path in the title
  #print -Pn '\e]0;%~\a'
  print -Pn '\e]0;\a'

  # default colors
  if [ -z "$PROMPT_PURE_DIR_COLOR" ]; then
    PROMPT_PURE_DIR_COLOR="%F{blue}"
  fi
  if [ -z "$PROMPT_PURE_VCS_COLOR" ]; then
    PROMPT_PURE_VCS_COLOR="%F{242}"
  fi
  if [ -z "$PROMPT_PURE_EXEC_TIME_COLOR" ]; then
    PROMPT_PURE_EXEC_TIME_COLOR="%F{yellow}"
  fi

  local prompt_pure_preprompt="\n$PROMPT_PURE_DIR_COLOR%~%f%b $(prompt_pure_git_dirty)$(prompt_pure_git_branch)%f%b $PROMPT_PURE_USERNAME_COLOR$prompt_pure_username%f%b $PROMPT_PURE_EXEC_TIME_COLOR`prompt_pure_cmd_exec_time`%f%b"
  print -P $prompt_pure_preprompt

  # check async if there is anything to pull
  (( ${PURE_GIT_PULL:-1} )) && {
    # check if we're in a git repo
    command git rev-parse --is-inside-work-tree &>/dev/null &&
    # check check if there is anything to pull
    command git fetch &>/dev/null &&
    # check if there is an upstream configured for this branch
    command git rev-parse --abbrev-ref @'{u}' &>/dev/null && {
      local arrows=''
      (( $(command git rev-list --right-only --count HEAD...@'{u}' 2>/dev/null) > 0 )) && arrows='⇣'
      (( $(command git rev-list --left-only --count HEAD...@'{u}' 2>/dev/null) > 0 )) && arrows+='⇡'
      print -Pn "\e7\e[A\e[1G\e[`prompt_pure_string_length $prompt_pure_preprompt`C%F{cyan}${arrows}%f\e8"
    }
  } &!

  # reset value since `preexec` isn't always triggered
  unset cmd_timestamp
}


prompt_pure_setup() {
  # prevent percentage showing up
  # if output doesn't end with a newline
  export PROMPT_EOL_MARK=''

  prompt_opts=(cr subst percent)

  zmodload zsh/datetime
  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info

  add-zsh-hook precmd prompt_pure_precmd
  add-zsh-hook preexec prompt_pure_preexec

  zstyle ':vcs_info:*' enable git

  # show username@host if logged in through SSH
  [[ -n "$SSH_CONNECTION" && -z "$PURE_NO_SSH_USER" ]] && prompt_pure_username='%n@%m '


  # default colors
  if [ -z "$PROMPT_PURE_SUCCESS_COLOR" ]; then
    PROMPT_PURE_SUCCESS_COLOR="%F{magenta}"
  fi
  if [ -z "$PROMPT_PURE_FAILURE_COLOR" ]; then
    PROMPT_PURE_FAILURE_COLOR="%F{red}"
  fi

  # prompt turns red if the previous command didn't exit with 0
  PROMPT="%(?.$PROMPT_PURE_SUCCESS_COLOR.$PROMPT_PURE_FAILURE_COLOR)❯%f%b "
}

prompt_pure_setup "$@"
