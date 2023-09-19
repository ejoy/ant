local builtin = require "builtin"

return {
    fastio = require "fastio_wrap",
    parse = require "parse",
    stringify = require "stringify",
    patch = require "patch",
    path = builtin.path,
}
