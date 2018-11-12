dofile 'libs/init.lua'

local reponame = assert((...), 'Need repo name')

local fs = require 'cppfs'
local cwd = fs.current_path()

local function mkdir(path)
    if fs.exists(path) then
        if not fs.is_directory(path) then
            fs.remove(path)
            fs.create_directories(path)
        end
	else
		fs.create_directories(path)
	end
end

local function cpdir(from, to)
	for fromfile in from:list_directory() do
		if fs.is_directory(fromfile) then
            cpdir(fromfile, to / fromfile:filename())
		else
            fs.create_directories(to)
            fs.copy_file(fromfile, to / fromfile:filename(), true)
		end
	end
end

local repopath = fs.path(os.getenv 'UserProfile') / 'Documents' / reponame
for i = 0, 255 do
	mkdir(repopath / '.repo' / ('%02x'):format(i))
end

cpdir(cwd / 'runtime' / 'core' / 'firmware', repopath / 'firmware')
