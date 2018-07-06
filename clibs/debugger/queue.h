#pragma once

#include <cassert>
#include <memory>

#if defined(_MSC_VER)
#	include <intrin.h>
#	if defined(_M_IX86)
#		pragma intrinsic( _InterlockedExchange )
#		undef _InterlockedExchangePointer
#		define _InterlockedExchangePointer(_Target, _Value) reinterpret_cast<void *>(static_cast<__w64 long>(_InterlockedExchange( \
	static_cast<long volatile *>(reinterpret_cast<__w64 long volatile *>(static_cast<void * volatile *>(_Target))), \
	static_cast<long>(reinterpret_cast<__w64 long>(static_cast<void *>(_Value))))))
#	elif defined(_M_X64)
#		pragma intrinsic( _InterlockedExchangePointer )
#	else
#		error "Microsoft Visual C++ compiler: unsupported processor architecture"
#	endif
#else
#	include <cstddef>
#	include <atomic>
#endif

namespace base {
#if defined(_MSC_VER)
	template <typename T>
	class atomic;

	template <typename T>
	class atomic<T*>
	{
	public:
		inline atomic() : ptr(nullptr) { }
		inline atomic(T *ptr_) : ptr(ptr_) { }
		inline ~atomic() { }
		inline T *exchange(T *val) { return (T*)_InterlockedExchangePointer((void*volatile*)&ptr, val); }
	private:
		volatile T *ptr;
	private:
		atomic(const atomic&);
		atomic& operator=(const atomic&);
	};
#else
	using std::atomic;
#endif

	template <typename T, ::std::size_t N>
	struct queue_chunk
	{
		T values [N];
		queue_chunk<T, N>* next;
	};

	template <typename T, ::std::size_t N, typename Alloc>
	class queue_alloc
		: public Alloc::template rebind<queue_chunk<T, N> >::other
	{
	public:
		typedef queue_chunk<T, N>                                  chunk_type;
		typedef typename Alloc::template rebind<chunk_type>::other base_type;

	public:
		chunk_type*  allocate()
		{
			return base_type::allocate(1);
		}

		void deallocate(chunk_type* p)
		{
			base_type::deallocate(p, 1);
		}
	};

	template <typename T, ::std::size_t N = 256, typename Alloc = ::std::allocator<T>, typename AtomicChunk = atomic<queue_chunk<T, N>*>>
	class queue
		: public queue_alloc<T, N, Alloc>
	{
	public:
		typedef queue_alloc<T, N, Alloc>        alloc_type;
		typedef typename alloc_type::chunk_type chunk_type;
		typedef T                               value_type;
		typedef value_type*                     pointer;
		typedef value_type&                     reference;
		typedef value_type const&               const_reference;

	public:
		queue()
			: begin_chunk(alloc_type::allocate())
			, begin_pos(0)
			, back_chunk(begin_chunk)
			, back_pos(0)
			, end_chunk(begin_chunk)
			, end_pos(0)
			, spare_chunk()
		{
			assert (begin_chunk);
			do_push();
			assert(empty());
		}

		virtual ~queue()
		{
			clear();
			alloc_type::deallocate(begin_chunk);
			chunk_type *sc = spare_chunk.exchange(nullptr);
			if (sc)
				alloc_type::deallocate(sc);
		}

		void clear()
		{
			for (;;) {
				if (begin_chunk == end_chunk) {
					break;
				}
				chunk_type *o = begin_chunk;
				begin_chunk = begin_chunk->next;
				alloc_type::deallocate(o);
			}
		}

		reference front()
		{
			return begin_chunk->values[begin_pos];
		}

		const_reference front() const
		{
			return begin_chunk->values[begin_pos];
		}

		reference back()
		{
			return back_chunk->values[back_pos];
		}

		const_reference back() const
		{
			return back_chunk->values[back_pos];
		}

		void push(value_type&& val)
		{
			new(&back()) T(::std::move(val));
			do_push();
		}

		void push(const_reference val)
		{
			new(&back()) T(val);
			do_push();
		}

		void pop()
		{
			assert(!empty());
			front().~T();
			do_pop();
		}

		bool try_pop(reference val)
		{
			if (empty())
				return false;
			val.~T();
			new(&val) T(front());
			pop();
			return true;
		}

		void do_push()
		{
			back_chunk = end_chunk;
			back_pos = end_pos;

			if (++end_pos != N)
				return;

			chunk_type *sc = spare_chunk.exchange(nullptr);
			if (sc) {
				end_chunk->next = sc;
			} else {
				end_chunk->next = alloc_type::allocate();
				assert (end_chunk->next);
			}
			end_chunk = end_chunk->next;
			end_pos = 0;
		}

		void do_pop()
		{
			if (++ begin_pos == N) {
				chunk_type *o = begin_chunk;
				begin_chunk = begin_chunk->next;
				begin_pos = 0;

				chunk_type *cs = spare_chunk.exchange(o);
				if (cs)
					alloc_type::deallocate(cs);
			}
		}

		// It's safe in pop thread.
		bool empty() const
		{
			volatile chunk_type* _back_chunk = back_chunk;
			volatile size_t      _back_pos   = back_pos;

			if ((begin_chunk == _back_chunk) && (begin_pos == _back_pos))
				return true;

			return false;
		}

	protected:
		chunk_type* begin_chunk;
		size_t      begin_pos;
		chunk_type* back_chunk;
		size_t      back_pos;
		chunk_type* end_chunk;
		size_t      end_pos;
		AtomicChunk spare_chunk;

	private:
		queue(const queue&);
		queue& operator=(const queue&);
	};
}