#include <lua.hpp>
#include <string>
#include <string_view>
#include <bee/lua/udata.h>

#import <Foundation/Foundation.h>
#include "channel.h"

extern "C" {
#include <3rd/lua-seri/lua-seri.h>
}

typedef bool(^CompletionHandler)(NSURL*);

@interface TaskDelegate: NSObject
@property(nonatomic) int64_t id;
@property(nonatomic, strong) NSURL* file;
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
- (void)sendCompletionMessage:(TaskDelegate*)taskDelegate statusCode:(NSInteger)statusCode {
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
    lua_pushinteger(L, statusCode);
    lua_setfield(L, -2, "code");
    self.channel->push(seri_pack(L, 0, NULL));
}
- (void)sendCompletionMessage:(TaskDelegate*)taskDelegate statusCode:(NSInteger)statusCode content:(NSString*)content {
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
    lua_pushinteger(L, statusCode);
    lua_setfield(L, -2, "code");
    lua_pushstring(L, [content UTF8String]);
    lua_setfield(L, -2, "content");
    self.channel->push(seri_pack(L, 0, NULL));
}
- (void)sendProgressMessage:(TaskDelegate*)taskDelegate n:(int64_t)n total:(int64_t)total {
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
    lua_pushinteger(L, n);
    lua_setfield(L, -2, "n");
    if (total != NSURLSessionTransferSizeUnknown) {
        lua_pushinteger(L, total);
        lua_setfield(L, -2, "total");
    }
    self.channel->push(seri_pack(L, 0, NULL));
}
- (void)sendResponseMessage:(TaskDelegate*)taskDelegate data:(NSData*) data {
    lua_State* L = self.L;
    if (!L) {
        return;
    }
    lua_settop(L, 0);
    lua_newtable(L);
    lua_pushinteger(L, [taskDelegate id]);
    lua_setfield(L, -2, "id");
    lua_pushstring(L, "response");
    lua_setfield(L, -2, "type");
    lua_pushlstring(L, (const char*)[data bytes], [data length]);
    lua_setfield(L, -2, "data");
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
    [self sendProgressMessage:taskDelegate n:totalBytesWritten total:totalBytesExpectedToWrite];
}

- (void)URLSession:(NSURLSession *)session 
              task:(NSURLSessionTask *)task 
   didSendBodyData:(int64_t)bytesSent 
    totalBytesSent:(int64_t)totalBytesSent 
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    TaskDelegate* taskDelegate = self.tasks[task];
    if (taskDelegate == nil) {
        return;
    }
    [self sendProgressMessage:taskDelegate n:totalBytesSent total:totalBytesExpectedToSend];
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
    if (!error && ![taskDelegate file]) {
        [self sendCompletionMessage:taskDelegate];
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

    NSInteger statusCode = 200;
    NSURLResponse* response = [downloadTask response];
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        statusCode = ((NSHTTPURLResponse*)response).statusCode;
    }
    if ([taskDelegate file] != nil) {
        NSError* error;
        NSFileManager* fileManager = [NSFileManager defaultManager];
        [fileManager removeItemAtURL:[taskDelegate file] error:&error];
        if (![fileManager moveItemAtURL:location toURL:[taskDelegate file] error:&error]) {
            [self sendErrorMessage:taskDelegate error: error];
            return;
        }
        [self sendCompletionMessage:taskDelegate statusCode:statusCode];
    }
    else {
        NSError* error;
        NSString* content = [NSString stringWithContentsOfFile:[location path] encoding:NSUTF8StringEncoding error:&error];
        if (!content) {
            [self sendErrorMessage:taskDelegate error: error];
            return;
        }
        [self sendCompletionMessage:taskDelegate statusCode:statusCode content:content];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    TaskDelegate* taskDelegate = self.tasks[dataTask];
    if (taskDelegate == nil) {
        return;
    }
    [self sendResponseMessage:taskDelegate data:data];
}
@end

struct HttpcSession {
    void* delegate;
    void* session;
    HttpcSession(SessionDelegate * d, NSURLSession* s)
        : delegate((__bridge_retained void*)d)
        , session((__bridge_retained void*)s)
    {}
    ~HttpcSession() {
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
    return { str, sz };
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
    NSURLSession* session = [NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:nil];
    bee::lua::newudata<HttpcSession>(L, delegate, session);
    return 1;
}

static int download(lua_State* L) {
    auto& s = bee::lua::checkudata<HttpcSession>(L, 1);
    SessionDelegate * delegate = s.objc_delegate();
    NSURLSession* session = s.objc_session();
    const char* downloadStr = luaL_checkstring(L, 2);
    NSURL* downloadUrl = [NSURL URLWithString:[NSString stringWithUTF8String:downloadStr]];
    TaskDelegate* taskDelegate = [[TaskDelegate alloc] init];
    taskDelegate.id = [delegate getTaskId];
    if (lua_isnoneornil(L, 3)) {
        taskDelegate.file = nil;
    }
    else {
        const char* fileStr = luaL_checkstring(L, 3);
        taskDelegate.file = [NSURL fileURLWithPath:[NSString stringWithUTF8String:fileStr]];
    }
    NSURLSessionDownloadTask* task = [session downloadTaskWithURL:downloadUrl];
    delegate.tasks[task] = taskDelegate;
    [task resume];
    lua_pushinteger(L, [taskDelegate id]);
    return 1;
}

static int upload(lua_State* L) {
    auto& s = bee::lua::checkudata<HttpcSession>(L, 1);
    SessionDelegate* delegate = s.objc_delegate();
    NSURLSession* session = s.objc_session();
    NSString* uploadStr = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
    NSString* fileStr = [NSString stringWithUTF8String:luaL_checkstring(L, 3)];
    NSString* nameStr = [NSString stringWithUTF8String:luaL_checkstring(L, 4)];
    NSString* boundaryStr = [NSString stringWithUTF8String:luaL_checkstring(L, 5)];
    NSURL* uploadUrl = [NSURL URLWithString:uploadStr];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:uploadUrl];
    request.HTTPMethod = @"POST";
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=\"%@\"", boundaryStr] forHTTPHeaderField:@"Content-Type"];
    NSData* boundaryData = [[NSString stringWithFormat:@"--%@", boundaryStr] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* newlineData = [@"\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData* body = [NSMutableData data];
    [body appendData:boundaryData];
    [body appendData:newlineData];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"", nameStr] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:newlineData];
    [body appendData:newlineData];
    [body appendData:[NSData dataWithContentsOfFile:fileStr]];
    [body appendData:boundaryData];
    [body appendData:[@"--" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:newlineData];

    NSURLSessionUploadTask* task = [session uploadTaskWithRequest:request fromData:body];
    TaskDelegate* taskDelegate = [[TaskDelegate alloc] init];
    taskDelegate.id = [delegate getTaskId];
    taskDelegate.file = nil;
    delegate.tasks[task] = taskDelegate;
    [task resume];
    lua_pushinteger(L, [taskDelegate id]);
    return 1;
}

static int select(lua_State* L) {
    auto& s = bee::lua::checkudata<HttpcSession>(L, 1);
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
        { "upload", upload },
        { "select", select },
        { NULL, NULL },
    };
    luaL_newlib(L, l);
    return 1;
}

namespace bee::lua {
    template <>
    struct udata<HttpcSession> {
        static inline auto metatable = +[](lua_State*){};
    };
}
