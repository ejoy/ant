Support UTF-8 filename in Windows
======

This lua library is for windows (mingw) only . It's similar to [lfs](https://keplerproject.github.io/luafilesystem) but support utf-8 filename.

* lfs.dir ==> winfile.dir
* lfs.currentdir ==> winfile.currentdir
* lfs.chdir ==> winfile.chdir
* lfs.touch ==> winfile.touch
* lfs.mkdir ==> winfile.mkdir
* lfs.rmdir ==> winfile.rmdir
* lfs.attributes ==> winfile.attributes
* os.remove ==> winfile.remove
* os.rename ==> winfile.rename
* os.execute ==> winfile.execute
* os.getenv ==> winfile.getenv
* loadfile ==> winfile.loadfile
* dofile ==> winfile.dofile
* io.open ==> winfile.open
* io.popen ==> winfile.popen
* winfile.shortname : Get the shorname of the path.
* winfile.personaldir : Get My Document dir.
