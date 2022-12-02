#!/bin/sh
util="cd ../../general/nfg-util"
shared="cd golden-hammer-shared"
services="cd golden-hammer-services"
ui="cd golden-hammer-ui"

session="gh"

SHOULD_PRESS_ENTER=""
SHOULD_LINK=""
WAIT_TIME=0
DEV_TYPE="dev"
winNum=1

showHelp() {
  figlet -f 3d -w $(tput cols) Golden  Hammer Helper

  usage="
    A simple helper script to perform actions on all projects, or start a tmux session for the projects.

    Usage: $(basename $0) [OPTIONS]

    Without any options, a tmux session will be created if necessary.

    -l              : Set up the environment to include linking the nfg-util project
    -w <numSeconds> : Wait <numSeconds> before continuing startup of environment.
                      This is useful for initial builds that can take a long while.
                      This *will* create the tmux session if necessary!
    -s <branchName> : Set Branch of all projects to <branchName>.
    -u              : Perform a \`git pull\` on all projects.
    -h              : This help screen.
  "

  echo "$usage"
}

setBranch() {
  echo "Setting Branch for Projects..."

  dirNames="golden-hammer-*/"

  for dir in $dirNames; do
    [ -L "${dir%/}" ] && continue

    echo "Setting $dir to $1"

    cd $dir
    git checkout $1
    cd ..
  done

  exit
}

updateProjects() {
  echo "Updating Projects..."

  for dir in $dirNames; do
    [ -L "${dir%/}" ] && continue

    echo "Updating $dir"

    cd $dir
    git pull
    cd ..
  done

  exit
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
  winName=$1

  tmux new-window -t $session:$winNum -n $winName
  tmux split-window -t $session:$winNum.0 -p 10
}

startProject() {
  cmdChDir="$1"
  ctrName="$2"

  tmux send-keys -t $session:$winNum.0 "$cmdChDir; $dockerBuild" C-m
  tmux send-keys -t $session:$winNum.1 "$cmdChDir; sleep ${WAIT_TIME}; docker exec -it $ctrName npm run dev" $SHOULD_PRESS_ENTER
  tmux select-pane -t $session:$winNum.1
}

createSession() {
  dockerBuild="docker-compose down; docker-compose -f ./docker-compose.yml -f ./docker-compose.$DEV_TYPE.yml up --build"
  figletHeader="figlet -f 3d -w $(tput cols) \"Golden  Hammer\""

  tmux start-server
  tmux new-session -d -s $session -n "Golden Hammer"

  # == Stats
  tmux split-window -t $session:1.0 -p 80
  tmux send-keys -t $session:1.0 "$figletHeader" C-m
  tmux send-keys -t $session:1.1 "code ./GoldenHammer.code-workspace && docker stats" C-m
  tmux select-pane -t $session:1.1

  # == nfg-util linking
  if [ -n $SHOULD_LINK ]; then
    openWindow nfg-util
    startProject "$util" nfg-util
  fi

  # == gh-shared
  openWindow gh-shared
  startProject "$shared" golden-hammer-shared_golden-hammer-shared_1

  # == gh-services
  openWindow gh-services
  tmux send-keys -t $session:$winNum.0 "$services; $dockerBuild" C-m
  tmux send-keys -t $session:$winNum.1 "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_api_1" $SHOULD_PRESS_ENTER
  tmux select-pane -t $session:$winNum.1

  # == gh-ui
  openWindow gh-ui
  startProject "$ui" golden-hammer-ui_golden-hammer-ui_1

  # # == gh-services Tests
  # openWindow "Tests: gh-services"
  # tmux send-keys "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_test_1" $SHOULD_PRESS_ENTER

  # return to main window
  tmux select-window -t $session:1.1

  joinSession
}

start() {
  DONT_START=""

  while getopts ":hlw:s:u" arg; do
    # echo "Argument: $arg == $OPTARG"

    case $arg in
      h)
        clear
        showHelp
        DONT_START="1"
        ;;
      l)
        SHOULD_LINK="1"
        DEV_TYPE="dev_linked"
        ;; 
      s)
        setBranch $OPTARG
        DONT_START="1"
        ;;
      u)
        updateProjects
        DONT_START="1"
        ;;
      w)
        WAIT_TIME="${OPTARG}"
        SHOULD_PRESS_ENTER="C-m"
        ;;
    esac
  done

  if [ -n "$DONT_START" ]; then
    exit 0
  fi

  createOrJoinSession
}

start "$@"
