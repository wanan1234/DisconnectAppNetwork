// =============================================================
//  DisconnectAppNetwork — 通用断网插件（TrollFools 适用）
//  可注入到任意 App，彻底阻断所有网络请求
//  无需修改 plist，TrollFools 会直接加载
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// 是否拦截所有请求（可根据需要添加白名单）
static BOOL DKShouldBlockRequest(NSURLRequest *request) {
    // 如果你需要对某些域名放行，可在此添加逻辑
    // 例如：if ([request.URL.host containsString:@"apple.com"]) return NO;
    return YES;
}

// 弹窗确认注入成功
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

// ========== Hook NSURLSession（最常用） ==========
%hook NSURLSession
// dataTask 有回调
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 dataTask: %@", request.URL);
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, completionHandler);
}
// dataTask 无回调
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 dataTask(无回调): %@", request.URL);
        return nil;
    }
    return %orig(request);
}
// uploadTask
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 uploadTask: %@", request.URL);
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, fileURL, completionHandler);
}
// downloadTask
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 downloadTask: %@", request.URL);
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, completionHandler);
}
%end

// ========== Hook NSURLConnection ==========
%hook NSURLConnection
// 同步请求
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截同步请求: %@", request.URL);
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
        NSLog(@"[DisconnectAppNetwork] 拦截异步请求: %@", request.URL);
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
        NSLog(@"[DisconnectAppNetwork] 拦截 connectionWithRequest: %@", request.URL);
        return nil;
    }
    return %orig(request, delegate);
}
%end

// ========== Hook AFNetworking ==========
%hook AFHTTPSessionManager
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 AFNetworking: %@", request.URL);
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, completionHandler);
}
%end

// ========== Hook WKWebView ==========
%hook WKWebView
- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] WKWebView 拦截: %@", request.URL);
        return nil;
    }
    return %orig(request);
}
%end

// ========== Hook NSURLProtocol（底层拦截） ==========
%hook NSURLProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        // 返回 NO 让系统不处理该请求，相当于直接丢弃
        return NO;
    }
    return %orig(request);
}
%end

// ========== 注入确认 ==========
%ctor {
    NSLog(@"[DisconnectAppNetwork] 插件加载成功，当前进程: %@", [[NSBundle mainBundle] bundleIdentifier]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DKShowAlert(@"断网插件已注入成功！\n所有网络请求将被拦截。");
    });
}
