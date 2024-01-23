local platform = require "bee.platform"

local WindowModePeek <const> = 0
local WindowModeLoop <const> = 1
local WindowMode <const> = {
    windows = WindowModePeek,
    android = WindowModePeek,
    macos = WindowModePeek,
    ios = WindowModeLoop,
}

if WindowMode[platform.os] == WindowModePeek then
    return require "peekwindow"
elseif WindowMode[platform.os] == WindowModeLoop then
    return require "loopwindow"
else
    error "window service unimplemented"
end
