local createPackage = require "core.sandbox.package"

local stdlib = {
    math = math,
    string = string,
    utf8 = utf8,
    table = table,

    assert = assert,
    error = error,
    getmetatable = getmetatable,
    ipairs = ipairs,
    load = load,
    next = next,
    pairs = pairs,
    pcall = pcall,
    warn = warn,
    rawequal = rawequal,
    rawlen = rawlen,
    rawget = rawget,
    rawset = rawset,
    select = select,
    setmetatable = setmetatable,
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    xpcall = xpcall,
    _VERSION = _VERSION,

    console = require "core.sandbox.console",
}

return function ()
    local env = {}
    createPackage(env)
    return setmetatable(env, {__index = stdlib})
end
