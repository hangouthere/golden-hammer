#!/bin/sh

# shellcheck disable=SC3043
# https://www.shellcheck.net/wiki/SC3043

utilName="hh-util"
util="cd ../../general/$utilName"
shared="cd golden-hammer-shared"
services="cd golden-hammer-services"
ui="cd golden-hammer-ui"

session="golden-hammer"
projectDirNames="golden-hammer-*/"

shouldLink=""
shouldDeleteCache=""
waitTime=3
figletHeader="figlet -f 3d -w $(tput cols) \"GoldenHammer\""
winNum=1

showHelp() {
  printf "\n"
  figlet -f 3d -w "$(tput cols)" " GoldenHammer"
  figlet -f small -w "$(tput cols)" "            > Project Helper"

  usage="
    This is a helper script to perform various github actions on all projects, clean up stale cache,
    or start/resume a tmux session for the projects. It even includes a way to link the utility project!

    Usage: $(basename "$0") [OPTIONS]

    Without any options, a tmux session will be created if necessary.

    -h              : This help screen.
    -l              : Set up the environment to include linking the hh-util project
    -d              : Deletes package-lock.json and node_modules. Highly useful when
                      switching between linked and non-linked environments, to avoid
                      network failures when npm inevitibly times out trying to
                      reach the private registry.
    -x              : Exit and destroy the environment, including the tmux session.
    -w <numSeconds> : Wait <numSeconds> before continuing startup of environment.
                      This is useful for initial builds that can take a long while.
                      This *will* create the tmux session if necessary!
    -s <branchName> : Set Branch of all projects to <branchName>.
    -u              : Perform a \`git pull\` on all projects.
  "

  echo "$usage"
}

setBranch() {
  echo "Setting Branch for Projects..."

  for dir in $projectDirNames; do
    [ -L "${dir%/}" ] && continue

    (
      echo "  ⚙️  Setting '$dir' to $1"
      cd "$dir" || exit
      git checkout -b "$1" > /dev/null 2>&1
    )
  done
}

updateProjects() {
  echo "Updating Projects..."

  for dir in $projectDirNames; do
    [ -L "${dir%/}" ] && continue

    (
      echo "  ⤴️ Updating '$dir' from $(git remote -vv | grep fetch)"
      cd "$dir" || exit
      git pull
    )
  done
}

deletePackageCache() {
  echo "Deleting Package Cache (node_modules, package-lock.json)"

  for dir in $projectDirNames; do
    [ -L "${dir%/}" ] && continue

    (
      echo "  ❌ Purging '$dir'"
      cd "$dir" || exit
      rm -rf node_modules package-lock.json
    )
  done
}

createOrJoinSession() {
  tmux has-session -t $session 2> /dev/null
  missingSession="$?"

  if [ "1" = "$missingSession" ]; then
    echo "Creating new: $session"
    createSession
  else
    echo "Session found: $session"
    joinSession
  fi
}

joinSession() {
  # Not in TMUX, so we can attach
  if [ -z "$TMUX" ]; then
    echo "Joining Session: $session"
    tmux attach -t $session
  else
    # Inside TMUX, so we need to switch
    echo "Switching to Session: $session"
    tmux switch-client -t $session
    # tmux switch-client -n
  fi
}

openWindow() {
  winNum=$((winNum+1))
  local winName="$1"

  tmux new-window -t $session:$winNum -n "$winName"
  tmux split-window -t $session:$winNum.0 -p 10

  sleep 2
}

startProject() {
  local cmdChDir="$1"
  local ctrName="$2"
  local cmdStart=""

  if [ "$utilName" = "$ctrName" ]; then
    cmdStart=$cmdProjectStartHH
  else
    cmdStart=$cmdProjectStart
  fi

  tmux send-keys -t $session:$winNum.0 " $cmdChDir; $cmdStart" Enter
  tmux send-keys -t $session:$winNum.1 " $cmdChDir; sleep $waitTime; docker exec -it $ctrName ash" Enter
  tmux select-pane -t $session:$winNum.1
}

stopProject() {
  local cmdChDir="$1"
  local cmdStart=""
  winNum=$((winNum+1))

  if [ "$utilName" = "$ctrName" ]; then
    cmdStop=$cmdProjectStopHH
  else
    cmdStop=$cmdProjectStop
  fi

  tmux send-keys -t $session:$winNum.0 C-c
  tmux send-keys -t $session:$winNum.0 " $cmdChDir; $cmdStop; tmux kill-window -t $winNum" Enter
}

createSession() {
  local outMsg="$figletHeader"
  local subMsg=""

  tmux new-session -d -s $session -n "GoldenHammer"

  # == Stats
  if [ -n "$shouldDeleteCache" ]; then
    deletePackageCache
    subMsg="  ✅ Deleted Cache Files"
  fi

  if [ -n "$shouldLink" ]; then
    subMsg="$subMsg\n  ✅ Linked $utilName"
  fi

  if [ "0" != "$waitTime" ]; then
    subMsg="$subMsg\n  ✅ Waiting ${waitTime}s before starting projects"
  fi

  tmux split-window -t $session:1.0 -p 70
  tmux send-keys -t $session:1.1 " code ./GoldenHammer.code-workspace & docker stats" Enter
  tmux send-keys -t $session:1.0 " clear && $outMsg"
  tmux select-pane -t $session:1.1

  if [ -n "$subMsg" ]; then
    tmux send-keys -t $session:1.0 " && echo '\n\n$subMsg'"
  fi

  tmux send-keys -t $session:1.0 Enter

  # == util linking
  if [ -n "$shouldLink" ]; then
    openWindow $utilName
    # wait a tiny bit for registry to come up
    startProject "$util && sleep 5" $utilName
  fi

  # == gh-shared
  openWindow gh-shared
  startProject "$shared" gh-shared

  # == gh-services
  openWindow gh-services
  startProject "$services" gh-api

  # == gh-ui
  openWindow gh-ui
  startProject "$ui" gh-ui

  # # == gh-services Tests
  # openWindow "Tests: gh-services"
  # tmux send-keys " $services; sleep ${waitTime}; docker attach golden-hammer-services_test_1" $shouldAutoEnter

  # return to main window
  tmux select-window -t $session:1.0

  joinSession
}

destroySession() {
  winNum=1

  tmux select-window -t $session:1

  if [ -n "$shouldLink" ]; then
    stopProject "$util"
  fi

  stopProject "$shared"
  stopProject "$services"
  stopProject "$ui"

  # Close first panel
  tmux send-keys -t $session:1.0 C-c
  tmux send-keys -t $session:1.0 " tmux kill-window -t 1" Enter
}

start() {
  local DONT_START=""
  local SHUTDOWN=""
  local devType="dev"

  tmux start-server

  while getopts "hldxw:s:u" arg; do
    # echo "Argument: $arg == $OPTARG"

    case $arg in
      l)
        shouldLink="1"
        devType="dev-linked"
        ;;
      d)
        shouldDeleteCache="1"
        ;;
      w)
        waitTime="${OPTARG}"
        ;;
      x)
        SHUTDOWN="1"
        ;;
      s)
        DONT_START="1"
        setBranch "$OPTARG"
        ;;
      u)
        DONT_START="1"
        updateProjects
        ;;
      *)
        DONT_START="1"
        clear
        showHelp
        ;;
    esac
  done

  if [ -n "$DONT_START" ]; then
    exit 0
  fi

  # util project starts a little differently since it's the underlying source for other projects' scripts
  cmdProjectStartHH="./.scripts/compose/$devType.sh"
  cmdProjectStopHH="./.scripts/compose/down.sh"
  cmdProjectStart="./node_modules/.bin/hh-compose-$devType"
  cmdProjectStop="./node_modules/.bin/hh-compose-down"

  if [ -z "$SHUTDOWN" ]; then
    createOrJoinSession
  else
    destroySession
  fi
}

start "$@"
