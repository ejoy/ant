dofile "libs/init.lua"

local path = require "filesystem.path"

local pp = path.join("abc", "efg", "ijk", "lmn.lua")
local fn = "bunny.material"
local parent = "test/simplerender/bunny.render"
if not path.has_parent(fn) then
    local pp = path.parent(parent)
    local nomem_pp = pp:match("mem://(.+)")    
    local ff = nomem_pp and nomem_pp or pp        
    print("ff : ", ff, "fn : ", fn)
    print(path.join(ff, fn))
else
    print("no parent")
end

print(path.join("test/simplerender", "bunny.material"))

