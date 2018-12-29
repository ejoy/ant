local fsutil = require 'filesystem.fsutil'

if __ANT_RUNTIME__ then
    return fsutil(require 'filesystem.vfs')
end

local platform = require 'platform'

if platform.CRT == 'MinGW C Runtime' then
    return fsutil(require 'filesystem.mingw')
end

if platform.OS == 'OSX' then
    return fsutil(require 'filesystem.macos')
end

if platform.OS == 'Windows' then
    return fsutil(require 'filesystem.cpp')
end

if platform.OS == 'Linux' then
    return fsutil(require 'filesystem.cpp')
end

error 'Not implemented'
