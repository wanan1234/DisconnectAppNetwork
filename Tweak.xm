// =============================================================
//  DisconnectAppNetwork — 全局断网插件（稳定版）
//  基于原版优化，修复返回 nil 导致的闪退问题
//  支持 NSURLSession、NSURLConnection、AFNetworking、WKWebView 等
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// 拦截所有请求（无白名单）
static BOOL DKShouldBlockRequest(NSURLRequest *request) {
    return YES;
}

// 弹窗确认（可移除）
static void DKShowAlert(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        if (!window) return;
        UIViewController *root = window.rootViewController;
        if (!root) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DisconnectAppNetwork"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

// ========== Hook NSURLSession ==========
%hook NSURLSession

// 有回调的 dataTask
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        // 1. 先调用原始方法创建任务，但不设置 completionHandler（传入 nil）
        NSURLSessionDataTask *task = %orig(request, nil);
        // 2. 立即取消任务，阻止实际网络请求
        [task cancel];
        // 3. 手动调用我们自己的错误回调
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        // 4. 返回已取消的任务（非 nil），避免 App 因 nil 崩溃
        return task;
    }
    return %orig(request, completionHandler);
}

// 无回调的 dataTask
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        // 同样创建并取消任务，但不触发任何回调
        NSURLSessionDataTask *task = %orig(request);
        [task cancel];
        return task;
    }
    return %orig(request);
}

// uploadTask
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

// downloadTask
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

// 同步请求
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    if (DKShouldBlockRequest(request)) {
        if (error) {
            *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
        }
        return nil; // 同步请求返回 nil 并设置错误，调用方通常会检查 error
    }
    return %orig(request, response, error);
}

// 异步请求（原版缺少，补充）
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

// connectionWithRequest:delegate:（返回非 nil 的连接，但立即取消）
+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if (DKShouldBlockRequest(request)) {
        // 创建连接，然后取消
        NSURLConnection *connection = %orig(request, delegate);
        [connection cancel];
        return connection; // 返回已取消的连接
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

// ========== Hook AFURLSessionManager（旧版 AFNetworking） ==========
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
        // 返回 nil 表示不加载，WKWebView 会处理 nil 为不执行
        return nil;
    }
    return %orig(request);
}
%end

// ========== Hook NSURLProtocol（底层拦截） ==========
%hook NSURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        return NO; // 不处理，系统会忽略该请求
    }
    return %orig(request);
}
%end

// ========== Hook GCDAsyncSocket（Socket 连接） ==========
%hook GCDAsyncSocket
- (void)connectToHost:(NSString *)host onPort:(uint16_t)port error:(NSError **)errPtr {
    if (DKShouldBlockRequest(nil)) { // 无 URL，直接拦截
        if (errPtr) {
            *errPtr = [NSError errorWithDomain:@"GCDAsyncSocketErrorDomain" code:1 userInfo:nil];
        }
        return;
    }
    %orig(host, onPort, error);
}
%end

// ========== 注入确认 ==========
%ctor {
    NSLog(@"[DisconnectAppNetwork] 稳定版插件加载成功");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DKShowAlert(@"断网插件已注入成功！\n所有网络请求已被拦截。");
    });
}
