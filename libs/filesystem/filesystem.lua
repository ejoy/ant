local fs = {}; util.__index = fs

local lfs = require "lfs"
local path = require "filesystem.path"

return fs