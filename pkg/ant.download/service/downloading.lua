local ltask = require "ltask"
local download = require "download"

local downloadService

local S = {}

local cancel = {}

function S.init(s)
	downloadService = s
end

local function progress(id, p, m, status)
	ltask.send(downloadService, "_p", id, p, m, status)
end

function S.download(id, url, filename)
	local cobj, ptr = download.cancel_object()
	cancel[id] = cobj
	ltask.send(downloadService, "_c", id, ptr)
	download.download(url, filename, progress, id, cobj)
end

function S.finish(id)
	cancel[id] = nil
end

return S
