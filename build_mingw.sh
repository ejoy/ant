#!/usr/bin/bash
ANT3RD="3rd"
if [ ! -d "$ANT3RD" ]; then
	echo $ANT3RD is not exist!
	exist 1
fi

echo Found $ANT3RD
cd $ANT3RD
make init 
make all $MP

cd -
cd clibs
make $MP $BIN