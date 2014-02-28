//
//  TBWebServer.h
//  tbtui
//
//  Created by iPhone on 13-6-14.
//  Copyright (c) 2013年 厦门同步网络. All rights reserved.
//

#import <Foundation/Foundation.h>

#if ZHENGBAN

#import <Foundation/Foundation.h>
#import "CHTTPServer.h"
#import "CWebDavHTTPHandler.h"
#import "CHTTPLoggingHandler.h"
#import "CHTTPDefaultHandler.h"
#import "CHTTPStaticResourcesHandler.h"
#import "CHTTPBasicAuthHandler.h"


@interface TBWebServer : NSObject
{
    CHTTPServer *HTTPServer;
}

@property (nonatomic, retain) CHTTPServer *HTTPServer;

+ (id)defaultServer;

//启动服务
- (void)startServer;

//关闭服务
- (void)stopServer;

+ (NSArray *)localAddrs;

@end

#endif