local ecs = ...
local world = ecs.world
local w = world.w

local iom = ecs.require "ant.objcontroller|obj_motion"
local gizmo = ecs.require "gizmo.gizmo"
local queue = require "queue"
local gizmo_const = require "gizmo.const"
local cmd_queue = {
	cmd_undo = queue.new(),
	cmd_redo = queue.new()
}
local isTranDirty = false
function cmd_queue:undo()
	local cmd = queue.pop_last(self.cmd_undo)
	if not cmd then
		return
	end
	local e <close> = world:entity(cmd.eid)
	if not e then
		return
	end
	if cmd.action == gizmo_const.SCALE then
		iom.set_scale(e, cmd.oldvalue)
	elseif cmd.action == gizmo_const.ROTATE then
		iom.set_rotation(e, cmd.oldvalue)
		if gizmo.mode ~= gizmo_const.SELECT and localSpace then
			iom.set_rotation(e, cmd.oldvalue)
		end
	elseif cmd.action == gizmo_const.MOVE then
		iom.set_position(e, cmd.oldvalue)
		if gizmo.mode ~= gizmo_const.SELECT then
			iom.set_position(e, cmd.oldvalue)
		end
	end
	gizmo:set_position()
	gizmo:set_rotation()
	world:pub {"Gizmo", "update"}
	queue.push_last(self.cmd_redo, cmd)
end

function cmd_queue:redo()
	local cmd = queue.pop_last(self.cmd_redo)
	if not cmd then
		return
	end
	local e <close> = world:entity(cmd.eid)
	if not e then
		return
	end
	if cmd.action == gizmo_const.SCALE then
		iom.set_scale(e, cmd.newvalue)
	elseif cmd.action == gizmo_const.ROTATE then
		iom.set_rotation(e, cmd.newvalue)
		if gizmo.mode ~= gizmo_const.SELECT and localSpace then
			iom.set_rotation(e, cmd.newvalue)
		end
	elseif cmd.action == gizmo_const.MOVE then
		iom.set_position(e, cmd.newvalue)
		if gizmo.mode ~= gizmo_const.SELECT then
			iom.set_position(e, cmd.newvalue)
		end
	end
	gizmo:set_position()
	gizmo:set_rotation()
	world:pub {"Gizmo", "update"}
	queue.push_last(self.cmd_undo, cmd)
end

function cmd_queue:record(cmd)
	local redocmd = queue.pop_last(self.cmd_redo)
	while redocmd do
		redocmd = queue.pop_last(self.cmd_redo)
	end
	queue.push_last(self.cmd_undo, cmd)
end

return cmd_queue