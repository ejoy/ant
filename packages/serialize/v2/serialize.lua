local save_entity = require "v2.save_entity"
local stringify_entity = require "v2.stringify_entity"

return {
    save_entity = function (w, eid, policies)
        return stringify_entity(w, policies, save_entity(w, eid))
    end,
}
