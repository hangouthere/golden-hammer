#!/bin/sh
util="cd ../../general/nfg-util"
shared="cd golden-hammer-shared"
services="cd golden-hammer-services"
ui="cd golden-hammer-ui"

session="golden-hammer"
projectDirNames="golden-hammer-*/"

SHOULD_PRESS_ENTER=""
SHOULD_LINK=""
SHOULD_DELETE_CACHE=""
WAIT_TIME=0
DEV_TYPE="dev"
winNum=1

showHelp() {
  figlet -f 3d -w $(tput cols) "GoldenHammer"
  figlet -f small -w $(tput cols) "Project Helper"

  usage="
    This is a helper script to perform various github actions on all projects, clean up stale cache,
    or start/resume a tmux session for the projects. It even includes a way to link the utility project!

    Usage: $(basename $0) [OPTIONS]

    Without any options, a tmux session will be created if necessary.

    -h              : This help screen.
    -l              : Set up the environment to include linking the nfg-util project
    -d              : Deletes package-lock.json and node_modules. Highly useful when
                      switching between linked and non-linked environments, to avoid
                      network failures when npm inevitibly times out trying to
                      reach the private registry.
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

    echo "  ⚙️ Setting '$dir' to $1"

    cd $dir
    git checkout -b $1 2>&1 /dev/null
    cd ..
  done

  exit
}

updateProjects() {
  echo "Updating Projects..."

  for dir in $projectDirNames; do
    [ -L "${dir%/}" ] && continue

    echo "  ⤴️ Updating '$dir' from $(git remote -vv | grep fetch)"

    cd $dir
    git pull
    cd ..
  done

  exit
}

deletePackageCache() {
  echo "Deleting Package Cache (node_modules, package-lock.json)"

  for dir in $projectDirNames; do
    [ -L "${dir%/}" ] && continue

    echo "  ❌ Purging '$dir'"

    cd $dir
    rm -rf node_modules package-lock.json
    cd ..
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
  winName=$1

  tmux new-window -t $session:$winNum -n $winName
  tmux split-window -t $session:$winNum.0 -p 10
}

startProject() {
  cmdChDir="$1"
  ctrName="$2"

  tmux send-keys -t $session:$winNum.0 " $cmdChDir; $dockerBuild" Enter
  # tmux send-keys -t $session:$winNum.1 " $cmdChDir; sleep ${WAIT_TIME}; docker exec -it $ctrName npm run dev" $SHOULD_PRESS_ENTER
  tmux send-keys -t $session:$winNum.1 " $cmdChDir && clear" Enter
  tmux select-pane -t $session:$winNum.1
}

createSession() {
  dockerBuild="docker-compose down; docker-compose -f ./docker-compose.yml -f ./docker-compose.$DEV_TYPE.yml up --build"
  figletHeader="figlet -f 3d -w $(tput cols) \"GoldenHammer\""

  outMsg="$figletHeader"
  subMsg=""

  tmux start-server
  tmux new-session -d -s $session -n "GoldenHammer"

  # == Stats
  if [ -n "$SHOULD_DELETE_CACHE" ]; then
    deletePackageCache
    subMsg="  ✅ Deleted Cache Files"
  fi
  if [ -n "$SHOULD_LINK" ]; then
    subMsg="$subMsg\n  ✅ Linked nfg-util"
  fi
  if [ "0" != "$WAIT_TIME" ]; then
    subMsg="$subMsg\n  ✅ Waiting ${WAIT_TIME}s before starting projects"
  fi
  tmux split-window -t $session:1.0 -p 70
  tmux send-keys -t $session:1.1 " code ./GoldenHammer.code-workspace & docker stats" Enter
  tmux select-pane -t $session:1.1
  tmux send-keys -t $session:1.0 " clear && $outMsg"
  if [ -n "$subMsg" ]; then
    tmux send-keys -t $session:1.0 " && echo '\n\n$subMsg'"
  fi

  tmux send-keys -t $session:1.0 Enter

  # == nfg-util linking
  if [ -n $SHOULD_LINK ]; then
    openWindow nfg-util
    startProject "$util" nfg-util
    sleep 5 # wait a tiny bit for registry to come up
  fi

  # == gh-shared
  openWindow gh-shared
  startProject "$shared" golden-hammer-shared_golden-hammer-shared_1

  # == gh-services
  openWindow gh-services
  startProject "$services" golden-hammer-services_api_1
  # tmux send-keys -t $session:$winNum.0 " $services; $dockerBuild" Enter
  # tmux send-keys -t $session:$winNum.1 " $services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_api_1" $SHOULD_PRESS_ENTER
  # tmux select-pane -t $session:$winNum.1

  # == gh-ui
  openWindow gh-ui
  startProject "$ui" golden-hammer-ui_golden-hammer-ui_1

  # # == gh-services Tests
  # openWindow "Tests: gh-services"
  # tmux send-keys " $services; sleep ${WAIT_TIME}; docker attach golden-hammer-services_test_1" $SHOULD_PRESS_ENTER

  # return to main window
  tmux select-window -t $session:1.1

  joinSession
}

start() {
  DONT_START=""

  while getopts "hldw:s:u" arg; do
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
      d)
        SHOULD_DELETE_CACHE="1"
        ;;
      w)
        WAIT_TIME="${OPTARG}"
        SHOULD_PRESS_ENTER="Enter"
        ;;
      s)
        setBranch $OPTARG
        DONT_START="1"
        ;;
      u)
        updateProjects
        DONT_START="1"
        ;;
    esac
  done

  if [ -n "$DONT_START" ]; then
    exit 0
  fi

  createOrJoinSession
}

start "$@"
