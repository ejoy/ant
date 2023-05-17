local ltask     = require "ltask"

local math3d    = require "math3d"
local MP<const> = math3d.value_ptr

local EFK_SERVER<const> = ltask.queryservice "ant.efk|efk"

local PLAY_HANDLES = {}

local handle_mt = {
    destroy = function(self)
        self.delete = true
    end,

    is_alive = function(self)
        return self.alive
    end,
    set_stop = function(self, delay)
        self.stop = true
        self.delay = delay
    end,
    set_transform = function(self, mat)
        self.mat = math3d.ref(mat)
    end,
    set_time = function(self, time)
        assert(time ~= nil)
        self.time = time
    end,
    set_pause = function(self, p)
        assert(p ~= nil)
        self.pause = p
    end,
    
    set_speed = function(self, speed)
        assert(speed ~= nil)
        self.speed = speed
    end,
    
    set_visible = function(self, v)
        assert(v ~= nil)
        self.visible = v
    end,

    set_state = function (from, to)
        to.efk_handle  = from.efk_handle
        to.delete      = from.delete
        to.play        = from.play
        to.mat         = from.mat
        to.stop        = from.stop
        to.delay       = from.delay
        to.time        = from.time
        to.pause       = from.pause
        to.speed       = from.speed
        to.visible     = from.visible
    end,

    copy = function (self)
        local c = {}
        self:set_state(c)
        return c
    end,

    clear = function (self)
        self:set_state{}
    end,
}
local gen_id;
do
    local id = 0
    gen_id = function ()
        id = id + 1
        return id
    end
end

local function create(efk_handle, mat, speed)
    local id = gen_id()
    local h = setmetatable({
        efk_handle  = efk_handle,
        id          = id,
        mat         = math3d.ref(mat),
        speed       = speed,
        init        = true,
        alive       = true,
    }, {__index = handle_mt})

    PLAY_HANDLES[id] = h
    return h
end

local function update_state(h, s)
    if s.mat then
        s.mat = MP(s.mat)
    end

    if h.init then
        h.handle    = ltask.call(EFK_SERVER, "play", s.efk_handle, s.mat, s.speed)
        h.init      = nil
    end
    h.alive = ltask.call(EFK_SERVER, "update_state", h.handle, s)
end

local function update_all()
    local remove_ids = {}
    for id, h in pairs(PLAY_HANDLES) do
        if h.delete then
            remove_ids[#remove_ids+1] = id
        else
            local s = h:copy()
            h:clear()
            ltask.fork(function ()
                if s.delete then
                    if not s.init then
                        ltask.call(EFK_SERVER, "destroy", h)
                    end
                else
                    update_state(h, s)
                end
            end)
        end
    end

    for _, id in ipairs(remove_ids) do
        PLAY_HANDLES[id] = nil
    end
end

return {
    create      = create,
    update_all  = update_all,
}