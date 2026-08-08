// =============================================================
//  DisconnectAppNetwork — 全局断网插件（基于原版，移除 GCDAsyncSocket）
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static BOOL DKShouldBlockRequest(NSURLRequest *request) {
    return YES;
}

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
    if (DKShouldBlockRequest(request)) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (DKShouldBlockRequest(request)) {
        return nil;
    }
    return %orig(request);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, fileURL, completionHandler);
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
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
        return nil;
    }
    return %orig(request, delegate);
}

%end

// ========== Hook AFNetworking ==========
%hook AFHTTPSessionManager
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig(request, completionHandler);
}
%end

%hook AFURLSessionManager
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    if (DKShouldBlockRequest(request)) {
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

// ========== 注入确认 ==========
%ctor {
    NSLog(@"[DisconnectAppNetwork] 原版逻辑版加载成功");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DKShowAlert(@"断网插件已注入！");
    });
}
