//
//  TBWebServer.m
//  tbtui
//
//  Created by iPhone on 13-6-14.
//  Copyright (c) 2013年 厦门同步网络. All rights reserved.
//

#import "TBWebServer.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#if ZHENGBAN

static TBWebServer *defaultServer = nil;

@implementation TBWebServer
@synthesize HTTPServer;

+ (id)defaultServer
{
    if (!defaultServer) {
        defaultServer = [[TBWebServer alloc]init];
    }
    
    return defaultServer;
}


//启动服务
- (void)startServer
{
    if (self.HTTPServer == NULL)
	{
        CHTTPServer *theHTTPServer = [[[CHTTPServer alloc] init] autorelease];
        [theHTTPServer createDefaultSocketListener];
        
        //	CHTTPBasicAuthHandler *theAuthHandler = [[[CHTTPBasicAuthHandler alloc] init] autorelease];
        //	theAuthHandler.delegate = self;
        //	[theHTTPServer.defaultRequestHandlers addObject:theAuthHandler];
        
        NSString *theRoot = [@"~/Documents" stringByExpandingTildeInPath];
        
        theRoot = [DocumentsManager getDocumentsPath];
        
        CWebDavHTTPHandler *theRequestHandler = [[[CWebDavHTTPHandler alloc] initWithRootPath:theRoot] autorelease];
        [theHTTPServer.defaultRequestHandlers addObject:theRequestHandler];
        
        CHTTPDefaultHandler *theDefaultHandler = [[[CHTTPDefaultHandler alloc] init] autorelease];
        [theHTTPServer.defaultRequestHandlers addObject:theDefaultHandler];
        
        CHTTPStaticResourcesHandler *theStaticResourceHandler = [[[CHTTPStaticResourcesHandler alloc] init] autorelease];
        [theHTTPServer.defaultRequestHandlers addObject:theStaticResourceHandler];
        
        CHTTPLoggingHandler *theLoggingHandler = [[[CHTTPLoggingHandler alloc] init] autorelease];
        [theHTTPServer.defaultRequestHandlers addObject:theLoggingHandler];
        
        // by default your server will be published via Bonjour,
        // to change this behaviour, just uncomment this line:
        theHTTPServer.socketListener.broadcasting = NO;
		
        // by default your server as broadcasted as simple HTTP service,
        // if you want your server to be discovert by WebDAV clients (like Transmit or Cyberduck),
        // uncomment this line:
        //theHTTPServer.socketListener.type = @"_webdav._tcp.";
		
        BOOL success = [theHTTPServer.socketListener start:NULL];
        
        if (!success) {
            theHTTPServer.socketListener.port = 0;
            success = [theHTTPServer.socketListener start:NULL];
        }
        
        //        theHTTPServer.socketListener.delegate = self;
        
        //        NSURL *theURL = [NSURL URLWithString:[NSString stringWithFormat:@"webdav://%@:%d", [[[self class] localAddrs] lastObject], theHTTPServer.socketListener.port]];
        //
        //        NSLog(@"%@",theURL);
        
        self.HTTPServer = theHTTPServer;
	}
}

//关闭服务

- (void)stopServer
{
    if (self.HTTPServer != NULL)
	{
        NSAutoreleasePool *thePool = [[NSAutoreleasePool alloc] init];
        
        self.HTTPServer = NULL;
        
        [thePool drain];
	}
}

+ (NSArray *)localAddrs
{
    NSMutableArray *addrs = [NSMutableArray array];
    
    struct ifaddrs *ll;
    //    struct ifaddrs *llOrigin;
    getifaddrs(&ll);
    
    //    llOrigin = ll;
    
    while (ll)
    {
        struct sockaddr *sa = ll->ifa_addr;
        if (sa->sa_family == AF_INET)
        {
            struct sockaddr_in *sin = (struct sockaddr_in*)sa;
            char *dottedQuadBuf = inet_ntoa(sin->sin_addr);
            
            if ( (ll->ifa_flags & (IFF_UP | IFF_RUNNING)) && !(ll->ifa_flags & IFF_LOOPBACK) )
            {
                [addrs addObject:[[[NSString alloc] initWithBytes:dottedQuadBuf length:strlen(dottedQuadBuf) encoding:NSUTF8StringEncoding] autorelease]];
            }
        }
        
        ll = ll->ifa_next;
    }
    
    freeifaddrs(ll);
    
    return [[addrs copy] autorelease];
}

@end

#endif