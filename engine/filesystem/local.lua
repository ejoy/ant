local fs = require "bee.filesystem"

function fs.open(filepath, ...)
    return io.open(filepath:string(), ...)
end

return fs
