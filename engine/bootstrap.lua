if __ANT_EDITOR__ then
    require "editor.init"
elseif not __ANT_RUNTIME__ then
    require "game.init"
end

require "packagemanager"
