#!/bin/env sh

# exit the script if any statement returns a non-true return value
set -e

unset GREP_OPTIONS
export LC_NUMERIC=C
# shellcheck disable=SC3041
if (set +H 2>/dev/null); then
  set +H
fi

if ! printf '' | sed -E 's///' 2>/dev/null; then
  if printf '' | sed -r 's///' 2>/dev/null; then
    sed() {
      n=$#
      while [ "$n" -gt 0 ]; do
        arg=$1
        shift
        case $arg in -E*) arg=-r${arg#-E} ;; esac
        set -- "$@" "$arg"
        n=$((n - 1))
      done
      command sed "$@"
    }
  fi
fi

_uname_s=$(uname -s)

[ -z "$TMUX" ] && exit 255
if [ -z "$TMUX_SOCKET" ]; then
  TMUX_SOCKET=$(printf '%s' "$TMUX" | cut -d, -f1)
fi
if [ -z "$TMUX_PROGRAM" ]; then
  TMUX_PID=$(printf '%s' "$TMUX" | cut -d, -f2)
  TMUX_PROGRAM=$(lsof -b -w -a -d txt -p "$TMUX_PID" -Fn 2>/dev/null | perl -n -e "if (s/^n((?:.(?!dylib$|so$))+)$/\1/g) { print; exit } } exit 1; {" || readlink "/proc/$TMUX_PID/exe" 2>/dev/null || printf tmux)
fi
if [ "$TMUX_PROGRAM" = "tmux" ]; then
  tmux() {
    command tmux ${TMUX_SOCKET:+-S "$TMUX_SOCKET"} "$@"
  }
else
  tmux() {
    "$TMUX_PROGRAM" ${TMUX_SOCKET:+-S "$TMUX_SOCKET"} "$@"
  }
fi

_tmux_version=$(tmux -V | awk '{gsub(/[^0-9.]/, "", $2); print ($2+0) * 100}')

_is_true() {
  [ "$1" = "true" ] || [ "$1" = "yes" ] || [ "$1" = "1" ]
}

_is_enabled() {
  [ "$1" = "enabled" ]
}

_is_disabled() {
  [ "$1" = "disabled" ]
}

_circled() {
  circled_digits='⓪ ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩ ⑪ ⑫ ⑬ ⑭ ⑮ ⑯ ⑰ ⑱ ⑲ ⑳'
  if [ "$1" -le 20 ] 2>/dev/null; then
    i=$(($1 + 1))
    eval set -- "$circled_digits"
    eval echo "\${$i}"
  else
    echo "$1"
  fi
}

_decode_unicode_escapes() {
  printf '%s' "$*" | perl -CS -pe 's/(\\u([0-9A-Fa-f]{1,4})|\\U([0-9A-Fa-f]{1,8}))/chr(hex($2.$3))/eg' 2>/dev/null
}

if command -v pkill >/dev/null 2>&1; then
  _pkillf() {
    pkill -f "$@" || true
  }
else
  case "$_uname_s" in
  *CYGWIN*)
    _pkillf() {
      while IFS= read -r pid; do
        kill "$pid" || true
      done <<EOF
$(grep -Eao "$@" /proc/*/cmdline | xargs -0 | sed -E -n 's,/proc/([0-9]+)/.+$,\1,pg')
EOF
    }
    ;;
  *)
    # shellcheck disable=SC2009
    _pkillf() {
      while IFS= read -r pid; do
        kill "$pid" || true
      done <<EOF
$(ps -x -o pid= -o command= | grep -E "$@" | cut -d' ' -f1)
EOF
    }
    ;;
  esac
fi

_toggle_mouse() {
  old=$(tmux show -gv mouse)
  new=""

  if [ "$old" = "on" ]; then
    new="off"
  else
    new="on"
  fi

  tmux set -g mouse $new
}

_pane_info() {
  pane_pid="$1"
  pane_tty="${2##/dev/}"
  case "$_uname_s" in
  *CYGWIN*)
    ps -al | tail -n +2 | awk -v pane_pid="$pane_pid" -v tty="$pane_tty" '
        ((/ssh/ && !/-W/) || !/ssh/) && !/tee/ && $5 == tty {
          user[$1] = $6; if (!child[$2]) child[$2] = $1
        }
        END {
          pid = pane_pid
          while (child[pid])
            pid = child[pid]

          file = "/proc/" pid "/cmdline"; getline command < file; close(file)
          gsub(/\0/, " ", command)
          "id -un " user[pid] | getline username
          print pid":"username":"command
        }
      '
    ;;
  *Linux*)
    ps -t "$pane_tty" --sort=lstart -o user=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX -o pid= -o ppid= -o command= | awk -v pane_pid="$pane_pid" '
        ((/ssh/ && !/-W/) || !/ssh/) && !/tee/ {
          user[$2] = $1; if (!child[$3]) child[$3] = $2; pid=$2; $1 = $2 = $3 = ""; command[pid] = substr($0,4)
        }
        END {
          pid = pane_pid
          while (child[pid])
            pid = child[pid]

          print pid":"user[pid]":"command[pid]
        }
      '
    ;;
  *)
    ps -t "$pane_tty" -o user=XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX -o pid= -o ppid= -o command= | awk -v pane_pid="$pane_pid" '
        ((/ssh/ && !/-W/) || !/ssh/) && !/tee/ {
          user[$2] = $1; if (!child[$3]) child[$3] = $2; pid=$2; $1 = $2 = $3 = ""; command[pid] = substr($0,4)
        }
        END {
          pid = pane_pid
          while (child[pid])
            pid = child[pid]

          print pid":"user[pid]":"command[pid]
        }
      '
    ;;
  esac
}

_ssh_or_mosh_args() {
  case "$1" in
  *ssh*)
    args=$(printf '%s' "$1" | perl -n -e 'print if s/.*?\bssh[\w_-]*\s*(.*)/\1/')
    ;;
  *mosh-client*)
    args=$(printf '%s' "$1" | sed -E -e 's/.*mosh-client -# (.*)\|.*$/\1/' -e 's/-[^ ]*//g' -e 's/\d:\d//g')
    ;;
  esac

  printf '%s' "$args"
}

_username() {
  pane_pid=${1:-$(tmux display -p '#{pane_pid}')}
  pane_tty=${2:-$(tmux display -p '#{b:pane_tty}')}
  ssh_only=$3

  pane_info=$(_pane_info "$pane_pid" "$pane_tty")
  command=${pane_info#*:}
  command=${command#*:}

  ssh_or_mosh_args=$(_ssh_or_mosh_args "$command")
  if [ -n "$ssh_or_mosh_args" ]; then
    # shellcheck disable=SC2086
    username=$(ssh -G $ssh_or_mosh_args 2>/dev/null | awk '/^user / { print $2; exit }')
    # shellcheck disable=SC2086
    [ -z "$username" ] && username=$(ssh $ssh_or_mosh_args -T -o ControlPath=none -o ProxyCommand="sh -c 'echo %%username%% %r >&2'" 2>&1 | awk '/^%username% / { print $2; exit }')
    # shellcheck disable=SC2086
    [ -z "$username" ] && username=$(ssh $ssh_or_mosh_args -v -T -o ControlPath=none -o ProxyCommand=false -o IdentityFile='%%username%%/%r' 2>&1 | awk '/%username%/ { print substr($4,12); exit }')
  else
    if ! _is_true "$ssh_only"; then
      username=${pane_info#*:}
      username=${username%%:*}
    fi
  fi

  printf '%s\n' "$username"
}

_hostname() {
  pane_pid=${1:-$(tmux display -p '#{pane_pid}')}
  pane_tty=${2:-$(tmux display -p '#{b:pane_tty}')}
  ssh_only=$3
  full=$4
  h_or_H=$5

  pane_info=$(_pane_info "$pane_pid" "$pane_tty")
  command=${pane_info#*:}
  command=${command#*:}

  ssh_or_mosh_args=$(_ssh_or_mosh_args "$command")
  if [ -n "$ssh_or_mosh_args" ]; then
    # shellcheck disable=SC2086
    hostname=$(ssh -G $ssh_or_mosh_args 2>/dev/null | awk '/^hostname / { print $2; exit }')
    # shellcheck disable=SC2086
    [ -z "$hostname" ] && hostname=$(ssh -T -o ControlPath=none -o ProxyCommand="sh -c 'echo %%hostname%% %h >&2'" $ssh_or_mosh_args 2>&1 | awk '/^%hostname% / { print $2; exit }')

    if ! _is_true "$full"; then
      case "$hostname" in
      *[a-z-].*)
        hostname=${hostname%%.*}
        ;;
      127.0.0.1)
        hostname="localhost"
        ;;
      esac
    fi
  else
    if ! _is_true "$ssh_only"; then
      hostname="$h_or_H"
    fi
  fi

  printf '%s\n' "$hostname"
}

_root() {
  pane_pid=${1:-$(tmux display -p '#{pane_pid}')}
  pane_tty=${2:-$(tmux display -p '#{b:pane_tty}')}
  root=$3

  username=$(_username "$pane_pid" "$pane_tty" false)

  [ "$username" = "root" ] && echo "$root"
}

_uptime() {
  case "$_uname_s" in
  *Darwin* | *FreeBSD*)
    boot=$(sysctl -q -n kern.boottime | awk -F'[ ,:]+' '{ print $4 }')
    now=$(date +%s)
    ;;
  *Linux* | *CYGWIN* | *MSYS* | *MINGW*)
    boot=0
    now=$(cut -d' ' -f1 </proc/uptime)
    ;;
  *OpenBSD*)
    boot=$(sysctl -n kern.boottime)
    now=$(date +%s)
    ;;
  esac
  # shellcheck disable=SC1004
  awk -v tmux="$TMUX_PROGRAM ${TMUX_SOCKET:+-S "$TMUX_SOCKET"}" -v boot="$boot" -v now="$now" '
    BEGIN {
      uptime = now - boot
      y = int(uptime / 31536000)
      dy = int(uptime / 86400) % 365
      d = int(uptime / 86400)
      h = int(uptime / 3600) % 24
      m = int(uptime / 60) % 60
      s = int(uptime) % 60

      system(tmux " set -g @uptime_y " y + 0    " \\;" \
                  " set -g @uptime_dy " dy + 0  " \\;" \
                  " set -g @uptime_d " d + 0    " \\;" \
                  " set -g @uptime_h " h + 0    " \\;" \
                  " set -g @uptime_m " m + 0    " \\;" \
                  " set -g @uptime_s " s + 0)
    }'
}

_apply_tmux_256color() {
  case "$(tmux show -gv default-terminal)" in
  tmux-256color | tmux-direct)
    return
    ;;
  esac

  # when tmux-256color is available, use it
  # on macOS though, make sure to use /usr/bin/infocmp to probe if it's availalbe system wide
  case "$_uname_s" in
  *Darwin*)
    if /usr/bin/infocmp -x tmux-256color >/dev/null 2>&1; then
      tmux set -g default-terminal 'tmux-256color'
    fi
    ;;
  *)
    if command infocmp -x tmux-256color >/dev/null 2>&1; then
      tmux set -g default-terminal 'tmux-256color'
    fi
    ;;
  esac
}

