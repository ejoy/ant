local enginepath = os.getenv("ANTGE")

if enginepath == nil or enginepath == "" then
	print "ANTGE environment variable is not define!"
	return
end

dofile(enginepath .. "/libs/init.lua")

require "project_entry"
