local adb = require "adb"
if adb == "" then
    print "adb not found."
    return
end

local ltask = require "ltask"
local ServiceSubprocess = ltask.uniqueservice "subprocess"

local devices = {}

local function devices_list(str)
    local r = {}
    local first = true
    for w in str:gmatch '[^\n]+' do
        if first then
            first = false
        else
            if not w:match "^%s+$" then
                local id, info = w:match "^%s*([^%s]+)%s+([^%s].*)$"
                if id then
                    r[id] = info
                end
            end
        end
    end
    return r
end

local function update_devices(msg)
    local list = devices_list(msg)
    for k, v in pairs(devices) do
        if list[k] == nil then
            print('Android Device Detached:', k, v)
            ltask.send(devices[k].sid, "Detached")
            devices[k] = nil
        end
    end
    for k, v in pairs(list) do
        if devices[k] == nil then
            print('Android Device Attached:', k, v)
            devices[k] = {
                sid = ltask.spawn("android.proxy", adb, 17001),
                info = v,
            }
            ltask.send(devices[k].sid, "Attached")
        else
            devices[k].info = v
        end
    end
end

local function wait_connect()
    local exitcode, msg = ltask.call(ServiceSubprocess, "run", {
        adb, "wait-for-usb-device", "devices", "-l",
        stdout     = true,
        stderr     = "stdout",
        hideWindow = true,
    })
    if exitcode ~= 0 then
        error(('Adb failed: [%d]%s'):format(exitcode, msg))
        return
    end
    update_devices(msg)
end

local function wait_disconnect()
    local exitcode, msg = ltask.call(ServiceSubprocess, "run", {
        adb, "wait-for-usb-disconnect", "devices", "-l",
        stdout     = true,
        stderr     = "stdout",
        hideWindow = true,
    })
    if exitcode ~= 0 then
        error(('Adb failed: [%d]%s'):format(exitcode, msg))
        return
    end
    update_devices(msg)
end

while true do
    if next(devices) == nil then
        wait_connect()
    else
        wait_disconnect()
    end
end