_apply_24b() {
  tmux_conf_theme_24b_colour=${tmux_conf_theme_24b_colour:-auto}
  tmux_conf_24b_colour=${tmux_conf_24b_colour:-$tmux_conf_theme_24b_colour}
  if [ "$tmux_conf_24b_colour" = "auto" ]; then
    case "$COLORTERM" in
    truecolor | 24bit)
      apply_24b=true
      ;;
    esac
    if [ "$apply_24b" = "" ] && [ "$(tput colors)" = "16777216" ]; then
      apply_24b=true
    fi
  elif _is_true "$tmux_conf_24b_colour"; then
    apply_24b=true
  fi
  if [ "$apply_24b" = "true" ]; then
    case "$TERM" in
    screen-* | tmux-*) ;;
    *)
      tmux set-option -ga terminal-overrides ",*256col*:Tc"
      ;;
    esac
  fi
}

_apply_bindings() {
  tmux_conf_new_window_retain_current_path=${tmux_conf_new_window_retain_current_path:-true}
  if ! _is_disabled "$tmux_conf_new_window_retain_current_path" && _is_true "$tmux_conf_new_window_retain_current_path"; then
    tmux bind -T prefix c new-window -c "#{pane_current_path}"
  # else keep the default setting in `tmux.conf`
  fi

  tmux_conf_new_pane_retain_current_path=${tmux_conf_new_pane_retain_current_path:-true}
  if ! _is_disabled "$tmux_conf_new_pane_retain_current_path" && _is_true "$tmux_conf_new_pane_retain_current_path"; then
    tmux bind -T prefix - split-window -v -c "#{pane_current_path}"
    tmux bind -T prefix _ split-window -h -c "#{pane_current_path}"
  # else keep the default setting in `tmux.conf`
  fi

  tmux_conf_new_session_prompt=${tmux_conf_new_session_prompt:-false}
  if ! _is_disabled "$tmux_conf_new_session_prompt" && _is_true "$tmux_conf_new_session_prompt"; then
    tmux bind -T prefix C-c command-prompt -p new-session "new-session -s \"%%\""
  else
    tmux bind -T prefix C-c new-session
  fi

  tmux_conf_copy_to_os_clipboard=${tmux_conf_copy_to_os_clipboard:-false}
  [ -z "$command" ] && command -v xsel >/dev/null 2>&1 && command='xsel -i -b'
  [ -z "$command" ] && command -v xclip >/dev/null 2>&1 && command='xclip -i -selection clipboard > \/dev\/null 2>\&1'
  [ -z "$command" ] && command -v wl-copy >/dev/null 2>&1 && command='wl-copy'
  [ -z "$command" ] && command -v pbcopy >/dev/null 2>&1 && command='pbcopy'
  [ -z "$command" ] && command -v reattach-to-user-namespace >/dev/null 2>&1 && command='reattach-to-user-namespace pbcopy'
  [ -z "$command" ] && command -v clip.exe >/dev/null 2>&1 && command='clip\.exe'
  [ -z "$command" ] && [ -c /dev/clipboard ] && command='cat > \/dev\/clipboard'

  if [ -n "$command" ]; then
    if ! _is_disabled "$tmux_conf_copy_to_os_clipboard" && _is_true "$tmux_conf_copy_to_os_clipboard"; then
      if [ "$_tmux_version" -lt 260 ]; then
        tmux set -s set-clipboard on
      else
        tmux set -s set-clipboard external
      fi
      if [ "$_tmux_version" -ge 320 ]; then
        tmux set -s copy-command "$command"
      fi
      tmux bind -T copy-mode y send -X copy-pipe-and-cancel "$command"
      tmux bind -T copy-mode MouseDragEnd1Pane send -X copy-pipe-and-cancel "$command"
      tmux bind -T copy-mode-vi y send -X copy-pipe-and-cancel "$command"
      tmux bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "$command"
    else
      tmux set -s set-clipboard off
    fi
  fi
}

