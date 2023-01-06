local ecs = ...
local world = ecs.world
local w = world.w

local assetmgr      = import_package "ant.asset"
local audio     = require "audio"

local audio_sys = ecs.system "audio_system"

local ia = ecs.interface "audio_interface"

function ia.create(eventname)
    return audio.create(eventname)
end
local bank = {}
function ia.load_bank(filename)
    if not bank[filename] then
        local res = assetmgr.resource(filename)
        bank[filename] = audio.load_bank(res.rawdata)
    end
    return bank[filename]
end

local sound_event = {}

function ia.play(event_name)
    if not sound_event[event_name] then
        sound_event[event_name] = ia.create(event_name)
    end
    local ev = sound_event[event_name]
    if ev then
        audio.play(ev)
    end
end

function ia.destroy(event_name)
    if event_name then
        local event = sound_event[event_name]
        if event then
            audio.destroy(event)
            sound_event[event_name] = nil
        end
    else
        for _, value in pairs(sound_event) do
            audio.destroy(value)
        end
        sound_event = {}
    end
end

-- function ia.play(event)
--     audio.play(event)
-- end

-- function ia.destroy(event)
--     audio.destroy(event)
-- end

function ia.stop(event)
    audio.stop(event)
end

function ia.get_event_list(b)
    return audio.get_event_list(b)
end

function ia.get_event_name(se)
    return audio.get_event_name(se)
end

local sound_attack_
local sound_click_

function audio_sys:init()    
    audio.init()
    --test
    -- local bankname = "res/sounds/Master.bank"
    -- local bank0 = ia.load_bank(bankname)
    -- if not bank0 then
    --     print("LoadBank Faied. :", bankname)
    -- end
    -- local bankname = "res/sounds/Master.strings.bank"
    -- local bank1 = ia.load_bank(bankname)
    -- if not bank1 then
    --     print("LoadBank Faied. :", bankname)
    -- end

    -- -- local bank_list = audio.get_bank_list()
    -- -- for _, v in ipairs(bank_list) do
    -- --     print(audio.get_bank_name(v))
    -- -- end

    -- local event_list = audio.get_event_list(bank0)
    -- for _, v in ipairs(event_list) do
    --     print(audio.get_event_name(v))
    -- end
    -- local event_name = "event:/Scene/attack"
    -- sound_event[event_name] = ia.create(event_name)
    -- event_name = "event:/UI/click"
    -- sound_event[event_name] = ia.create(event_name)
    -- ia.play(event_name)
end

function audio_sys:data_changed()
    audio.update()
end

function audio_sys:exit()
    ia.destroy()
    audio.shutdown()
end