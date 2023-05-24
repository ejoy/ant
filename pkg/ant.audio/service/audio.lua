local function DummyAudio()
    local caudio = {}
    local mt = {}
    function mt.shutdown()
    end
    function mt.load_bank()
    end
    function mt.unload_bank()
    end
    function mt.unload_all()
    end
    function mt.update()
    end
    function mt.event_get()
    end
    function caudio.init()
        return setmetatable({}, mt)
    end
    function caudio.play(...)
    end
    function caudio.background()
    end
    return caudio
end

local caudio = package.preload.audio
    and require "audio"
    or DummyAudio()

local ltask = require "ltask"
local sys_obj = caudio.init()
local event_list = {}

local S = {}

function S.load_bank(filename)
    sys_obj:load_bank(filename, event_list)
end

function S.play(event_name)
    caudio.play(event_list[event_name])
end

function S.quit()
    sys_obj:shutdown()
    ltask.quit()
end

ltask.fork(function()
    while true do
        ltask.sleep(100)
        sys_obj:update()
    end
end)

return S