_apply_theme() {
  tmux_conf_theme=${tmux_conf_theme:-enabled}
  if ! _is_disabled "$tmux_conf_theme"; then

    # -- panes ---------------------------------------------------------------

    tmux_conf_theme_window_fg=${tmux_conf_theme_window_fg:-default}
    tmux_conf_theme_window_bg=${tmux_conf_theme_window_bg:-default}
    tmux_conf_theme_highlight_focused_pane=${tmux_conf_theme_highlight_focused_pane:-false}
    tmux_conf_theme_focused_pane_fg=${tmux_conf_theme_focused_pane_fg:-default}
    tmux_conf_theme_focused_pane_bg=${tmux_conf_theme_focused_pane_bg:-$tmux_conf_theme_colour_2}

    window_style="fg=$tmux_conf_theme_window_fg,bg=$tmux_conf_theme_window_bg"
    if _is_true "$tmux_conf_theme_highlight_focused_pane"; then
      window_active_style="fg=$tmux_conf_theme_focused_pane_fg,bg=$tmux_conf_theme_focused_pane_bg"
    else
      window_active_style="default"
    fi

    tmux_conf_theme_pane_border_style=${tmux_conf_theme_pane_border_style:-thin}
    tmux_conf_theme_pane_border=${tmux_conf_theme_pane_border:-$tmux_conf_theme_colour_2}
    tmux_conf_theme_pane_active_border=${tmux_conf_theme_pane_active_border:-$tmux_conf_theme_colour_4}
    tmux_conf_theme_pane_border_fg=${tmux_conf_theme_pane_border_fg:-$tmux_conf_theme_pane_border}
    tmux_conf_theme_pane_active_border_fg=${tmux_conf_theme_pane_active_border_fg:-$tmux_conf_theme_pane_active_border}
    case "$tmux_conf_theme_pane_border_style" in
    fat)
      tmux_conf_theme_pane_border_bg=${tmux_conf_theme_pane_border_bg:-$tmux_conf_theme_pane_border_fg}
      tmux_conf_theme_pane_active_border_bg=${tmux_conf_theme_pane_active_border_bg:-$tmux_conf_theme_pane_active_border_fg}
      ;;
    thin | *)
      tmux_conf_theme_pane_border_bg=${tmux_conf_theme_pane_border_bg:-default}
      tmux_conf_theme_pane_active_border_bg=${tmux_conf_theme_pane_active_border_bg:-default}
      ;;
    esac

    tmux_conf_theme_pane_indicator=${tmux_conf_theme_pane_indicator:-$tmux_conf_theme_colour_4}
    tmux_conf_theme_pane_active_indicator=${tmux_conf_theme_pane_active_indicator:-$tmux_conf_theme_colour_4}

    # -- status line ---------------------------------------------------------

    tmux_conf_theme_left_separator_main=$(_decode_unicode_escapes "${tmux_conf_theme_left_separator_main-}")
    tmux_conf_theme_left_separator_sub=$(_decode_unicode_escapes "${tmux_conf_theme_left_separator_sub-|}")
    tmux_conf_theme_right_separator_main=$(_decode_unicode_escapes "${tmux_conf_theme_right_separator_main-}")
    tmux_conf_theme_right_separator_sub=$(_decode_unicode_escapes "${tmux_conf_theme_right_separator_sub-|}")

    tmux_conf_theme_message_fg=${tmux_conf_theme_message_fg:-$tmux_conf_theme_colour_1}
    tmux_conf_theme_message_bg=${tmux_conf_theme_message_bg:-$tmux_conf_theme_colour_5}
    tmux_conf_theme_message_attr=${tmux_conf_theme_message_attr:-bold}

    tmux_conf_theme_message_command_fg=${tmux_conf_theme_message_command_fg:-$tmux_conf_theme_colour_5}
    tmux_conf_theme_message_command_bg=${tmux_conf_theme_message_command_bg:-$tmux_conf_theme_colour_1}
    tmux_conf_theme_message_command_attr=${tmux_conf_theme_message_command_attr:-bold}

    tmux_conf_theme_mode_fg=${tmux_conf_theme_mode_fg:-$tmux_conf_theme_colour_1}
    tmux_conf_theme_mode_bg=${tmux_conf_theme_mode_bg:-$tmux_conf_theme_colour_5}
    tmux_conf_theme_mode_attr=${tmux_conf_theme_mode_attr:-bold}

    tmux_conf_theme_status_fg=${tmux_conf_theme_status_fg:-$tmux_conf_theme_colour_3}
    tmux_conf_theme_status_bg=${tmux_conf_theme_status_bg:-$tmux_conf_theme_colour_1}
    tmux_conf_theme_status_attr=${tmux_conf_theme_status_attr:-none}

    tmux_conf_theme_terminal_title=${tmux_conf_theme_terminal_title:-#h ❐ #S ● #I #W}

    tmux_conf_theme_window_status_fg=${tmux_conf_theme_window_status_fg:-$tmux_conf_theme_colour_3}
    tmux_conf_theme_window_status_bg=${tmux_conf_theme_window_status_bg:-$tmux_conf_theme_colour_1}
    tmux_conf_theme_window_status_attr=${tmux_conf_theme_window_status_attr:-none}
    tmux_conf_theme_window_status_format=${tmux_conf_theme_window_status_format:-'#I #W#{?#{||:#{window_bell_flag},#{window_zoomed_flag}}, ,}#{?window_bell_flag,!,}#{?window_zoomed_flag,Z,}'}

    tmux_conf_theme_window_status_current_fg=${tmux_conf_theme_window_status_current_fg:-$tmux_conf_theme_colour_1}
    tmux_conf_theme_window_status_current_bg=${tmux_conf_theme_window_status_current_bg:-$tmux_conf_theme_colour_4}
    tmux_conf_theme_window_status_current_attr=${tmux_conf_theme_window_status_current_attr:-bold}
    tmux_conf_theme_window_status_current_format=${tmux_conf_theme_window_status_current_format:-'#I #W#{?#{||:#{window_bell_flag},#{window_zoomed_flag}}, ,}#{?window_bell_flag,!,}#{?window_zoomed_flag,Z,}'}

    tmux_conf_theme_window_status_activity_fg=${tmux_conf_theme_window_status_activity_fg:-default}
    tmux_conf_theme_window_status_activity_bg=${tmux_conf_theme_window_status_activity_bg:-default}
    tmux_conf_theme_window_status_activity_attr=${tmux_conf_theme_window_status_activity_attr:-underscore}

    tmux_conf_theme_window_status_bell_fg=${tmux_conf_theme_window_status_bell_fg:-$tmux_conf_theme_colour_5}
    tmux_conf_theme_window_status_bell_bg=${tmux_conf_theme_window_status_bell_bg:-default}
    tmux_conf_theme_window_status_bell_attr=${tmux_conf_theme_window_status_bell_attr:-blink,bold}

    tmux_conf_theme_window_status_last_fg=${tmux_conf_theme_window_status_last_fg:-$tmux_conf_theme_colour_4}
    tmux_conf_theme_window_status_last_bg=${tmux_conf_theme_window_status_last_bg:-default}
    tmux_conf_theme_window_status_last_attr=${tmux_conf_theme_window_status_last_attr:-none}

    if [ "$tmux_conf_theme_window_status_bg" = "$tmux_conf_theme_status_bg" ] || [ "$tmux_conf_theme_window_status_bg" = "default" ]; then
      spacer=''
      spacer_current=' '
    else
      spacer=' '
      spacer_current=' '
    fi
    if [ "$tmux_conf_theme_window_status_last_bg" = "$tmux_conf_theme_status_bg" ] || [ "$tmux_conf_theme_window_status_last_bg" = "default" ]; then
      spacer_last=''
    else
      spacer_last=' '
    fi
    if [ "$tmux_conf_theme_window_status_activity_bg" = "$tmux_conf_theme_status_bg" ] || [ "$tmux_conf_theme_window_status_activity_bg" = "default" ]; then
      spacer_activity=''
      spacer_last_activity="$spacer_last"
    else
      spacer_activity=' '
      spacer_last_activity=' '
    fi
    if [ "$tmux_conf_theme_window_status_bell_bg" = "$tmux_conf_theme_status_bg" ] || [ "$tmux_conf_theme_window_status_bell_bg" = "default" ]; then
      spacer_bell=''
      spacer_last_bell="$spacer_last"
      spacer_activity_bell="$spacer_activity"
      spacer_last_activity_bell="$spacer_last_activity"
    else
      spacer_bell=' '
      spacer_last_bell=' '
      spacer_activity_bell=' '
      spacer_last_activity_bell=' '
    fi
    spacer="#{?window_last_flag,#{?window_activity_flag,#{?window_bell_flag,$spacer_last_activity_bell,$spacer_last_activity},#{?window_bell_flag,$spacer_last_bell,$spacer_last}},#{?window_activity_flag,#{?window_bell_flag,$spacer_activity_bell,$spacer_activity},#{?window_bell_flag,$spacer_bell,$spacer}}}"
    if [ "$(tmux show -g -v status-justify)" = "right" ]; then
      if [ -z "$tmux_conf_theme_right_separator_main" ]; then
        window_status_separator=' '
      else
        window_status_separator=''
      fi
      window_status_format="#[fg=$tmux_conf_theme_window_status_bg,bg=$tmux_conf_theme_status_bg,none]#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_bg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_bg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_bg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}$tmux_conf_theme_right_separator_main#[fg=$tmux_conf_theme_window_status_fg,bg=$tmux_conf_theme_window_status_bg,$tmux_conf_theme_window_status_attr]#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_fg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_fg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_fg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}$spacer$(printf '%s' "$tmux_conf_theme_window_status_last_attr" | perl -n -e 'print "#{?window_last_flag,#[none],}" if !/default/ ; s/([a-z]+),?/#{?window_last_flag,#[\1],}/g; print if !/default/')$(printf '%s' "$tmux_conf_theme_window_status_activity_attr" | perl -n -e 'print "#{?window_activity_flag?,#[none],}" if !/default/ ; s/([a-z]+),?/#{?window_activity_flag,#[\1],}/g; print if !/default/')$(printf '%s' "$tmux_conf_theme_window_status_bell_attr" | perl -n -e 'print "#{?window_bell_flag,#[none],}" if !/default/ ; s/([a-z]+),?/#{?window_bell_flag,#[\1],}/g; print if !/default/')$tmux_conf_theme_window_status_format#[none]$spacer#[fg=$tmux_conf_theme_status_bg,bg=$tmux_conf_theme_window_status_bg]#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#[none]$tmux_conf_theme_right_separator_main"
      window_status_current_format="#[fg=$tmux_conf_theme_window_status_current_bg,bg=$tmux_conf_theme_status_bg,none]$tmux_conf_theme_right_separator_main#[fg=$tmux_conf_theme_window_status_current_fg,bg=$tmux_conf_theme_window_status_current_bg,$tmux_conf_theme_window_status_current_attr]$spacer_current$tmux_conf_theme_window_status_current_format$spacer_current#[fg=$tmux_conf_theme_status_bg,bg=$tmux_conf_theme_window_status_current_bg,none]$tmux_conf_theme_right_separator_main"
    else
      if [ -z "$tmux_conf_theme_left_separator_main" ]; then
        window_status_separator=' '
      else
        window_status_separator=''
      fi
      window_status_format="#[fg=$tmux_conf_theme_status_bg,bg=$tmux_conf_theme_window_status_bg,none]#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}$tmux_conf_theme_left_separator_main#[fg=$tmux_conf_theme_window_status_fg,bg=$tmux_conf_theme_window_status_bg,$tmux_conf_theme_window_status_attr]#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_fg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_fg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_fg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_bg" | perl -n -e "s/.+/#[bg=$&]/; print if !/default/"),}$spacer$(printf '%s' "$tmux_conf_theme_window_status_last_attr" | perl -n -e 'print "#{?window_last_flag,#[none],}" if !/default/ ; s/([a-z]+),?/#{?window_last_flag,#[\1],}/g; print if !/default/')$(printf '%s' "$tmux_conf_theme_window_status_activity_attr" | perl -n -e 'print "#{?window_activity_flag,#[none],}" if !/default/ ; s/([a-z]+),?/#{?window_activity_flag,#[\1],}/g; print if !/default/')$(printf '%s' "$tmux_conf_theme_window_status_bell_attr" | perl -n -e 'print "#{?window_bell_flag,#[none],}" if /!default/ ; s/([a-z]+),?/#{?window_bell_flag,#[\1],}/g; print if !/default/')$tmux_conf_theme_window_status_format#[none]$spacer#[fg=$tmux_conf_theme_window_status_bg,bg=$tmux_conf_theme_status_bg]#{?window_last_flag,$(printf '%s' "$tmux_conf_theme_window_status_last_bg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_activity_flag,$(printf '%s' "$tmux_conf_theme_window_status_activity_bg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}#{?window_bell_flag,$(printf '%s' "$tmux_conf_theme_window_status_bell_bg" | perl -n -e "s/.+/#[fg=$&]/; print if !/default/"),}$tmux_conf_theme_left_separator_main"
      window_status_current_format="#[fg=$tmux_conf_theme_status_bg,bg=$tmux_conf_theme_window_status_current_bg,none]$tmux_conf_theme_left_separator_main#[fg=$tmux_conf_theme_window_status_current_fg,bg=$tmux_conf_theme_window_status_current_bg,$tmux_conf_theme_window_status_current_attr]$spacer_current$tmux_conf_theme_window_status_current_format$spacer_current#[fg=$tmux_conf_theme_window_status_current_bg,bg=$tmux_conf_theme_status_bg]$tmux_conf_theme_left_separator_main"
    fi

    # -- indicators

    tmux_conf_theme_pairing=${tmux_conf_theme_pairing:-⚇} # U+2687
    tmux_conf_theme_pairing_fg=${tmux_conf_theme_pairing_fg:-none}
    tmux_conf_theme_pairing_bg=${tmux_conf_theme_pairing_bg:-none}
    tmux_conf_theme_pairing_attr=${tmux_conf_theme_pairing_attr:-none}

    tmux_conf_theme_prefix=${tmux_conf_theme_prefix:-⌨} # U+2328
    tmux_conf_theme_prefix_fg=${tmux_conf_theme_prefix_fg:-none}
    tmux_conf_theme_prefix_bg=${tmux_conf_theme_prefix_bg:-none}
    tmux_conf_theme_prefix_attr=${tmux_conf_theme_prefix_attr:-none}

    tmux_conf_theme_mouse=${tmux_conf_theme_mouse:-↗} # U+2197
    tmux_conf_theme_mouse_fg=${tmux_conf_theme_mouse_fg:-none}
    tmux_conf_theme_mouse_bg=${tmux_conf_theme_mouse_bg:-none}
    tmux_conf_theme_mouse_attr=${tmux_conf_theme_mouse_attr:-none}

    tmux_conf_theme_root=${tmux_conf_theme_root:-!}
    tmux_conf_theme_root_fg=${tmux_conf_theme_root_fg:-none}
    tmux_conf_theme_root_bg=${tmux_conf_theme_root_bg:-none}
    tmux_conf_theme_root_attr=${tmux_conf_theme_root_attr:-bold,blink}

    tmux_conf_theme_synchronized=${tmux_conf_theme_synchronized:-⚏} # U+268F
    tmux_conf_theme_synchronized_fg=${tmux_conf_theme_synchronized_fg:-none}
    tmux_conf_theme_synchronized_bg=${tmux_conf_theme_synchronized_bg:-none}
    tmux_conf_theme_synchronized_attr=${tmux_conf_theme_synchronized_attr:-none}

    # -- status-left style

    tmux_conf_theme_status_left=${tmux_conf_theme_status_left-' ❐ #S | 🟢#{?uptime_y, #{uptime_y}y,}#{?uptime_d, #{uptime_d}d,}#{?uptime_h, #{uptime_h}h,}#{?uptime_m, #{uptime_m}m,} '}
    tmux_conf_theme_status_left_fg=${tmux_conf_theme_status_left_fg:-$tmux_conf_theme_colour_6,$tmux_conf_theme_colour_7,$tmux_conf_theme_colour_8}
    tmux_conf_theme_status_left_bg=${tmux_conf_theme_status_left_bg:-$tmux_conf_theme_colour_9,$tmux_conf_theme_colour_10,$tmux_conf_theme_colour_11}
    tmux_conf_theme_status_left_attr=${tmux_conf_theme_status_left_attr:-bold,none,none}

    if [ -n "$tmux_conf_theme_status_left" ]; then
      status_left=$(echo "$tmux_conf_theme_status_left" | sed \
        -e "s/#{pairing}/#[fg=$tmux_conf_theme_pairing_fg]#[bg=$tmux_conf_theme_pairing_bg]#[$tmux_conf_theme_pairing_attr]#{pairing}/g" \
        -e "s/#{prefix}/#[fg=$tmux_conf_theme_prefix_fg]#[bg=$tmux_conf_theme_prefix_bg]#[$tmux_conf_theme_prefix_attr]#{prefix}/g" \
        -e "s/#{mouse}/#[fg=$tmux_conf_theme_mouse_fg]#[bg=$tmux_conf_theme_mouse_bg]#[$tmux_conf_theme_mouse_attr]#{mouse}/g" \
        -e "s%#{synchronized}%#[fg=$tmux_conf_theme_synchronized_fg]#[bg=$tmux_conf_theme_synchronized_bg]#[$tmux_conf_theme_synchronized_attr]#{synchronized}%g" \
        -e "s%#{root}%#[fg=$tmux_conf_theme_root_fg]#[bg=$tmux_conf_theme_root_bg]#[$tmux_conf_theme_root_attr]#{root}#[inherit]%g")

      status_left=$(printf '%s' "$status_left" | awk \
        -v status_bg="$tmux_conf_theme_status_bg" \
        -v fg_="$tmux_conf_theme_status_left_fg" \
        -v bg_="$tmux_conf_theme_status_left_bg" \
        -v attr_="$tmux_conf_theme_status_left_attr" \
        -v mainsep="$tmux_conf_theme_left_separator_main" \
        -v subsep="$tmux_conf_theme_left_separator_sub" '
        function subsplit(s, l, i, a, r)
        {
          l = split(s, a, ",")
          for (i = 1; i <= l; ++i)
          {
            o = split(a[i], _, "(") - 1
            c = split(a[i], _, ")") - 1
            open += o - c
            o_ = split(a[i], _, "{") - 1
            c_ = split(a[i], _, "}") - 1
            open_ += o_ - c_
            o__ = split(a[i], _, "[") - 1
            c__ = split(a[i], _, "]") - 1
            open__ += o__ - c__

            if (i == l)
              r = sprintf("%s%s", r, a[i])
            else if (open || open_ || open__)
              r = sprintf("%s%s,", r, a[i])
            else
              r = sprintf("%s%s#[fg=%s,bg=%s,%s]%s", r, a[i], fg[j], bg[j], attr[j], subsep)
          }

          gsub(/#\[inherit\]/, sprintf("#[default]#[fg=%s,bg=%s,%s]", fg[j], bg[j], attr[j]), r)
          return r
        }
        BEGIN {
          FS = "|"
          l1 = split(fg_, fg, ",")
          l2 = split(bg_, bg, ",")
          l3 = split(attr_, attr, ",")
          l = l1 < l2 ? (l1 < l3 ? l1 : l3) : (l2 < l3 ? l2 : l3)
        }
        {
          for (i = j = 1; i <= NF; ++i)
          {
            if (open || open_ || open__)
              printf "|%s", subsplit($i)
            else
            {
              if (i > 1)
                printf "#[fg=%s,bg=%s,none]%s#[fg=%s,bg=%s,%s]%s", bg[j_], bg[j], mainsep, fg[j], bg[j], attr[j], subsplit($i)
              else
                printf "#[fg=%s,bg=%s,%s]%s", fg[j], bg[j], attr[j], subsplit($i)
            }

            if (!open && !open_ && !open__)
            {
              j_ = j
              j = j % l + 1
            }
          }
          printf "#[fg=%s,bg=%s,none]%s", bg[j_], status_bg, mainsep
        }')
    fi
    status_left="$status_left "

    # -- status-right style

    tmux_conf_theme_status_right=${tmux_conf_theme_status_right-' #{prefix}#{mouse}#{pairing}#{synchronized}, %R , %d %b | #{username}#{root} | #{hostname} '}
    tmux_conf_theme_status_right_fg=${tmux_conf_theme_status_right_fg:-$tmux_conf_theme_colour_12,$tmux_conf_theme_colour_13,$tmux_conf_theme_colour_14}
    tmux_conf_theme_status_right_bg=${tmux_conf_theme_status_right_bg:-$tmux_conf_theme_colour_15,$tmux_conf_theme_colour_16,$tmux_conf_theme_colour_17}
    tmux_conf_theme_status_right_attr=${tmux_conf_theme_status_right_attr:-none,none,bold}

    if [ -n "$tmux_conf_theme_status_right" ]; then
      status_right=$(echo "$tmux_conf_theme_status_right" | sed \
        -e "s/#{pairing}/#[fg=$tmux_conf_theme_pairing_fg]#[bg=$tmux_conf_theme_pairing_bg]#[$tmux_conf_theme_pairing_attr]#{pairing}/g" \
        -e "s/#{prefix}/#[fg=$tmux_conf_theme_prefix_fg]#[bg=$tmux_conf_theme_prefix_bg]#[$tmux_conf_theme_prefix_attr]#{prefix}/g" \
        -e "s/#{mouse}/#[fg=$tmux_conf_theme_mouse_fg]#[bg=$tmux_conf_theme_mouse_bg]#[$tmux_conf_theme_mouse_attr]#{mouse}/g" \
        -e "s%#{synchronized}%#[fg=$tmux_conf_theme_synchronized_fg]#[bg=$tmux_conf_theme_synchronized_bg]#[$tmux_conf_theme_synchronized_attr]#{synchronized}%g" \
        -e "s%#{root}%#[fg=$tmux_conf_theme_root_fg]#[bg=$tmux_conf_theme_root_bg]#[$tmux_conf_theme_root_attr]#{root}#[inherit]%g")

      status_right=$(printf '%s' "$status_right" | awk \
        -v status_bg="$tmux_conf_theme_status_bg" \
        -v fg_="$tmux_conf_theme_status_right_fg" \
        -v bg_="$tmux_conf_theme_status_right_bg" \
        -v attr_="$tmux_conf_theme_status_right_attr" \
        -v mainsep="$tmux_conf_theme_right_separator_main" \
        -v subsep="$tmux_conf_theme_right_separator_sub" '
        function subsplit(s, l, i, a, r)
        {
          l = split(s, a, ",")
          for (i = 1; i <= l; ++i)
          {
            o = split(a[i], _, "(") - 1
            c = split(a[i], _, ")") - 1
            open += o - c
            o_ = split(a[i], _, "{") - 1
            c_ = split(a[i], _, "}") - 1
            open_ += o_ - c_
            o__ = split(a[i], _, "[") - 1
            c__ = split(a[i], _, "]") - 1
            open__ += o__ - c__

            if (i == l)
              r = sprintf("%s%s", r, a[i])
            else if (open || open_ || open__)
              r = sprintf("%s%s,", r, a[i])
            else
              r = sprintf("%s%s#[fg=%s,bg=%s,%s]%s", r, a[i], fg[j], bg[j], attr[j], subsep)
          }

          gsub(/#\[inherit\]/, sprintf("#[default]#[fg=%s,bg=%s,%s]", fg[j], bg[j], attr[j]), r)
          return r
        }
        BEGIN {
          FS = "|"
          l1 = split(fg_, fg, ",")
          l2 = split(bg_, bg, ",")
          l3 = split(attr_, attr, ",")
          l = l1 < l2 ? (l1 < l3 ? l1 : l3) : (l2 < l3 ? l2 : l3)
        }
        {
          for (i = j = 1; i <= NF; ++i)
          {
            if (open_ || open || open__)
              printf "|%s", subsplit($i)
            else
              printf "#[fg=%s,bg=%s,none]%s#[fg=%s,bg=%s,%s]%s", bg[j], (i == 1) ? status_bg : bg[j_], mainsep, fg[j], bg[j], attr[j], subsplit($i)

            if (!open && !open_ && !open__)
            {
              j_ = j
              j = j % l + 1
            }
          }
        }')
    fi
    status_right=${status_right-}

    tmux setw -g window-style "$window_style" \; \
      setw -g window-active-style "$window_active_style" \; \
      setw -g pane-border-style "fg=$tmux_conf_theme_pane_border_fg,bg=$tmux_conf_theme_pane_border_bg" \; \
      set -g pane-active-border-style "fg=$tmux_conf_theme_pane_active_border_fg,bg=$tmux_conf_theme_pane_active_border_bg" \; \
      set -g display-panes-colour "$tmux_conf_theme_pane_indicator" \; \
      set -g display-panes-active-colour "$tmux_conf_theme_pane_active_indicator" \; \
      set -g message-style "fg=$tmux_conf_theme_message_fg,bg=$tmux_conf_theme_message_bg,$tmux_conf_theme_message_attr" \; \
      set -g message-command-style "fg=$tmux_conf_theme_message_command_fg,bg=$tmux_conf_theme_message_command_bg,$tmux_conf_theme_message_command_attr" \; \
      setw -g mode-style "fg=$tmux_conf_theme_mode_fg,bg=$tmux_conf_theme_mode_bg,$tmux_conf_theme_mode_attr" \; \
      set -g status-style "fg=$tmux_conf_theme_status_fg,bg=$tmux_conf_theme_status_bg,$tmux_conf_theme_status_attr" \; \
      set -g status-left-style "fg=$tmux_conf_theme_status_fg,bg=$tmux_conf_theme_status_bg,$tmux_conf_theme_status_attr" \; \
      set -g status-right-style "fg=$tmux_conf_theme_status_fg,bg=$tmux_conf_theme_status_bg,$tmux_conf_theme_status_attr" \; \
      setw -g window-status-style "fg=$tmux_conf_theme_window_status_fg,bg=$tmux_conf_theme_window_status_bg,$tmux_conf_theme_window_status_attr" \; \
      setw -g window-status-current-style "fg=$tmux_conf_theme_window_status_current_fg,bg=$tmux_conf_theme_window_status_current_bg,$tmux_conf_theme_window_status_current_attr" \; \
      setw -g window-status-activity-style "fg=$tmux_conf_theme_window_status_activity_fg,bg=$tmux_conf_theme_window_status_activity_bg,$tmux_conf_theme_window_status_activity_attr" \; \
      setw -g window-status-bell-style "fg=$tmux_conf_theme_window_status_bell_fg,bg=$tmux_conf_theme_window_status_bell_bg,$tmux_conf_theme_window_status_bell_attr" \; \
      setw -g window-status-last-style "fg=$tmux_conf_theme_window_status_last_fg,bg=$tmux_conf_theme_window_status_last_bg,$tmux_conf_theme_window_status_last_attr" \; \
      setw -g window-status-separator "$window_status_separator"
  fi

  # -- variables -------------------------------------------------------------
  set_titles_string=$(printf '%s' "${tmux_conf_theme_terminal_title:-$(tmux show -gv set-titles-string)}" | sed \
    -e "s%#{circled_window_index}%#(sh '$OH_MY_TMUX' _circled '#I')%g" \
    -e "s%#{circled_session_name}%#(sh '$OH_MY_TMUX' _circled '#S')%g" \
    -e "s%#{username}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' false '#D')%g" \
    -e "s%#{hostname}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false false '#h' '#D')%g" \
    -e "s%#{hostname_full}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false true '#H' '#D')%g" \
    -e "s%#{username_ssh}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' true '#D')%g" \
    -e "s%#{hostname_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true false '#h' '#D')%g" \
    -e "s%#{hostname_full_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true true '#H' '#D')%g")

  window_status_format=$(printf '%s' "${window_status_format:-$(tmux show -gv window-status-format)}" | sed \
    -e "s%#{circled_window_index}%#(sh '$OH_MY_TMUX' _circled '#I')%g" \
    -e "s%#{circled_session_name}%#(sh '$OH_MY_TMUX' _circled '#S')%g" \
    -e "s%#{username}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' false '#D')%g" \
    -e "s%#{hostname}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false false '#h' '#D')%g" \
    -e "s%#{hostname_full}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false true '#H' '#D')%g" \
    -e "s%#{username_ssh}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' true '#D')%g" \
    -e "s%#{hostname_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true false '#h' '#D')%g" \
    -e "s%#{hostname_full_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true true '#H' '#D')%g")

  window_status_current_format=$(printf '%s' "${window_status_current_format:-$(tmux show -gv window-status-current-format)}" | sed \
    -e "s%#{circled_window_index}%#(sh '$OH_MY_TMUX' _circled '#I')%g" \
    -e "s%#{circled_session_name}%#(sh '$OH_MY_TMUX' _circled '#S')%g" \
    -e "s%#{username}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' false '#D')%g" \
    -e "s%#{hostname}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false false '#h' '#D')%g" \
    -e "s%#{hostname_full}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false true '#H' '#D')%g" \
    -e "s%#{username_ssh}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' true '#D')%g" \
    -e "s%#{hostname_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true false '#h' '#D')%g" \
    -e "s%#{hostname_full_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true true '#H' '#D')%g")

  status_left=$(printf '%s' "${status_left-$(tmux show -gv status-left)}" | sed \
    -e "s/#{pairing}/#{?session_many_attached,$tmux_conf_theme_pairing,}/g" \
    -e "s/#{prefix}/#{?client_prefix,$tmux_conf_theme_prefix,}/g" \
    -e "s/#{mouse}/#{?mouse,$tmux_conf_theme_mouse,}/g" \
    -e "s%#{synchronized}%#{?pane_synchronized,$tmux_conf_theme_synchronized,}%g" \
    -e "s%#{circled_session_name}%#(sh '$OH_MY_TMUX' _circled '#S')%g" \
    -e "s%#{root}%#{?#{==:#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' '#D'),root},$tmux_conf_theme_root,}%g")

  status_right=$(printf '%s' "${status_right-$(tmux show -gv status-right)}" | sed \
    -e "s/#{pairing}/#{?session_many_attached,$tmux_conf_theme_pairing,}/g" \
    -e "s/#{prefix}/#{?client_prefix,$tmux_conf_theme_prefix,}/g" \
    -e "s/#{mouse}/#{?mouse,$tmux_conf_theme_mouse,}/g" \
    -e "s%#{synchronized}%#{?pane_synchronized,$tmux_conf_theme_synchronized,}%g" \
    -e "s%#{circled_session_name}%#(sh '$OH_MY_TMUX' _circled '#S')%g" \
    -e "s%#{root}%#{?#{==:#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' '#D'),root},$tmux_conf_theme_root,}%g")

  case "$status_left $status_right" in
  *'#{username}'* | *'#{hostname}'* | *'#{hostname_full}'* | *'#{username_ssh}'* | *'#{hostname_ssh}'* | *'#{hostname_full_ssh}'*)
    status_left=$(echo "$status_left" | sed \
      -e "s%#{username}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' false '#D')%g" \
      -e "s%#{hostname}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false false '#h' '#D')%g" \
      -e "s%#{hostname_full}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false true '#H' '#D')%g" \
      -e "s%#{username_ssh}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' true '#D')%g" \
      -e "s%#{hostname_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true false '#h' '#D')%g" \
      -e "s%#{hostname_full_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true true '#H' '#D')%g")
    status_right=$(echo "$status_right" | sed \
      -e "s%#{username}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' false '#D')%g" \
      -e "s%#{hostname}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false false '#h' '#D')%g" \
      -e "s%#{hostname_full}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' false true '#H' '#D')%g" \
      -e "s%#{username_ssh}%#(sh '$OH_MY_TMUX' _username '#{pane_pid}' '#{b:pane_tty}' true '#D')%g" \
      -e "s%#{hostname_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true false '#h' '#D')%g" \
      -e "s%#{hostname_full_ssh}%#(sh '$OH_MY_TMUX' _hostname '#{pane_pid}' '#{b:pane_tty}' true true '#H' '#D')%g")
    ;;
  esac

  _pkillf "sh '$OH_MY_TMUX' _uptime"
  case "$status_left $status_right" in
  *'#{uptime_'* | *'#{?uptime_'*)
    status_left=$(echo "$status_left" | perl -p -e '
        ; s/#\{(\?)?uptime_y\b/#\{\1\@uptime_y/g
        ; s/#\{(\?)?uptime_d\b/#\{\1\@uptime_d/g
        ; s/\@uptime_d\b/\@uptime_dy/g if /\@uptime_y\b/
        ; s/#\{(\?)?uptime_h\b/#\{\1\@uptime_h/g
        ; s/#\{(\?)?uptime_m\b/#\{\1\@uptime_m/g
        ; s/#\{(\?)?uptime_s\b/#\{\1\@uptime_s/g')
    status_right=$(echo "$status_right" | perl -p -e '
        ; s/#\{(\?)?uptime_y\b/#\{\1\@uptime_y/g
        ; s/#\{(\?)?uptime_d\b/#\{\1\@uptime_d/g
        ; s/\@uptime_d\b/\@uptime_dy/g if /\@uptime_y\b/
        ; s/#\{(\?)?uptime_h\b/#\{\1\@uptime_h/g
        ; s/#\{(\?)?uptime_m\b/#\{\1\@uptime_m/g
        ; s/#\{(\?)?uptime_s\b/#\{\1\@uptime_s/g')
    interval=60
    case "$status_left $status_right" in
    *'#{@uptime_s}'*)
      interval=$(tmux show -gv status-interval)
      ;;
    esac
    if [ "$_tmux_version" -ge 320 ]; then
      tmux run -b "trap '[ -n \"\$sleep_pid\" ] && kill -9 \"\$sleep_pid\"; exit 0' TERM; while [ x\"\$('$TMUX_PROGRAM' -S '#{socket_path}' display -p '#{l:#{pid}}')\" = x\"#{pid}\" ]; do nice sh '$OH_MY_TMUX' _uptime; sleep $interval & sleep_pid=\$!; wait \"\$sleep_pid\"; sleep_pid=; done"
    elif [ "$_tmux_version" -ge 280 ]; then
      status_right="#(echo; while [ x\"\$('$TMUX_PROGRAM' -S '#{socket_path}' display -p '#{l:#{pid}}')\" = x\"#{pid}\" ]; do nice sh '$OH_MY_TMUX' _uptime; sleep $interval; done)$status_right"
    elif [ "$_tmux_version" -gt 240 ]; then
      status_right="#(echo; while :; do nice sh '$OH_MY_TMUX' _uptime; sleep $interval; done)$status_right"
    else
      status_right="#(nice sh '$OH_MY_TMUX' _uptime)$status_right"
    fi
    ;;
  esac

  # --------------------------------------------------------------------------
  tmux set -g set-titles-string "$(_decode_unicode_escapes "$set_titles_string")" \; \
    setw -g window-status-format "$(_decode_unicode_escapes "$window_status_format")" \; \
    setw -g window-status-current-format "$(_decode_unicode_escapes "$window_status_current_format")" \; \
    set -g status-left-length 1000 \; \
    set -g status-left "$(_decode_unicode_escapes "$status_left")" \; \
    set -g status-right-length 1000 \; \
    set -g status-right "$(_decode_unicode_escapes "$status_right")"
}

__apply_plugins() {
  window_active="$1"
  tmux_conf_update_plugins_on_launch="$2"
  tmux_conf_update_plugins_on_reload="$3"
  tmux_conf_uninstall_plugins_on_reload="$4"

  if [ -z "$TMUX_PLUGIN_MANAGER_PATH" ]; then
    return 255
  fi
  mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"

  tpm_plugins=$(tmux show -gvq '@tpm_plugins' 2>/dev/null)
  if [ -z "$(tmux show -gv '@plugin' 2>/dev/null)" ] && [ -z "$tpm_plugins" ]; then
    if _is_true "$tmux_conf_uninstall_plugins_on_reload" && [ -d "$TMUX_PLUGIN_MANAGER_PATH/tpm" ]; then
      tmux display 'Uninstalling tpm and plugins...'
      rm -rf "$TMUX_PLUGIN_MANAGER_PATH"
      tmux display 'Done uninstalling tpm and plugins...'
    fi
  else
    if [ "$(command tmux display -p '#{pid} #{version} #{socket_path}')" = "$($TMUX_PROGRAM display -p '#{pid} #{version} #{socket_path}')" ]; then
      tpm_plugins=$(
        cat <<EOF | tr ' ' '\n' | awk '/^\s*$/ {next;}; !seen[$0]++ { gsub(/^[ \t]+/,"",$0); gsub(/[ \t]+$/,"",$0); print $0 }'
        $(awk '/^[ \t]*set(-option)?.*[ \t]@plugin[ \t]/ { gsub(/'\''/, ""); gsub(/'\"'/, ""); print $NF }' "$TMUX_CONF_LOCAL" 2>/dev/null)
EOF
      )
      tmux set -g '@tpm_plugins' "$tpm_plugins"
      if git ls-remote -hq https://github.com/gpakosz/.tmux.git master >/dev/null; then
        if [ ! -d "$TMUX_PLUGIN_MANAGER_PATH/tpm" ]; then
          install_tpm=true
          tmux display 'Installing tpm and plugins...'
          git clone --depth 1 https://github.com/tmux-plugins/tpm "$TMUX_PLUGIN_MANAGER_PATH/tpm"
        elif { [ -z "$window_active" ] && _is_true "$tmux_conf_update_plugins_on_launch"; } || { [ -n "$window_active" ] && _is_true "$tmux_conf_update_plugins_on_reload"; }; then
          update_tpm=true
          tmux display 'Updating tpm and plugins...'
          (cd "$TMUX_PLUGIN_MANAGER_PATH/tpm" && git fetch -q -p && git checkout -q master && git reset -q --hard origin/master)
        fi
        if [ "$install_tpm" = "true" ] || [ "$update_tpm" = "true" ]; then
          perl -0777 -p -i -e 's/git clone(?!\s+--depth\s+1)/git clone --depth 1/g
                              ;s/(install_plugin(.(?!&))*)\n(\s+)done/\1&\n\3done\n\3wait/g' "$TMUX_PLUGIN_MANAGER_PATH/tpm/scripts/install_plugins.sh"
          perl -p -i -e 's/git submodule update --init --recursive(?!\s+--depth\s+1)/git submodule update --init --recursive --depth 1/g' "$TMUX_PLUGIN_MANAGER_PATH/tpm/scripts/update_plugin.sh"
          perl -p -i -e 's,\$tmux_file\s+>/dev/null\s+2>\&1,$& || { tmux display "Plugin \$(basename \${plugin_path}) failed" && false; },' "$TMUX_PLUGIN_MANAGER_PATH/tpm/scripts/source_plugins.sh"
        fi
        if [ "$update_tpm" = "true" ]; then
          {
            echo "Invoking $TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins ..." >"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              "$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins" >>"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              echo "Invoking $TMUX_PLUGIN_MANAGER_PATH/tpm/bin/update_plugins all ..." >"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              "$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/update_plugins" all >>"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              echo "Invoking $TMUX_PLUGIN_MANAGER_PATH/tpm/bin/clean_plugins all ..." >"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              "$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/clean_plugins" all >>"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              tmux display 'Done updating tpm and plugins...'
          } || tmux display 'Failed updating tpm and plugins...'
        elif [ "$install_tpm" = "true" ]; then
          {
            echo "Invoking $TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins ..." >"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1 &&
              "$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins" >>"$TMUX_PLUGIN_MANAGER_PATH/tpm_log.txt" 2>&1
            tmux display 'Done installing tpm and plugins...'
          } || tmux display 'Failed installing tpm and plugins...'
        fi
      else
        tmux display "GitHub doesn't seem to be reachable, skipping installing and/or updating tpm and plugins..."
      fi

      [ -z "$(tmux show -gqv '@tpm-install')" ] && tmux set -g '@tpm-install' 'I'
      [ -z "$(tmux show -gqv '@tpm-update')" ] && tmux set -g '@tpm-update' 'u'
      [ -z "$(tmux show -gqv '@tpm-clean')" ] && tmux set -g '@tpm-clean' 'M-u'
      "$TMUX_PLUGIN_MANAGER_PATH/tpm/tpm" || tmux display "One or more tpm plugin(s) failed"
    else
      tmux run -b "sleep \$((#{display-time} / 1000)) && '$TMUX_PROGRAM' set display-time 3000 \; display 'Cannot use tpm which assumes a globally installed tmux' \; set -u display-time"
    fi

    if [ "$_tmux_version" -gt 260 ]; then
      tmux set -gu '@tpm-install' \; set -gu '@tpm-update' \; set -gu '@tpm-clean' \; set -gu '@plugin'
    else
      tmux set -g '@tpm-install' '' \; set -g '@tpm-update' '' \; set -g '@tpm-clean' '' \; set -g '@plugin' ''
    fi
  fi
}

_apply_plugins() {
  tmux_conf_update_plugins_on_launch=${tmux_conf_update_plugins_on_launch:-true}
  tmux_conf_update_plugins_on_reload=${tmux_conf_update_plugins_on_reload:-true}
  tmux_conf_uninstall_plugins_on_reload=${tmux_conf_uninstall_plugins_on_reload:-true}

  tpm_plugins=$(tmux show -gvq '@tpm_plugins' 2>/dev/null)
  if [ -n "$(tmux show -gv '@plugin' 2>/dev/null)" ] || [ -n "$tpm_plugins" ]; then
    if [ -z "$TMUX_PLUGIN_MANAGER_PATH" ]; then
      if [ "$(dirname "$TMUX_CONF")" = "$HOME" ]; then
        TMUX_PLUGIN_MANAGER_PATH="$HOME/.tmux/plugins"
      else
        TMUX_PLUGIN_MANAGER_PATH="$(dirname "$TMUX_CONF")/plugins"
      fi
      tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$TMUX_PLUGIN_MANAGER_PATH"
    fi
    tmux run -b "sh '$OH_MY_TMUX' __apply_plugins '$window_active' '$tmux_conf_update_plugins_on_launch' '$tmux_conf_update_plugins_on_reload' '$tmux_conf_uninstall_plugins_on_reload'"
  fi
}

_apply_configuration() {
  window_active="$(tmux display -p '#{window_active}' 2>/dev/null || true)"
  if [ -z "$window_active" ]; then
    if ! command -v perl >/dev/null 2>&1; then
      tmux run -b 'tmux set display-time 3000 \; display "This configuration requires perl" \; set -u display-time \; run "sleep 3" \; kill-server'
      return
    fi
    if ! command -v sed >/dev/null 2>&1; then
      tmux run -b 'tmux set display-time 3000 \; display "This configuration requires sed" \; set -u display-time \; run "sleep 3" \; kill-server'
      return
    fi
    if ! command -v awk >/dev/null 2>&1; then
      tmux run -b 'tmux set display-time 3000 \; display "This configuration requires awk" \; set -u display-time \; run "sleep 3" \; kill-server'
      return
    fi
    if [ "$_tmux_version" -lt 240 ]; then
      tmux run -b 'tmux set display-time 3000 \; display "This configuration requires tmux 2.4+" \; set -u display-time \; run "sleep 3" \; kill-server'
      return
    fi
  fi

  case "$_uname_s" in
  *CYGWIN* | *MSYS*)
    # prevent Cygwin and MSYS2 from cd-ing into home directory when evaluating /etc/profile
    tmux setenv -g CHERE_INVOKING 1
    ;;
  esac

  _apply_tmux_256color
  _apply_24b &
  _apply_theme &
  _apply_bindings &
  wait

  _apply_plugins

  # shellcheck disable=SC2046
  tmux setenv -gu tmux_conf_dummy $(printenv | grep -E -o '^tmux_conf_[^=]+' | awk '{printf "; setenv -gu %s", $0}')
}

