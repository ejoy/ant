#pragma once
template<class T>
class singletonT{
    singletonT(singletonT &) = delete;
    singletonT& operator=(singletonT &) = delete;

public:
    singletonT() = default;
    ~singletonT() { destroy(); }
    
    template<typename ...Args>
    static T& create(Args ...args){
        assert(sinst == nullptr);
        sinst = new T(args...);
        return *sinst;
    }

    static void destroy(){
        if (sinst){
            delete sinst;
            sinst = nullptr;
        }
    }
    static T& get(){ assert(sinst); return *sinst;}

private:
    static inline T* sinst = nullptr;
};