#pragma once

#include <stdint.h>

namespace Rml {
    template <typename T>
    class SharedPtr {
    public:
        SharedPtr() = default;
        SharedPtr(std::nullptr_t) {}
        SharedPtr(T* ptr)
            : ptr_(ptr)
            , ref_(new RefCount)
        {}
        SharedPtr(const SharedPtr& r)
            : ptr_(r.ptr_)
            , ref_(r.ref_)
        {
            ref_->ref();
        }
        SharedPtr(SharedPtr&& r) 
            : ptr_(r.ptr_)
            , ref_(r.ref_)
        {
            r.ptr_ = nullptr;
            r.ref_ = nullptr;
        }
        template <typename Y>
        SharedPtr(Y* ptr)
            : ptr_(static_cast<T*>(ptr))
            , ref_(new RefCount)
        {}
        template <typename Y>
        SharedPtr(const SharedPtr<Y>& r)
            : ptr_(static_cast<T*>(r.ptr_))
            , ref_(r.ref_)
        {
            ref_->ref();
        }
        template <class Y>
        SharedPtr(SharedPtr<Y>&& r) 
            : ptr_(static_cast<T*>(r.ptr_))
            , ref_(r.ref_)
        {
            r.ptr_ = nullptr;
            r.ref_ = nullptr;
        }
        ~SharedPtr() {
            if (ref_) {
                ref_->unref();
                if (ref_->count() == 0) {
                    delete ptr_;
                    delete ref_;
                }
            }
        }
        SharedPtr& operator=(const SharedPtr& r) {
            SharedPtr(r).swap(*this);
            return *this;
        }
        SharedPtr& operator=(SharedPtr&& r) {
            SharedPtr(std::move(r)).swap(*this);
            return *this;
        }
        template <typename Y>
        SharedPtr& operator=(const SharedPtr<Y>& r) {
            SharedPtr(r).swap(*this);
            return *this;
        }
        template <typename Y>
        SharedPtr& operator=(SharedPtr<Y>&& r) {
            SharedPtr(std::move(r)).swap(*this);
            return *this;
        }
        void reset() {
            SharedPtr().swap(*this);
        }
        template <typename Y>
        void reset(Y* ptr) {
            SharedPtr(ptr).swap(*this);
        }
        void swap(SharedPtr& r) {
            std::swap(ptr_, r.ptr_);
            std::swap(ref_, r.ref_);
        }
        T& operator*() const {
            return *get();
        }
        T* operator->() const {
            return get();
        }
        explicit operator bool() const {
            return get() != nullptr;
        }
        T* get() const {
            return ptr_;
        }
        uint64_t use_count() {
            return ref_? ref_->count(): 0;
        }
        bool operator==(const SharedPtr& r) const {
            return (ptr_ == r.ptr_) && (ref_ == r.ref_);
        }
    private:
        class RefCount {
        public:
            RefCount() = default;
            RefCount(const RefCount& r) = delete;
            RefCount& operator=(const RefCount& r) = delete;
            void ref() { ++count_; }
            void unref() { --count_; }
            uint64_t count() { return count_; }
        private:
            uint64_t count_ = 1;
        };

        T* ptr_ { nullptr };
        RefCount* ref_ { nullptr };
    };
    template <typename T, typename... Args>
    SharedPtr<T> MakeShared(Args&&... args) {
        return {new T(std::forward<Args>(args)...)};
    }
}
