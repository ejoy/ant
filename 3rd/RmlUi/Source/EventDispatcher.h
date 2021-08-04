#pragma once

#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Event.h"

namespace Rml {

class Event;

bool DispatchEvent(Event& e, bool bubbles);

}
