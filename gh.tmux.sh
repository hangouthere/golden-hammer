#!/bin/sh

shared="cd golden-hammer-shared"
services="cd golden-hammer-services"
ui="cd golden-hammer-ui"

figletHeader="figlet -f 3d -w $(tput cols) \"Golden  Hammer\""
dockerBuild="docker-compose down && docker-compose -f ./docker-compose.yml -f ./docker-compose.dev.yml up --build"

session="gh"

SHOULD_ENTER=""
WAIT_TIME=0

while getopts ":w:" arg; do
  case $arg in
    w)
      WAIT_TIME="${OPTARG}"
      SHOULD_ENTER="C-m"
      ;;
    *)
      ;;
  esac
done

# set up tmux
tmux start-server

# == Build Window 1
tmux new-session -d -s $session -n scratch
tmux select-pane -t 0
tmux split-window -p 90
# Exec Pane Commands 
tmux select-pane -t 0
tmux send-keys "$figletHeader" C-m
tmux select-pane -t 1
tmux send-keys "docker stats" C-m


# == Build Window 2
tmux new-window -t $session:2 -n gh-shared
tmux select-pane -t 0 
tmux split-window -p 90
# Exec Pane Commands 
tmux select-pane -t 0 
tmux send-keys "$shared; $dockerBuild" C-m
tmux select-pane -t 1
tmux send-keys "$shared; sleep ${WAIT_TIME}; docker exec -it golden-hammer-shared_golden-hammer-shared_1 npm run dev" $SHOULD_ENTER


# == Build Window 3
tmux new-window -t $session:3 -n gh-services
tmux select-pane -t 0 
tmux split-window -p 90
# Exec Pane Commands 
tmux select-pane -t 0 
tmux send-keys "$services; $dockerBuild" C-m
tmux select-pane -t 1
tmux send-keys "$services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_api_1 " $SHOULD_ENTER
if [ ! -z "${WAIT_TIME}" ]; then
    tmux send-keys "sleep ${WAIT_TIME}; actions" $SHOULD_ENTER
fi

# == Build Window 4
tmux new-window -t $session:4 -n gh-ui
tmux select-pane -t 0 
tmux split-window -p 90
# Exec Pane Commands 
tmux select-pane -t 0 
tmux send-keys "$ui; $dockerBuild" C-m
tmux select-pane -t 1
tmux send-keys "$ui; sleep ${WAIT_TIME}; docker exec -it golden-hammer-ui_golden-hammer-ui_1 npm run dev" $SHOULD_ENTER



# return to main window
tmux select-window -t $session:1

# Finished setup, attach to the tmux session!
tmux attach-session -t $session
