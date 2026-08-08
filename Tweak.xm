// =============================================================
//  DisconnectAppNetwork — 全局断网插件（无弹窗、防闪退）
//  原理：创建真实任务并立即取消，返回非 nil 任务，避免 App 崩溃
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static BOOL DKShouldBlockRequest(NSURLRequest *request) {
    return YES; // 拦截所有请求
}

// ========== Hook NSURLSession ==========
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        // 1. 创建真实任务（不传入 completionHandler，避免系统回调）
        NSURLSessionDataTask *task = %orig(request, nil);
        // 2. 立即取消任务（阻止网络请求）
        [task cancel];
        // 3. 手动调用传入的 completionHandler，传递断网错误
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        // 4. 返回已取消的任务（非 nil，避免 App 崩溃）
        return task;
    }
    return %orig(request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        // 无回调版本，直接创建并取消任务
        NSURLSessionDataTask *task = %orig(request);
        [task cancel];
        return task;
    }
    return %orig(request);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSURLSessionUploadTask *task = %orig(request, fileURL, nil);
        [task cancel];
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return task;
    }
    return %orig(request, fileURL, completionHandler);
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSURLSessionDownloadTask *task = %orig(request, nil);
        [task cancel];
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return task;
    }
    return %orig(request, completionHandler);
}

%end

// ========== Hook NSURLConnection ==========
%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    if (DKShouldBlockRequest(request)) {
        if (error) {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
        }
        return nil;
    }
    return %orig(request, response, error);
}

+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))handler {
    if (DKShouldBlockRequest(request)) {
        if (handler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            handler(nil, nil, error);
        }
        return;
    }
    %orig(request, queue, handler);
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if (DKShouldBlockRequest(request)) {
        // 返回 nil，但通常 NSURLConnection 的 delegate 方式较少用
        return nil;
    }
    return %orig(request, delegate);
}

%end

// ========== Hook AFNetworking ==========
%hook AFHTTPSessionManager
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSURLSessionDataTask *task = %orig(request, nil);
        [task cancel];
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return task;
    }
    return %orig(request, completionHandler);
}
%end

%hook AFURLSessionManager
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSURLSessionDataTask *task = %orig(request, nil);
        [task cancel];
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return task;
    }
    return %orig(request, completionHandler);
}
%end

// ========== Hook WKWebView ==========
%hook WKWebView
- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        return nil;
    }
    return %orig(request);
}
%end

// ========== Hook NSURLProtocol ==========
%hook NSURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        return NO;
    }
    return %orig(request);
}
%end

// ========== Hook CFSocketStream（可选） ==========
%hook CFSocketStream
- (void)open {
    // 不执行任何操作，阻止打开
}
%end

// ========== Hook GCDAsyncSocket（如果存在） ==========
%hook GCDAsyncSocket
- (void)connectToHost:(NSString *)host onPort:(uint16_t)port error:(NSError **)errPtr {
    if (errPtr) {
        *errPtr = [NSError errorWithDomain:@"GCDAsyncSocketErrorDomain" code:1 userInfo:nil];
    }
}
%end

// ========== 无弹窗 ==========
%ctor {
    NSLog(@"[DisconnectAppNetwork] 无弹窗防闪退版加载成功");
}
