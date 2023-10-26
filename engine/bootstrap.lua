if __ANT_RUNTIME__ then
    require "packagemanager"
    --require "runtime.debug"
else
    require "editor.init_vfs"
    require "packagemanager"
end
