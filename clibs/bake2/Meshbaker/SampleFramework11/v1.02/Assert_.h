/*
* Copyright (c) 2008, Power of Two Games LLC
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of Power of Two Games LLC nor the
*       names of its contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY POWER OF TWO GAMES LLC ``AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL POWER OF TWO GAMES LLC BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#pragma once

#define POW2_ASSERTS_ENABLED

namespace pow2 { namespace Assert
{
	enum FailBehavior
	{
		Halt,
		Continue,
	};

	typedef FailBehavior (*Handler)(const char* condition,
									const char* msg,
									const char* file,
									int line);

	Handler GetHandler();
	void SetHandler(Handler newHandler);

	FailBehavior ReportFailure(const char* condition,
							   const char* file,
							   int line,
							   const char* msg, ...);
}}

#define POW2_HALT() __debugbreak()
#define POW2_UNUSED(x) do { (void)sizeof(x); } while(0)

#ifdef POW2_ASSERTS_ENABLED
	#define POW2_ASSERT(cond) \
		do \
		{ \
			if (!(cond)) \
			{ \
				if (pow2::Assert::ReportFailure(#cond, __FILE__, __LINE__, 0) == \
					pow2::Assert::Halt) \
					POW2_HALT(); \
			} \
		} while(0)

	#define POW2_ASSERT_MSG(cond, msg, ...) \
		do \
		{ \
			if (!(cond)) \
			{ \
				if (pow2::Assert::ReportFailure(#cond, __FILE__, __LINE__, (msg), __VA_ARGS__) == \
					pow2::Assert::Halt) \
					POW2_HALT(); \
			} \
		} while(0)

	#define POW2_ASSERT_FAIL(msg, ...) \
		do \
		{ \
			if (pow2::Assert::ReportFailure(0, __FILE__, __LINE__, (msg), __VA_ARGS__) == \
				pow2::Assert::Halt) \
			POW2_HALT(); \
		} while(0)

	#define POW2_VERIFY(cond) POW2_ASSERT(cond)
	#define POW2_VERIFY_MSG(cond, msg, ...) POW2_ASSERT_MSG(cond, msg, ##__VA_ARGS__)
#else
	#define POW2_ASSERT(condition) \
		do { POW2_UNUSED(condition); } while(0)
	#define POW2_ASSERT_MSG(condition, msg, ...) \
		do { POW2_UNUSED(condition); POW2_UNUSED(msg); } while(0)
	#define POW2_ASSERT_FAIL(msg, ...) \
		do { POW2_UNUSED(msg); } while(0)
	#define POW2_VERIFY(cond) (void)(cond)
	#define POW2_VERIFY_MSG(cond, msg, ...) \
		do { (void)(cond); POW2_UNUSED(msg); } while(0)
#endif

// SampleFramework11 Asserts
#ifdef _DEBUG
    #define UseAsserts_ 1
#else
    #define UseAsserts_ 0
#endif

#if UseAsserts_
    #define Assert_(x) POW2_ASSERT(x)
    #define AssertMsg_(x, msg, ...) POW2_ASSERT_MSG(x, msg, __VA_ARGS__)
    #define AssertFail_(msg, ...) POW2_ASSERT_FAIL(msg, __VA_ARGS__)
#else
    #define Assert_(x)
    #define AssertMsg_(x, msg, ...)
    #define AssertFail_(msg, ...)
#endif

#define UseStaticAsserts_ 1

#if UseStaticAsserts_
    #define StaticAssert_(x) static_assert(x, #x);
    #define StaticAssertMsg_(x, msg) static_assert(x, #x ", " msg);
#else
    #define StaticAssert_(x)
    #define StaticAssertMsg_(x, msg)
#endif
