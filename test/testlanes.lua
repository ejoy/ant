dofile "libs/editor.lua"

-- See http://lualanes.github.io/lanes/ for document and license

local lanes = require "lanes".configure()

f = lanes.gen(function(n) return 2 * n end)
a = f(1)
b = f(2)

print(a[1], b[1])
