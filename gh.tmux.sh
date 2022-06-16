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

launchTmux() {
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
  # Exec Pane Commands 
  tmux send-keys "$shared; $dockerBuild" C-m
  tmux select-pane -t 1
  tmux send-keys "$shared; sleep ${WAIT_TIME}; docker exec -it golden-hammer-shared_golden-hammer-shared_1 npm run dev" $SHOULD_ENTER

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
  tmux select-pane -t 1
  tmux send-keys "$ui; sleep ${WAIT_TIME}; docker exec -it golden-hammer-ui_golden-hammer-ui_1 npm run dev" $SHOULD_ENTER

  # == Build Window 5
  openWindow 5 "Tests: gh-services"
  # Exec Pane Commands 
  tmux send-keys "$services;" C-m
  tmux select-pane -t 1
  tmux send-keys "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_test_1" $SHOULD_ENTER

  # return to main window
  tmux select-window -t $session:1

  # Finished setup, attach to the tmux session!
  tmux attach-session -t $session
}

while getopts ":w:s:u" arg; do
  echo "Argument: $arg == $OPTARG"

  case $arg in
    s)
      setBranch $OPTARG
      ;; 
    u)
      updateProjects
      ;;
    w)
      WAIT_TIME="${OPTARG}"
      SHOULD_ENTER="C-m"

     launchTmux
      ;;
    *)
    launchTmux

      ;;
  esac

  exit 0
done

# No args met
launchTmux
