local serialization = require "bee.serialization"
local aio = import_package "ant.io"

local ozz = require "ozz"

return {
    loader = function (filename)
        local c = aio.readall(filename)
        local data = serialization.unpack(c)
        return {
            inverseBindMatrices = ozz.MatrixVector(data.inverseBindMatrices),
            jointsRemap = ozz.Uint16Verctor(data.jointsRemap)
        }
    end,
}
