local editor_watcher_system = {}

--watch entities eids -> {eid->serialize_entity}
editor_watcher_system.WATCH_ENTITIES = "WATCH_ENTITIES"
--
editor_watcher_system.SEND_ENTITIES = "SEND_ENTITIES"
--
editor_watcher_system.SEND_COMPONENT = "SEND_COMPONENT"
--
editor_watcher_system.SEND_HIERARCHY = "SEND_HIERARCHY"

--packages,systems,schemas
editor_watcher_system.REQUEST_WORLD_INFO = "REQUEST_WORLD_INFO"
editor_watcher_system.RESPONSE_WORLD_INFO = "RESPONSE_WORLD_INFO"

editor_watcher_system.MODIFY_COMPONENT = "MODIFY_COMPONENT"

return editor_watcher_system
