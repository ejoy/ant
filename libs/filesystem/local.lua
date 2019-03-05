local fsutil = require 'filesystem.fsutil'

if __ANT_RUNTIME__ then
    return fsutil(require 'filesystem.runtime')
end

return fsutil(require 'filesystem.cpp')
