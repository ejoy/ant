local im = import_package "inputmgr"

local q = im.queue {
	BUTTON = { [1] = "LEFT", [2] = "RIGHT" },
	STATUS = function (s) return s*2 end,
	mouse = "_,BUTTON,STATUS",
	key = "BUTTON",
}

q:push("mouse", "xxx", 1, 2)
q:push("key", 2)

for idx, msg, v1,v2,v3 in pairs(q) do
	print(msg, v1,v2,v3)
end
