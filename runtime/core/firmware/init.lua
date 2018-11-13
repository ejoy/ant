local boot = assert(loadfile("firmware/bootstrap.lua"))
local vfs = boot("firmware", "127.0.0.1", 2018)
package.loaded.vfs = vfs
vfs.open('./')

local function loadfile(path)
    local realpath = vfs.realpath(path)
    if not realpath then
        return nil, ('%s:No such file or directory'):format(path)
    end
    local f, err = io.open(realpath, 'rb')
    if not f then
        return nil, err
    end
    local str = f:read 'a'
    f:close()
    return load(str, '@vfs://' .. path)
end

assert(loadfile("main.lua"))()
