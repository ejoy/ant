local ltask = require "ltask"
arg = ltask.call(ltask.queryservice "arguments", "QUERY")
local path = package.path
package.path = "engine/?.lua"
require "bootstrap"
package.path = package.path .. ";" .. path
