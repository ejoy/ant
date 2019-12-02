local save_entity = require "v2.save_entity"
local stringify_entity = require "v2.stringify_entity"

return {
    save_entity = function (w, eid)
        return stringify_entity(w, save_entity(w, eid))
    end,
    load_entity = require "v2.load_entity",
}
