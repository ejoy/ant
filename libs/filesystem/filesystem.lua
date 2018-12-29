local vfs = require 'vfs'

if not vfs.localvfs then
    return require 'filesystem.vfs'
end

local platform = require 'platform'

if platform.CRT == 'MinGW C Runtime' then
    return require 'filesystem.mingw'
end

if platform.OS == 'OSX' then
    return require 'filesystem.macos'
end

if platform.OS == 'Windows' then
    return require 'filesystem.cpp'
end

if platform.OS == 'Linux' then
    return require 'filesystem.cpp'
end

error 'Not implemented'
