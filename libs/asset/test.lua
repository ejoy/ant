local asset = require "asset"
print_r = require "../common/print_r"

local s = asset["test/foobar.shader"]
local s2 = asset["test/foobar.shader"]

assert(s == s2)

print(s.vs)
print(s.fs)
print(s.foobar[1])


local render = asset["test/bunny.render"]
print_r(render)
