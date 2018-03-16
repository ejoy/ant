local asset = require "asset"

local ss = asset["test/pickup.material"]

local s = asset["test/foobar.shader"]
local s2 = asset["test/foobar.shader"]

assert(s == s2)

print(s.vs)
print(s.fs)
print(s.foobar[1])


local render = asset["test/bunny.render"]
for k, v in pairs(render) do
    print(k, v)
end
