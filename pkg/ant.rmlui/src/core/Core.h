#pragma once

namespace Rml {

class Script;
class Render;

bool Initialise();
void Shutdown();
void SetRender(Render* render);
Render* GetRender();
void SetScript(Script* script);
Script* GetScript();

}
