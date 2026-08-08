// =============================================================
//  DisconnectAppNetwork — 基于 NSURLProtocol 的断网插件
//  原理：注册自定义 Protocol，直接拦截所有请求并返回错误
//  不返回 nil，无闪退风险，断网更彻底
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

// ========== 自定义 NSURLProtocol ==========
@interface DisconnectProtocol : NSURLProtocol
@end

@implementation DisconnectProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // 拦截所有请求（可添加白名单过滤）
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    // 直接返回网络不可用错误，不发起真实请求
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                         code:NSURLErrorNotConnectedToInternet
                                     userInfo:@{NSLocalizedDescriptionKey: @"Disconnected by DisconnectAppNetwork"}];
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)stopLoading {
    // 无需任何操作
}

@end

// ========== 自动注册 ==========
%ctor {
    // 注册自定义 Protocol
    [NSURLProtocol registerClass:[DisconnectProtocol class]];
    NSLog(@"[DisconnectAppNetwork] NSURLProtocol 注册成功，所有网络请求将被拦截");
}
