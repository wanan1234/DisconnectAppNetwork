// =============================================================
//  DisconnectAppNetwork — 全局断网插件（稳定精简版）
//  仅保留核心 Hook：NSURLSession、NSURLConnection、AFNetworking、WKWebView
//  移除 GCDAsyncSocket 避免编译错误
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// 拦截所有请求（无白名单）
static BOOL DKShouldBlockRequest(NSURLRequest *request) {
    return YES;
}

// 弹窗确认
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

// 无回调的 dataTask
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
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
        return nil;
    }
    return %orig(request, response, error);
}

// 异步请求
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

// connectionWithRequest:delegate:
+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if (DKShouldBlockRequest(request)) {
        NSURLConnection *connection = %orig(request, delegate);
        [connection cancel];
        return connection;
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

// ========== Hook WKWebView ==========
%hook WKWebView
- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        return nil;
    }
    return %orig(request);
}
%end

// ========== Hook NSURLProtocol（底层拦截） ==========
%hook NSURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        return NO;
    }
    return %orig(request);
}
%end

// ========== 注入确认 ==========
%ctor {
    NSLog(@"[DisconnectAppNetwork] 稳定精简版插件加载成功");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DKShowAlert(@"断网插件已注入成功！\n所有网络请求已被拦截。");
    });
}
