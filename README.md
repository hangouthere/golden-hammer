## TODO

* Set up link reinstall for all projects using @nfg/util
* Set up link reinstall for all projects using golden-hammer-shared

Both these setups use npm registry reinstall, but triggered on vol mounts via nodemon. These can point to dist folders for limited triggers
 -  mount expected trigger folder to /links/nfgutil and /links/gh-shared
 -  setup nodemon scripts for link targets to reinstall themselves
	- gh-shared needs some checking


## Setup

### File System Watch

https://www.suse.com/support/kb/doc/?id=000020048


Need to establish symlinks when working in "linked mode"


