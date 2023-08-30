local ltask     = require "ltask"

local math3d    = require "math3d"

local EFK_SERVER<const> = ltask.queryservice "ant.efk|efk"

local handle_mt = {
    realive = function (self, speed)
        ltask.call(EFK_SERVER, "play", self.handle, speed)
    end,
    is_alive = function(self)
        ltask.fork(function ()
            self.alive = ltask.call(EFK_SERVER, "is_alive", self.handle)
        end)
        return self.alive
    end,
    set_stop = function(self, delay)
        ltask.send(EFK_SERVER, "set_stop", self.handle, delay)
    end,

    set_time = function(self, time)
        ltask.send(EFK_SERVER, "set_time", self.handle, time)
    end,
    set_pause = function(self, p)
        assert(p ~= nil)
        ltask.send(EFK_SERVER, "set_pause", self.handle, p)
    end,
    
    set_speed = function(self, speed)
        assert(speed ~= nil)
        ltask.send(EFK_SERVER, "set_speed", self.handle, speed)
    end,
    
    set_visible = function(self, v)
        assert(v ~= nil)
        ltask.send(EFK_SERVER, "set_visible", self.handle, v)
    end,

    update_transform = function(self, mat)
        ltask.send(EFK_SERVER, "update_transform", self.handle, math3d.serialize(mat))
    end,
    update_hitch_transforms = function (self, hitchmats, localmat)
        local mats = {}
        for _, hm in ipairs(hitchmats) do
            mats[#mats+1] = math3d.serialize(math3d.mul(hm, localmat))
        end
        ltask.send(EFK_SERVER, "update_hitch_transforms", self.handle, mats)
    end
}

local function create(efk_handle, speed, worldmat)
    ltask.call(EFK_SERVER, "play", efk_handle, speed)
    local h = setmetatable({
        alive       = true,
        handle      = efk_handle,
    }, {__index = handle_mt})
    if worldmat then
        h:update_transform(worldmat)
    end
    return h
end

return {
    create      = create,
}