#pragma once

#include <vector>
#include <forward_list>

template<typename NODE>
struct node_container {
    node_container(int c): nodes(c){}
    int alloc(){
        int Nidx;
        if (!freelist.empty()){
            Nidx = freelist.front();
            freelist.pop_front();
        } else {
            Nidx = n++;
            if (n == (int)nodes.size()){
                nodes.resize(n*2);
            }
        }

        nodes[Nidx].clear();
        return Nidx;
    }

    void dealloc(int Nidx){
        freelist.push_front(Nidx);
    }

    inline bool isvalid(int Nidx) const {
        return 0 <= Nidx && Nidx < n;
    }

    std::vector<NODE> nodes;
    std::forward_list<int>   freelist;
    int n = 0;
};