#include <lua.hpp>
#include <mutex>
#include <queue>
#include <string>
#include <string_view>
#include <variant>
#include <vector>
#include <bee/lua/binding.h>
#include <bee/thread/spinlock.h>

#import <Foundation/Foundation.h>

extern "C" {
#include <3rd/lua-seri/lua-seri.h>
}

typedef bool(^CompletionHandler)(NSURL*);
typedef void(^SelectHandler)(void* data);

class MessageChannel {
public:
    void push(void* data) {
        std::unique_lock<bee::spinlock> lk(mutex);
        queue.push_back(data);
    }
    void select(SelectHandler handler) {
        std::unique_lock<bee::spinlock> lk(mutex);
        if (queue.empty()) {
            return;
        }
        for (void* data: queue) {
            handler(data);
        }
        queue.clear();
    }
private:
    std::vector<void*> queue;
    bee::spinlock mutex;
};

@interface TaskDelegate: NSObject
@property(nonatomic) int64_t id;
@property(nonatomic, strong) NSURL* target;
@end
@implementation TaskDelegate
@end

@interface SessionDelegate: NSObject<NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSURLSessionStreamDelegate>
@property(nonatomic) int64_t taskid;
@property(nonatomic, strong) NSMutableDictionary<NSURLSessionTask*, TaskDelegate*>* tasks;
@property(nonatomic) lua_State* L;
@property(nonatomic) MessageChannel* channel;
@end
@implementation SessionDelegate 

- (id)init {
    self = [super init];
    if (nil == self) {
        return nil;
    }
    self.taskid = 0;
    self.tasks = [NSMutableDictionary dictionaryWithCapacity:0];
    self.L = luaL_newstate();
    self.channel = new MessageChannel;
    return self;
}

- (int64_t)getTaskId {
    return ++self.taskid;
}
- (void)sendErrorMessage:(TaskDelegate*)taskDelegate error:(NSError*)error {
    lua_State* L = self.L;
    if (!L) {
        return;
    }
    lua_settop(L, 0);
    lua_newtable(L);
    lua_pushinteger(L, [taskDelegate id]);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, "error");
    lua_setfield(L, -2, "type");
    lua_pushstring(L, [[error localizedDescription] UTF8String]);
    lua_setfield(L, -2, "errmsg");
    self.channel->push(seri_pack(L, 0, NULL));
}
- (void)sendCompletionMessage:(TaskDelegate*)taskDelegate {
    lua_State* L = self.L;
    if (!L) {
        return;
    }
    lua_settop(L, 0);
    lua_newtable(L);
    lua_pushinteger(L, [taskDelegate id]);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, "completion");
    lua_setfield(L, -2, "type");
    self.channel->push(seri_pack(L, 0, NULL));
}
- (void)sendProgressMessage:(TaskDelegate*)taskDelegate written:(int64_t)written total:(int64_t)total {
    lua_State* L = self.L;
    if (!L) {
        return;
    }
    lua_settop(L, 0);
    lua_newtable(L);
    lua_pushinteger(L, [taskDelegate id]);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, "progress");
    lua_setfield(L, -2, "type");
    lua_pushinteger(L, written);
    lua_setfield(L, -2, "written");
    if (total != NSURLSessionTransferSizeUnknown) {
        lua_pushinteger(L, total);
        lua_setfield(L, -2, "total");
    }
    self.channel->push(seri_pack(L, 0, NULL));
}

-(void)select:(SelectHandler)handler {
    self.channel->select(handler);
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    TaskDelegate* taskDelegate = self.tasks[downloadTask];
    if (taskDelegate == nil) {
        return;
    }
    [self sendProgressMessage:taskDelegate written:totalBytesWritten total:totalBytesExpectedToWrite];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes {
}

- (void)URLSession:(NSURLSession *)session 
              task:(NSURLSessionTask *)task 
didCompleteWithError:(NSError *)error {
    TaskDelegate* taskDelegate = self.tasks[task];
    if (taskDelegate == nil) {
        return;
    }
    [self sendErrorMessage:taskDelegate error: error];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    TaskDelegate* taskDelegate = self.tasks[downloadTask];
    if (taskDelegate == nil) {
        return;
    }
    self.tasks[downloadTask] = nil;
    NSError* error;
    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:[taskDelegate target] error:&error];
    if (![fileManager moveItemAtURL:location toURL:[taskDelegate target] error:&error]) {
        [self sendErrorMessage:taskDelegate error: error];
        return;
    }
    [self sendCompletionMessage:taskDelegate];
}
@end

