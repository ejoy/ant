#include "pch.h"
#include "system.h"
#include <assert.h>

System::System()
    : mStartTime(std::chrono::steady_clock::now()){
}

double System::GetElapsedTime(){
    auto now = std::chrono::steady_clock::now();
    auto duration = now - mStartTime;
    auto time = std::chrono::duration_cast<std::chrono::milliseconds>(duration);
	return time.count() / 1000.;
}

template <typename Container>
void str_split(std::string const& str, Container& cont, std::string const& delim) {
    std::size_t current, previous = 0;
    current = str.find_first_of(delim);
    while (current != std::string::npos) {
        cont.emplace_back(str.substr(previous, current - previous));
        previous = current + 1;
        current = str.find_first_of(delim, previous);
    }
    cont.emplace_back(str.substr(previous, current - previous));
}

template <typename Container>
std::string str_join(Container const& cont, std::string const& delim) {
    auto it = cont.begin();
    std::string r = *it++;
    for (; it != cont.end(); ++it) {
        r += delim;
        r += *it;
    }
    return r;
}

void System::JoinPath(Rml::String& out, const Rml::String& base, const Rml::String& path) {
    std::vector<std::string> path_elems;
    str_split(base, path_elems, "/");
    assert(path_elems.size() > 0);
    if (path_elems.size() > 0) {
        path_elems.pop_back();
    }
    str_split(path, path_elems, "/");

    std::deque<std::string> stack;
    for (auto& e : path_elems) {
        if (e == ".." && !stack.empty() && stack.back() != "..") {
            stack.pop_back();
        }
        else if (e != ".") {
            stack.push_back(e);
        }
    }
    out = str_join(stack, "/");
}
