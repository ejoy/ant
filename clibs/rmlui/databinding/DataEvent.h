#pragma once

#include <core/EventListener.h>
#include <memory>

namespace Rml {

class Element;
class DataModel;
class DataExpression;
using DataExpressionPtr = std::unique_ptr<DataExpression>;

class DataEvent {
public:
    DataEvent(Element* element);
    ~DataEvent();
    bool Initialize(DataModel& model, Element* element, const std::string& expression, const std::string& modifier);
    Element* GetElement() const;

private:
	ObserverPtr<Element> element;
    EventListener* listener;
};

}
