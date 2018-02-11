local winfile =  require "winfile"

os.remove = winfile.remove
os.rename = winfile.rename
loadfile = winfile.loadfile
dofile = winfile.dofile
io.open = winfile.open
os.execute = winfile.execute
os.getenv = winfile.getenv
os.popen = winfile.popen

return winfile