_toggle_clock() {
  window_name="__clock_window"
  current_session=${1:-$(tmux display -p '#{session_name}')}
  clock_window=$(tmux list-windows -t "$current_session" -F '#{window_name} #{window_id}' | grep -E -o "^$window_name .*$" | cut -d ' ' -f2- || true)

  if [ -z "$clock_window" ]; then
    tmux new-window -n "$window_name" \; \
      split-window -h \; \
      split-window -h \; \
      select-layout even-horizontal \; \
      split-window -v \; \
      select-pane -L \; \
      split-window -v \; \
      select-pane -L \; \
      split-window -v \; \
      send-keys -t 1 'TZ=Asia/Shanghai tock -sc' C-m \; \
      send-keys -t 2 'TZ=America/New_York tock -sc' C-m \; \
      send-keys -t 3 'TZ=America/Chicago tock -sc' C-m \; \
      send-keys -t 4 'TZ=Europe/London tock -sc' C-m \; \
      send-keys -t 5 'TZ=Australia/Sydney tock -sc' C-m \; \
      send-keys -t 6 'TZ=Asia/Kolkata tock -sc' C-m
  else
    tmux kill-window -t "$clock_window"
  fi
}

_weather_info() {
  curl -f -s -m 2 "wttr.in/Shanghai?format=3" || printf '\n'
  sleep 900
}

"$@"
