// =============================================================
//  DisconnectAppNetwork — 增强版断网插件
//  只拦截 HTTP/HTTPS 请求，放行本地文件请求（如 file://）
// =============================================================
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <sys/socket.h>
#import <dlfcn.h>
#import <errno.h>

// ========== 自定义 NSURLProtocol ==========
@interface DisconnectProtocol : NSURLProtocol
@end
@implementation DisconnectProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // 只拦截 http 和 https 请求，放行 file、data 等本地协议
    NSString *scheme = request.URL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        return YES;
    }
    return NO; // 放行其他请求
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)stopLoading {
    // 无需操作
}

@end

// ========== Hook Socket（备用，暂未启用） ==========
static int (*orig_connect)(int, const struct sockaddr *, socklen_t);

int hooked_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    errno = ECONNREFUSED;
    return -1;
}

static void hook_socket(void) {
    NSLog(@"[DisconnectAppNetwork] Socket Hook 已安装");
}

%ctor {
    // 注册 NSURLProtocol
    [NSURLProtocol registerClass:[DisconnectProtocol class]];
    NSLog(@"[DisconnectAppNetwork] NSURLProtocol 注册成功（仅拦截 HTTP/HTTPS）");
    
    // Hook Socket（如需启用，需引入 fishhook）
    orig_connect = (int(*)(int, const struct sockaddr*, socklen_t))dlsym(RTLD_DEFAULT, "connect");
    if (orig_connect) {
        // 实际替换需要 fishhook 或手动重绑定
        // hook_socket();
        NSLog(@"[DisconnectAppNetwork] Socket 连接已拦截（未实际启用）");
    }
}
