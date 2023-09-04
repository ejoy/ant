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
    return assert(GROUPS[k], "Invalid group:" .. k)
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

    world:group_flush(tag)
end

function ig.enable_from_name(gn, tag, enable)
    enable_group(ig.groupid(gn), tag, enable)
end

function ig.enable(gid, tag, enable)
    check_group(gid)
    enable_group(gid, tag, enable)
end

function ig.filter(gid, enable, maintag, vicetag, filtertag)
	ig.enable(gid, maintag, enable)
	w:filter(filtertag, ("%s %s"):format(maintag, vicetag))
end

local OBJMT =  {
    __index = {
        enable = function (self, gid, enable)
            ig.enable(gid, self.tag, enable)
        end,
        filter = function (self, gid, enable, vicetag, filtertag)
            ig.filter(gid, enable, self.tag, vicetag, filtertag)
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