#pragma once

#include "queue.h"

struct msg {
    msg(char* s, size_t l)
        : str(s)
        , len(l)
    { }
    char*  str;
    size_t len;
};

struct msgqueue : public blocking_queue<msg> {
    typedef blocking_queue<msg> mybase;

    struct autodelete_msg : public msg {
        autodelete_msg()
            : msg(0, 0)
        { }
        autodelete_msg(autodelete_msg&& o)
            : msg(o.str, o.len)
        {
            o.str = 0;
            o.len = 0;
        }
        autodelete_msg& operator=(msg&& o) {
            str = o.str;
            len = o.len;
            o.str = 0;
            o.len = 0;
            return *this;
        }
        ~autodelete_msg() {
            if (str) delete[] str;
        }
    };
    void push(const char* str, size_t len) {
        if (str && len) {
            msg msg(new char[len], len);
            memcpy(msg.str, str, len);
            mybase::push(msg);
        }
        else {
            msg msg(0, 0);
            mybase::push(msg);
        }
    }
    bool try_pop(autodelete_msg& res) {
        return mybase::try_pop(res);
    }
};
