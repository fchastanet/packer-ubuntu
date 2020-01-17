#!/usr/bin/env bash

if [[ "$1" == "--help" ]]; then
cmdName=$(basename $0)
cat << USAGE >&2
fix git author name in current branch
Usage : ${cmdName} old@address "Old name" new@address "New name"
USAGE
exit 0
fi

if [[ "$#" != "4" ]]; then
    echo "check your arguments (--help for help)"
fi

OLD_ADDR="$1"
OLD_NAME="$2"
NEW_ADDR="$3"
NEW_NAME="$4"

git filter-branch --env-filter '
  [ "$GIT_AUTHOR_EMAIL"    = "$OLD_ADDR" ] && export GIT_AUTHOR_EMAIL=$NEW_ADDR
  [ "$GIT_AUTHOR_NAME"     = "$OLD_NAME" ] && export GIT_AUTHOR_NAME=$NEW_NAME
  [ "$GIT_COMMITTER_EMAIL" = "$OLD_ADDR" ] && export GIT_COMMITTER_EMAIL=$NEW_ADDR
  [ "$GIT_COMMITTER_NAME"  = "$OLD_NAME" ] && export GIT_COMMITTER_NAME=$NEW_NAME
' HEAD

# to fix in all branches replace HEAD with -- --all

echo "do not forget to push force"
