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
    print = print,

    audio = require "core.sandbox.audio",
    json = import_package "ant.json",
}

return function (path)
    local env = {}
    createPackage(env, path)
    return setmetatable(env, {__index = stdlib})
end
