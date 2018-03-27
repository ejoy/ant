dofile "libs/init.lua"

local path = require "filesystem.path"

local pp = path.join("abc", "efg", "ijk", "lmn.lua")
print(pp)
print(path.filename(pp))
print(path.ext(pp))
print(path.remove_ext(pp))
print(path.filename_without_ext(pp))
print(path.parent(pp))