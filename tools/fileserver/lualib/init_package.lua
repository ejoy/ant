local ltask = require "ltask"
local manager = require "ltask.manager"
arg = ltask.call(manager.query "arguments", "QUERY")
local path = package.path
package.path = "engine/?.lua"
require "bootstrap"
package.path = path
