local rdebug = require 'remotedebug'

local function initialize()
    return require 'new-debugger.master'
end

local function start()
    rdebug.start 'new-debugger.worker'
end

local function update()
	rdebug.probe 'update'
end

return {
    initialize = initialize,
    start = start,
    update = update,
}
