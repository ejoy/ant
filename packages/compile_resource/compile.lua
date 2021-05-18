if __ANT_RUNTIME__ then
    return require "runtime.compile"
end

return require "editor.compile"
