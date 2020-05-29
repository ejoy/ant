local util = {}; util.__index = util
local fs = require "filesystem.local"
function util.subrespath(rootpath, fullpath)
    return fs.path(fullpath:string():gsub(rootpath:string(), "."))
end

return util