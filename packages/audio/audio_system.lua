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

function ia.load_bank(filename)
    local res = assetmgr.resource(filename)
    return audio.load_bank(res.rawdata)
end

function ia.play(event)
    audio.play(event)
end

function ia.destroy(event)
    audio.destroy(event)
end

function ia.stop(event)
    audio.stop(event)
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

    -- local bank_list = audio.get_bank_list()
    -- for _, v in ipairs(bank_list) do
    --     print(audio.get_bank_name(v))
    -- end

    -- local event_list = audio.get_event_list(bank0)
    -- for _, v in ipairs(event_list) do
    --     print(audio.get_event_name(v))
    -- end
    -- sound_attack_ = ia.create("event:/Scene/attack")
    -- sound_click_ = ia.create("event:/UI/click")
    -- ia.play(sound_attack_)
    -- ia.destroy(sound_click_)
end

function audio_sys:data_changed()
    audio.update()
end

function audio_sys:exit()
    audio.shutdown()
end