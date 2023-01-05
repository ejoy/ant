local path = ...
local p <close> = assert(io.popen("git log -n 1 --pretty=format:\"return {%n    commit = '%H',%n    date = '%ad',%n}\" --date=iso"))
local f <close> = assert(io.open(path, 'w'))
f:write(p:read "a")
