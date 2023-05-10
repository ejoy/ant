local ecs = ...
local platform = require "bee.platform"
local assetmgr = import_package "ant.asset"
local audio_sys = ecs.system "audio_system"
local ia = ecs.interface "audio_interface"
local caudio
if "android" ~= platform.os then
    caudio = require "audio"
end
function ia.create(eventname)
    if not caudio then return end
    return caudio.create(eventname)
end
local bank = {}
function ia.load_bank(filename)
    if not caudio then return end
    if not bank[filename] then
        local res = assetmgr.resource(filename)
        bank[filename] = caudio.load_bank(res.rawdata)
    end
    return bank[filename]
end

local sound_event = {}

function ia.play(event_name)
    if not caudio then return end
    if not sound_event[event_name] then
        sound_event[event_name] = ia.create(event_name)
    end
    local ev = sound_event[event_name]
    if ev then
        caudio.play(ev)
    end
end

function ia.destroy(event_name)
    if not caudio then return end
    if event_name then
        local event = sound_event[event_name]
        if event then
            caudio.destroy(event)
            sound_event[event_name] = nil
        end
    else
        for _, value in pairs(sound_event) do
            caudio.destroy(value)
        end
        sound_event = {}
    end
end

-- function ia.play(event)
--     caudio.play(event)
-- end

-- function ia.destroy(event)
--     caudio.destroy(event)
-- end

function ia.stop(event)
    if not caudio then return end
    caudio.stop(event)
end

function ia.get_event_list(b)
    if not caudio then return {} end
    return caudio.get_event_list(b)
end

function ia.get_event_name(se)
    if not caudio then return "" end
    return caudio.get_event_name(se)
end

function audio_sys:init()
    if not caudio then return end
    caudio.init()
    --test
    local bankname = "/pkg/tools.prefab_editor/res/sounds/Master.bank"
    local master = ia.load_bank(bankname)
    if not master then
        print("LoadBank Faied. :", bankname)
    end
    bankname = "/pkg/tools.prefab_editor/res/sounds/Master.strings.bank"
    local bank1 = ia.load_bank(bankname)
    if not bank1 then
        print("LoadBank Faied. :", bankname)
    end
    bankname = "/pkg/tools.prefab_editor/res/sounds/Construt.bank"
    local construt = ia.load_bank(bankname)
    if not construt then
        print("LoadBank Faied. :", bankname)
    end
    bankname = "/pkg/tools.prefab_editor/res/sounds/UI.bank"
    local ui = ia.load_bank(bankname)
    if not ui then
        print("LoadBank Faied. :", bankname)
    end
    local bank_list = caudio.get_bank_list()
    for _, v in ipairs(bank_list) do
        print(caudio.get_bank_name(v))
    end

    local event_list = caudio.get_event_list(master)
    for _, v in ipairs(event_list) do
        print(caudio.get_event_name(v))
    end
    local event_list = caudio.get_event_list(construt)
    for _, v in ipairs(event_list) do
        print(caudio.get_event_name(v))
    end
    local event_list = caudio.get_event_list(ui)
    for _, v in ipairs(event_list) do
        print(caudio.get_event_name(v))
    end
    -- sound_event[event_name] = ia.create(event_name)
    -- event_name = "event:/UI/click"
    -- sound_event[event_name] = ia.create(event_name)
    ia.play("event:/background")
end

function audio_sys:data_changed()
    if not caudio then return end
    caudio.update()
end

function audio_sys:exit()
    if not caudio then return end
    ia.destroy()
    caudio.shutdown()
end