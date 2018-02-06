local asset = require "asset"

local s = asset["test/foobar.shader"]
local s2 = asset["test/foobar.shader"]

assert(s == s2)

print(s.vs)
print(s.fs)
print(s.foobar[1])
