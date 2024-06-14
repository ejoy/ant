#pragma once

namespace Rml {

class Script;
class Render;

Render* GetRender();
Script* GetScript();
void SetView(int viewid);

}
