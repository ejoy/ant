#pragma once

namespace Rml {

class Element;

struct StyleSheetNodeSelector {
	virtual ~StyleSheetNodeSelector() {}
	virtual bool IsApplicable(const Element* element, int a, int b) = 0;
};

struct StyleSheetNodeSelectorEmpty : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorFirstChild : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorFirstOfType : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorLastChild : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorLastOfType : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorNthChild : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorNthLastChild : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorNthLastOfType : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorNthOfType : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorOnlyChild : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

struct StyleSheetNodeSelectorOnlyOfType : public StyleSheetNodeSelector {
	bool IsApplicable(const Element* element, int a, int b) override;
};

}
