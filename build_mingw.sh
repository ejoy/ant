#!/usr/bin/bash
ANT3RD="../ant3rd"
if [ ! -d "$ANT3RD" ]; then
	echo $ANT3RD is not exist!
	exist 1
fi

echo Found $ANT3RD
cd $ANT3RD
if [ "$UPDATE_GIT" != "" ]; then
	git pull && git submodule update --init
fi
make init 
make all $MP

cd -
if [ "$UPDATE_GIT" != ""]; then
	git pull && git submodule update --init
fi

cd clibs
make $MP $BIN