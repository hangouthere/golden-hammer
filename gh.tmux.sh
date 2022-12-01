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

openWindow() {
  tmux new-window -t $session:$1 -n $2
  tmux select-pane -t 0 
  tmux split-window -p 90
  tmux select-pane -t 0 
}

createOrJoinSession() {
  tmux has-session -t $session

  if [ "1" = "$?" ]; then
    createSession
  else
    # Not in TMUX, so we can attach
    if [ -z "$TMUX" ]; then
      echo "Joining existing session: $session"
      tmux attach -t $session
    else
      # Inside TMUX, so we need to switch
      echo "Switching to existing session: $session"
      tmux switch-client -t $session
    fi

  fi
}

startProject() {
  cmdChDir="$1"
  containerName="$2"

  tmux send-keys "$cmdChDir; $dockerBuild" C-m
  tmux select-pane -t 1
  tmux send-keys "$cmdChDir; sleep ${WAIT_TIME}; docker exec -it $containerName npm run dev" $SHOULD_ENTER
}


createSession() {
  # set up tmux
  tmux start-server

  tmux new-session -d -s $session -n scratch

  # == Build Window 1
  tmux select-pane -t 0
  tmux split-window -p 80
  # Exec Pane Commands 
  tmux select-pane -t 0
  tmux send-keys "$figletHeader" C-m
  tmux select-pane -t 1
  tmux send-keys "code ./GoldenHammer.code-workspace && docker stats" C-m

  # == Build Window 2
  openWindow 2 gh-shared
  startProject "$shared" golden-hammer-shared_golden-hammer-shared_1

  # == Build Window 3
  openWindow 3 gh-services
  # Exec Pane Commands 
  tmux send-keys "$services; $dockerBuild" C-m
  tmux select-pane -t 1
  tmux send-keys "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_api_1" $SHOULD_ENTER

  # == Build Window 4
  openWindow 4 gh-ui
  # Exec Pane Commands 
  tmux send-keys "$ui; $dockerBuild" C-m
  startProject "$ui" golden-hammer-ui_golden-hammer-ui_1

  # # == Build Window 5
  # openWindow 5 "Tests: gh-services"
  # # Exec Pane Commands 
  # tmux send-keys "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_test_1" $SHOULD_ENTER

  # return to main window
  tmux select-window -t $session:1

  # Finished setup, attach to the tmux session!
  tmux attach-session -t $session
}

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
