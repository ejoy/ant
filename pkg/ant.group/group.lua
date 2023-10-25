local ecs   = ...
local world = ecs.world
local w     = world.w

local ig = {}

local DEF_GROUP<const> = 0
local NEXT_GROUP = DEF_GROUP + 1
local GROUPS = {
    DEFAULT = DEF_GROUP,
    DEF_GROUP = "DEFAULT",
}
function ig.register(name)
    if GROUPS[name] then
        error("duplicate group")
    end

    local gid = NEXT_GROUP
    NEXT_GROUP = NEXT_GROUP + 1

    GROUPS[name] = gid
    GROUPS[gid] = name

    return gid
end

local function check_group(k)
    -- k can be group name or gorup id
    return GROUPS[k] or error ("Invalid group:" .. k)
end

ig.groupid      = check_group
ig.groupname    = check_group
ig.check        = check_group
function ig.has(k)
    return GROUPS[k]
end

local function enable_group(gid, tag, enable)
    if enable then
        world:group_enable_tag(tag, gid)
    else
        world:group_disable_tag(tag, gid)
    end
end

local function enable_group_and_flush(gid, tag, enable)
    enable_group(gid, tag, enable)
    world:group_flush(tag)
end

function ig.enable_from_name(gn, tag, enable)
    enable_group_and_flush(ig.groupid(gn), tag, enable)
end

function ig.enable(gid, tag, enable)
    check_group(gid)
    enable_group_and_flush(gid, tag, enable)
end

ig.enable_no_flush = enable_group

function ig.flush(tag)
    world:group_flush(tag)
end

function ig.filter(filtertag, maintag, vicetag)
	w:filter(filtertag, ("%s %s"):format(maintag, vicetag))
end

local OBJMT =  {
    __index = {
        enable = function (self, gid, enable)
            enable_group(gid, self.tag, enable)
        end,
        flush = function(self)
            world:group_flush(self.tag)
        end,
        filter = function (self, filtertag, vicetag)
            ig.filter(filtertag, self.tag, vicetag)
        end,
    },
    __close = function (t)
        world:group_flush(t.tag)
    end
}

function ig.obj(tag)
    return setmetatable({tag=tag}, OBJMT)
end

return ig