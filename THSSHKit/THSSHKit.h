//
//  THSSHKit.h
//  THSSHKitDemo
//
//  Created by Hao Tang on 13-12-18.
//  Copyright (c) 2013年 HaoTang. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^THSSHConnctSuccessBlock)();
typedef void (^THSSHConnectFailureBlock)(NSError *error);
typedef void (^THSSHExecuteSuccessBlock)(NSString *result);
typedef void (^THSSHExecuteFailureBlock)(NSError *error);

@interface THSSHClient : NSObject

- (void)connectToHost:(NSString *)host
                 port:(int)port
                 user:(NSString *)user
             password:(NSString *)password
              success:(THSSHConnctSuccessBlock)successBlock
              failure:(THSSHConnectFailureBlock)failureBlock;

- (NSString *)executeCommand:(NSString *)command error:(NSError **)error;

- (void)executeCommand:(NSString *)command
               success:(THSSHExecuteSuccessBlock)successBlock
               failure:(THSSHExecuteFailureBlock)failureBlock;

- (void)createRemoteTunnelWithHost:(NSString *)host
                              user:(NSString *)user
                          password:(NSString *)password
                  remoteListenPort:(int)remoteListenPort
                         forwardIP:(NSString *)forwadIP
                       forwardPort:(int)forwardPort;

- (void)disconnect;

@end
