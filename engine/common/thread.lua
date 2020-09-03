if __ANT_RUNTIME__ then
    return require "runtime.thread"
else
    return require "editor.thread"
end
