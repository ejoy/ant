local im = import_package "ant.inputmgr"

local q = im.queue {
	BUTTON = { [1] = "LEFT", [2] = "RIGHT" },
	STATUS = function (s) return s*2 end,
	mouse = "_,BUTTON,STATUS",
	key = "BUTTON",
}

q:push(1, 2, "mouse", "xxx", 1, 2)
q:push("keyboard", 2, true)

for idx, msg, v1,v2,v3 in pairs(q) do
	print(msg, v1,v2,v3)
end
