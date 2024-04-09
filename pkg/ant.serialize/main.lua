local aio = import_package "ant.io"
local fastio = require "fastio"
local builtin = require "builtin"
local parse = require "parse"

local function load(filename)
    return parse(filename, aio.readall(filename))
end

local function load_lfs(filename)
    return parse(filename, fastio.readall_f(filename))
end

return {
    parse = require "parse",
    load = load,
    load_lfs = load_lfs,
    stringify = require "stringify",
    path = builtin.path,
}
