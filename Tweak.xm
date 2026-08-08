#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// 弹窗确认注入成功（可选）
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

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    // 模拟返回错误，表示网络不可用
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    completionHandler(nil, nil, error);
    return nil; // 返回 nil 来阻止请求
}

%end

// ========== Hook NSURLConnection ==========
%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    // 模拟返回错误，表示网络不可用
    if (error) {
        *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    }
    return nil;
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    // 模拟网络不可用
    NSLog(@"[DisconnectAppNetwork] Hooked NSURLConnection");
    return nil;
}

- (void)start {
    NSLog(@"[DisconnectAppNetwork] NSURLConnection start hooked");
}

%end

// ========== Hook AFHTTPSessionManager ==========
%hook AFHTTPSessionManager

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    NSLog(@"[DisconnectAppNetwork] Hooked AFNetworking request: %@", request.URL.absoluteString);
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    completionHandler(nil, nil, error);
    return nil;
}

%end

// ========== Hook AFURLSessionManager ==========
%hook AFURLSessionManager

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    NSLog(@"[DisconnectAppNetwork] Blocked AFNetworking request: %@", request.URL.absoluteString);
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    completionHandler(nil, nil, error);
    return nil;
}

%end

// ========== Hook CFSocketStream ==========
%hook CFSocketStream

- (void)open {
    NSLog(@"[DisconnectAppNetwork] Hooked CFSocketStream open");
}

- (void)close {
    NSLog(@"[DisconnectAppNetwork] Hooked CFSocketStream close");
}

%end

// ========== Hook NSURLProtocol ==========
%hook NSURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSLog(@"[DisconnectAppNetwork] Hooked NSURLProtocol");
    return NO; // 阻止任何网络请求
}

%end

// ========== Hook WKWebView ==========
%hook WKWebView

- (void)loadRequest:(NSURLRequest *)request {
    NSLog(@"[DisconnectAppNetwork] WKWebView network request intercepted: %@", request.URL.absoluteString);
    // 不调用原始方法，直接返回
}

%end

// ========== Hook GCDAsyncSocket ==========
%hook GCDAsyncSocket

- (void)connectToHost:(NSString *)host onPort:(uint16_t)port error:(NSError **)errPtr {
    NSLog(@"[DisconnectAppNetwork] GCDAsyncSocket connection blocked to host: %@", host);
    if (errPtr) {
        *errPtr = [NSError errorWithDomain:@"GCDAsyncSocketErrorDomain" code:1 userInfo:nil];
    }
}

%end

// ========== 注入确认 ==========
%ctor {
    NSLog(@"[DisconnectAppNetwork] 原版复刻版加载成功");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DKShowAlert(@"断网插件已注入！");
    });
}
