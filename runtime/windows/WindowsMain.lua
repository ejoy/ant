--this is the windows ui
local root = os.getenv "ANTGE" or "."
local local_binpath = (os.getenv "BIN_PATH" or "clibs")
package.cpath = root .. "/" .. local_binpath .. "/?.dll;" ..
        root .. "/bin/?.dll"

package.path = root .. "/libs/?.lua;" .. root .. "/libs/?/?.lua;" .. root .. "/libs/fw/?.lua;" .. root .. "/runtime/core/?.lua;"
package.path = root .. "/libs/asset/?.lua;" .. package.path
----------------iup ui------------------
require "iuplua"
local width, height = 480, 320
local canvas = iup.canvas{
    rastersize = width .. "x" .. height
}


local start_button = iup.button{title = "start"}    --testing
local button_hbox = iup.hbox {start_button}

local vbox = iup.vbox{canvas, button_hbox}
local dlg = iup.dialog{
    vbox,
    title = "ant windows",
    size = "HALFxHALF",
}

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil
-----------------------------------------

local lanes = require "lanes"
if lanes.configure then lanes.configure() end
linda = lanes.linda()

err_log = ""
fw_dir = "runtime/ios/ant_ios/fw"
remote_dir = "runtime/Windows"

--at begin, only search for these locations
function ant_load(file_path, vfs_repo)
    --todo vfs load?
    local function path_normalize(fullname)
        local t = {}
        for m in fullname:gmatch("([^/\\]+)[/\\]?") do
            if m == ".." and next(t) then
                table.remove(t, #t)
            elseif m ~= "." then
                table.insert(t, m)
            end
        end

        return table.concat(t, "/")
    end

    local file, err = nil, ""
    if vfs_repo then
        file = vfs_repo:open(file_path)
        --print("vfs repo open", path)
    end

    if not file then
        --print("normalize path", file_path, path_normalize(file_path))
        file, err = io.open(path_normalize(file_path), "r")
        if not file then
            return nil, err
        end
    end

    --print("load file ~~ ".. path)
    local content = file:read("a")
    file:close()

    return load(content, "@" .. file_path)
end

--load io/msg_process
function add_module(path, ...)
    local res, err = ant_load(path)
    if not res then
        error("load module " .. path .. " error: " .. err)
        return
    end

    print("add module: " .. path .. " finished")
    return xpcall(res, debug.traceback, ...)
end

local fw_updating = false

RUN_FUNC_NAME = ""
RUN_FUNC = nil

local run_func = require "fw_run"
function start_button.action()
    print("start function")

    local res, err = add_module("runtime/windows/RunFrameWork.lua", err_log, fw_dir, remote_dir)
    if not res then
        error(err)
    end

    --fw_start
    print("start running")
    run_func("libs/fw/fw_start.lua", iup.GetAttributeData(canvas, "HWND"), width, height, fw_dir, remote_dir)

    fw_updating = true
end

if iup.MainLoopLevel() == 0 then
    while true do
        local msg = iup.LoopStep()
        if msg == iup.CLOSE then
            break
        end

        --fw_update
        if fw_updating then
            run_func("libs/fw/fw_update.lua")
        end
    end

    --fw_terminate
    if fw_updating then
        run_func("libs/fw/fw_terminate.lua")
    end
    iup.Close()
end
