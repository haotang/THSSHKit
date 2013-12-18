//
//  THSSHKit.h
//  THSSHKitDemo
//
//  Created by Hao Tang on 13-12-18.
//  Copyright (c) 2013年 HaoTang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface THSSHKit : NSObject

+ (BOOL)start;
+ (BOOL)createRemoteTunnelWithServerIP:(NSString *)serverIP
                              username:(NSString *)userName
                              password:(NSString *)password
                      remoteListenPort:(int)remoteListenPort
                             forwardIP:(NSString *)forwadIP
                           forwardPort:(int)forwardPort;

@end
