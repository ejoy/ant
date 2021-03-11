local finder = {}; finder.__index = finder
local constant = require "constant"

local ctrunkid = require "trunkid_class"

local face_index<const> = constant.face_index
local next_face = {
    [face_index.back] = {
        x_p = face_index.left,
        x_n = face_index.right,
        y_p = face_index.top,
        y_n = face_index.bottom,
    },
    [face_index.front] = {
        x_p = face_index.front,
        x_n = face_index.back,
        y_p = face_index.top,
        y_n = face_index.bottom,
    },
    [face_index.up] = {
        x_p = face_index.front,
        x_n = face_index.back,
        y_p = face_index.top,
        y_n = face_index.bottom,
    },
    [face_index.down] = {
        x_p = face_index.front,
        x_n = face_index.back,
        y_p = face_index.top,
        y_n = face_index.bottom,
    },
    [face_index.left] = {
        x_p = face_index.front,
        x_n = face_index.back,
        y_p = face_index.top,
        y_n = face_index.bottom,
    },
    [face_index.right] = {
        x_p = face_index.front,
        x_n = face_index.back,
        y_p = face_index.top,
        y_n = face_index.bottom,
    },
}

function finder.get_x(trunkid, num_trunk, direction, from)
    local face, tx, ty = ctrunkid.unpack(trunkid)
    if direction > 0 then
        local n = from + 1
        if n > num_trunk then

        end
    else
        local n = from - 1
    end
end



return finder