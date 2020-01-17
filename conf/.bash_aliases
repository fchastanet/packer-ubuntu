#!/bin/bash

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias folder-size='du -h -c -d 1'
alias ps_full_command='ps -efww'

# ssh tunnels to remote hosts
sshKillAllTunnel() {
    ps -aux | grep 'ssh.*-L' | awk -F " " '{print $2}' | xargs kill
}
alias ssh_kill_all_tunnel='sshKillAllTunnel'

# git commands
gitSafelyRemoveLocalBranch() {
    local branch="$1"
    git tag "${branch}" "${branch}" && git branch -D "${branch}"

}
alias git-safely-remove-local-branch='gitSafelyRemoveLocalBranch'

gitListBranchesForCommit() {
    local branch="$1"
    git branch -a --contains "${branch}"
}
alias git-list-branches-for-commit='gitListBranchesForCommit'

# container commands
alias code="/usr/bin/code >/dev/null 2>&1"

UI::askYesNo() {
    while true; do
        read -p "$1 (y or n)? " -n 1 -r
        echo    # move to a new line
        case ${REPLY} in
            [yY]) return 0;;
            [nN]) return 1;;
            *)
                read -N 10000000 -t '0.01' ||true; # empty stdin in case of control characters
                # \\r to go back to the beginning of the line
                Log::displayError "\\r invalid answer                                                          "
        esac
    done
}

# undo last pushed commit
# - step 1: remove commit locally
# - step 2: force-push the new HEAD commit
# !!!! use it with care
# this will create an "alternate reality" for people who have already fetch/pulled/cloned from the remote repository.
undoLastPushedCommit() {
    echo -e '\e[33m!!! use it with care\e[0m'
    echo -e '\e[33mthis will create an "alternate reality" for people who have already fetch/pulled/cloned from the remote repository.\e[0m'
    UI::askYesNo "do you confirm" && {
        git reset HEAD^ && git push origin +HEAD
    }
}
alias undoLastPushedCommit="undoLastPushedCommit"

alias docker-compose-down-one-service='docker-compose rm -f -s'
