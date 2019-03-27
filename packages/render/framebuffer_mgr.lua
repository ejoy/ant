local mgr = {}; mgr.__index = mgr

local fb_mapper = {}
function mgr.bind(viewid, fb)
	fb_mapper[viewid] = fb
end

function mgr.get(viewid)
	return fb_mapper[viewid]
end

return mgr