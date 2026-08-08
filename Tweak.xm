// =============================================================
//  DisconnectAppNetwork — 断网插件增强版
//  功能：拦截网络请求，模拟成功响应，避免 App 闪退
//  专为多看阅读等 App 优化，支持白名单域名放行
//  原项目名不变，只替换此文件
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h> 

// ---------- 配置区 ----------
// 白名单域名（这些域名的请求将正常放行，不拦截）
static NSArray *kWhitelistDomains = @[
    // @"example.com", // 如需放行某些域名，取消注释并添加
];
// 延迟启用时间（秒），避免干扰 App 启动
static const NSTimeInterval kEnableDelay = 1.5;

// ---------- 辅助函数 ----------
// 判断是否应该拦截此请求（白名单检查）
static BOOL DKShouldBlockRequest(NSURLRequest *request) {
    if (!request.URL.host) return YES;
    for (NSString *domain in kWhitelistDomains) {
        if ([request.URL.host containsString:domain]) {
            return NO; // 白名单放行
        }
    }
    return YES; // 默认拦截
}

// 模拟成功响应（返回空 JSON + 200 状态码）
static void DKSimulateSuccessResponse(NSURLRequest *request, void (^completion)(NSData *, NSURLResponse *, NSError *)) {
    if (!completion) return;
    NSData *mockData = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    NSHTTPURLResponse *mockResponse = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                                  statusCode:200
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:@{@"Content-Type": @"application/json"}];
    completion(mockData, mockResponse, nil);
}

// ---------- Hook 实现 ----------
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截请求: %@", request.URL.absoluteString);
        // 模拟成功响应（避免 App 因网络错误崩溃）
        DKSimulateSuccessResponse(request, completionHandler);
        return nil;
    }
    return %orig(request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截请求(无回调): %@", request.URL.absoluteString);
        return nil;
    }
    return %orig(request);
}

%end

%hook NSURLConnection

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截同步请求: %@", request.URL.absoluteString);
        if (response) {
            *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
        }
        if (error) {
            *error = nil;
        }
        return [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    }
    return %orig(request, response, error);
}

+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 connectionWithRequest: %@", request.URL.absoluteString);
        return nil;
    }
    return %orig(request, delegate);
}

%end

%hook AFHTTPSessionManager

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] 拦截 AFNetworking 请求: %@", request.URL.absoluteString);
        // 模拟成功响应
        NSData *mockData = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
        NSHTTPURLResponse *mockResponse = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{}];
        id jsonObject = [NSJSONSerialization JSONObjectWithData:mockData options:0 error:nil];
        completionHandler(mockResponse, jsonObject, nil);
        return nil;
    }
    return %orig(request, completionHandler);
}

%end

%hook WKWebView

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        NSLog(@"[DisconnectAppNetwork] WKWebView 拦截请求: %@", request.URL.absoluteString);
        return nil;
    }
    return %orig(request);
}

%end

// ---------- 延迟启用，避免干扰 App 启动 ----------
%ctor {
    NSLog(@"[DisconnectAppNetwork] 断网插件增强版加载成功，延迟 %.1f 秒启用", kEnableDelay);
    // 延迟执行，确保 App 启动完成后再启用拦截
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kEnableDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[DisconnectAppNetwork] 插件已完全激活");
        // 可选：弹窗提示（可注释掉）
        // dispatch_async(dispatch_get_main_queue(), ^{
        //     UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        //     if (window) {
        //         UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DisconnectAppNetwork"
        //                                                                        message:@"断网插件已激活"
        //                                                                 preferredStyle:UIAlertControllerStyleAlert];
        //         [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        //         [window.rootViewController presentViewController:alert animated:YES completion:nil];
        //     }
        // });
    });
}