struct LuaURLSession {
    void* delegate;
    void* session;
    LuaURLSession(SessionDelegate * d, NSURLSession* s)
        : delegate((__bridge_retained void*)d)
        , session((__bridge_retained void*)s)
    {}
    ~LuaURLSession() {
        SessionDelegate * ns_delegate = (__bridge_transfer SessionDelegate *)delegate;
        NSURLSession* ns_session = (__bridge_transfer NSURLSession*)session;
        lua_close(ns_delegate.L);
        delete ns_delegate.channel;
        ns_delegate.L = nullptr;
        ns_delegate.channel = nullptr;
        (void)ns_session;
        delegate = nullptr;
        session = nullptr;
    }
    SessionDelegate * objc_delegate() const {
        return (__bridge SessionDelegate *)delegate;
    }
    NSURLSession* objc_session() const {
        return (__bridge NSURLSession*)session;
    }
};

static std::string_view lua_checkstrview(lua_State* L, int idx) {
    size_t sz = 0;
    const char* str = luaL_checklstring(L, idx, &sz);
    return std::string_view(str, sz);
}

static int session(lua_State* L) {
    auto config_name = lua_checkstrview(L, 1);
    NSURLSessionConfiguration* config;
    if (config_name == "default") {
        config = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    else if (config_name == "ephemeral") {
        config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    }
    else {
        config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSString stringWithUTF8String:config_name.data()]];
    }
    SessionDelegate * delegate = [[SessionDelegate  alloc] init];
    NSOperationQueue* operation = [[NSOperationQueue alloc] init];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:operation];
    bee::lua::newudata<LuaURLSession>(L, delegate, session);
    return 1;
}

static int download(lua_State* L) {
    auto& s = bee::lua::checkudata<LuaURLSession>(L, 1);
    SessionDelegate * delegate = s.objc_delegate();
    NSURLSession* session = s.objc_session();
    const char* downloadStr = luaL_checkstring(L, 2);
    const char* targetStr = luaL_checkstring(L, 3);
    NSURL* downloadUrl = [NSURL URLWithString:[NSString stringWithUTF8String:downloadStr]];
    NSURL* targetUrl = [NSURL fileURLWithPath:[NSString stringWithUTF8String:targetStr]];
    NSURLSessionDownloadTask* task = [session downloadTaskWithURL:downloadUrl];
    TaskDelegate* taskDelegate = [[TaskDelegate alloc] init];
    taskDelegate.id = [delegate getTaskId];
    taskDelegate.target = targetUrl;
    delegate.tasks[task] = taskDelegate;
    [task resume];
    lua_pushinteger(L, [taskDelegate id]);
    return 1;
}

template <typename>
constexpr bool always_false_v = false;

static int select(lua_State* L) {
    auto& s = bee::lua::checkudata<LuaURLSession>(L, 1);
    SessionDelegate * delegate = s.objc_delegate();
    lua_newtable(L);
    __block lua_Integer n = 0;
    [delegate select:^(void* data){
        seri_unpackptr(L, data);
        lua_seti(L, -2, ++n);
    }];
    return 1;
}

extern "C"
int luaopen_httpc(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "session", session },
        { "download", download },
        { "select", select },
        { NULL, NULL },
    };
    luaL_newlib(L, l);
    return 1;
}

namespace bee::lua {
    template <>
    struct udata<LuaURLSession> {
        static inline auto name = "LuaURLSession";
        static inline auto metatable = +[](lua_State*){};
    };
}
