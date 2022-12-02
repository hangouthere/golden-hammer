#!/bin/sh

shared="cd golden-hammer-shared"
services="cd golden-hammer-services"
ui="cd golden-hammer-ui"

figletHeader="figlet -f 3d -w $(tput cols) \"Golden  Hammer\""
dockerBuild="docker-compose down; docker-compose -f ./docker-compose.yml -f ./docker-compose.dev.yml up --build"

session="gh"
dirNames="golden-hammer-*/"

SHOULD_ENTER=""
WAIT_TIME=0

showHelp() {
  figlet -f 3d -w $(tput cols) Golden  Hammer Helper

  __usage="
    A simple helper script to perform actions on all projects, or start a tmux session for the projects.

    Usage: $(basename $0) [OPTIONS]

    Without any options, a tmux session will be created if necessary.

    -w <numSeconds> : Wait <numSeconds> before continuing startup of environment.
                      This is useful for initial builds that can take a long while.
                      This *will* create the tmux session if necessary!
    -s <branchName> : Set Branch of all projects to <branchName>.
    -u              : Perform a \`git pull\` on all projects.
    -h              : This help screen.
  "

  echo "$__usage"
}

setBranch() {
  echo "Setting Branch for Projects..."

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

startProject() {
  winNum=$1
  cmdChDir="$2"
  ctrName="$3"

  tmux send-keys -t $session:$winNum.0 "$cmdChDir; $dockerBuild" C-m
  tmux send-keys -t $session:$winNum.1 "$cmdChDir; sleep ${WAIT_TIME}; docker exec -it $ctrName npm run dev" $SHOULD_ENTER
  tmux select-pane -t $session:$winNum.1
}

openWindow() {
  winNum=$1
  winName=$2

  tmux new-window -t $session:$winNum -n $winName
  tmux split-window -t $session:$winNum.0 -p 90
}

createSession() {
  tmux start-server
  tmux new-session -d -s $session -n "Golden Hammer"

  # == Build Window 1
  tmux split-window -t $session:1.0 -p 80
  tmux send-keys -t $session:1.0 "$figletHeader" C-m
  tmux send-keys -t $session:1.1 "code ./GoldenHammer.code-workspace && docker stats" C-m
  tmux select-pane -t $session:1.1

  # == Build Window 2
  openWindow 2 gh-shared
  startProject 2 "$shared" golden-hammer-shared_golden-hammer-shared_1

  # == Build Window 3
  openWindow 3 gh-services
  tmux send-keys -t $session:3.0 "$services; $dockerBuild" C-m
  tmux send-keys -t $session:3.1 "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_api_1" $SHOULD_ENTER
  tmux select-pane -t $session:3.1

  # == Build Window 4
  openWindow 4 gh-ui
  startProject 4 "$ui" golden-hammer-ui_golden-hammer-ui_1

  # # == Build Window 5
  # openWindow 5 "Tests: gh-services"
  # # Exec Pane Commands 
  # tmux send-keys "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_test_1" $SHOULD_ENTER

  # return to main window
  tmux select-window -t $session:1.1

  joinSession
}

start() {
  while getopts "hw:s:u" arg; do
    echo "Argument: $arg == $OPTARG"

    case $arg in
      h)
        clear
        showHelp
        ;; 
      s)
        setBranch $OPTARG
        ;; 
      u)
        updateProjects
        ;;
      w)
        WAIT_TIME="${OPTARG}"
        SHOULD_ENTER="C-m"

        createOrJoinSession
        ;;
      *)
      createOrJoinSession

        ;;
    esac

    exit 0
  done

  # No args met
  createOrJoinSession
}

start
