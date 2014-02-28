//
//  THSSHKit.m
//  THSSHKitDemo
//
//  Created by Hao Tang on 13-12-18.
//  Copyright (c) 2013年 HaoTang. All rights reserved.
//

#import "THSSHKit.h"
#include "libssh2_config.h"
#include "libssh2.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

#ifdef HAVE_SYS_SELECT_H
#include <sys/select.h>
#endif

#ifndef INADDR_NONE
#define INADDR_NONE (in_addr_t)-1
#endif

const char *public_key = "/Users/thgit/.ssh/id_rsa.pub";
const char *private_key = "/Users/thgit/.ssh/id_rsa";

enum {
    AUTH_NONE = 0,
    AUTH_PASSWORD,
    AUTH_PUBLICKEY
};

static int waitsocket(int socket_fd, LIBSSH2_SESSION *session)
{
    struct timeval timeout;
    int rc;
    fd_set fd;
    fd_set *writefd = NULL;
    fd_set *readfd = NULL;
    int dir;
    
    timeout.tv_sec = 10;
    timeout.tv_usec = 0;
    
    FD_ZERO(&fd);
    
    FD_SET(socket_fd, &fd);
    
    /* now make sure we wait in the correct direction */
    dir = libssh2_session_block_directions(session);
    
    if(dir & LIBSSH2_SESSION_BLOCK_INBOUND)
        readfd = &fd;
    
    if(dir & LIBSSH2_SESSION_BLOCK_OUTBOUND)
        writefd = &fd;
    
    rc = select(socket_fd + 1, readfd, writefd, NULL, &timeout);
    
    return rc;
}

@interface THSSHClient ()

@property (copy, nonatomic) THSSHConnctSuccessBlock connectSuccessBlock;
@property (copy, nonatomic) THSSHConnectFailureBlock connectFailureBlock;
@property (nonatomic) int sock;
@property (nonatomic) NSInteger rc;
@property (nonatomic) LIBSSH2_SESSION *session;
@property (nonatomic) LIBSSH2_CHANNEL *channel;

@end

@implementation THSSHClient

- (void)connectToHost:(NSString *)host
                 port:(int)port
                 user:(NSString *)user
             password:(NSString *)password
              success:(THSSHConnctSuccessBlock)successBlock
              failure:(THSSHConnectFailureBlock)failureBlock {
    if (host.length == 0) {
        NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:300 userInfo:@{NSLocalizedDescriptionKey:@"No host"}];
        failureBlock(error);
        return;
    }
    
    if (!host) {
        host = @"";
    }
    
    if (!user) {
        user = @"";
    }
    
    if (!password) {
        password = @"";
    }
	const char* hostChar = [host cStringUsingEncoding:NSUTF8StringEncoding];
	const char* userChar = [user cStringUsingEncoding:NSUTF8StringEncoding];
	const char* passwordChar = [password cStringUsingEncoding:NSUTF8StringEncoding];
    struct sockaddr_in sock_serv_addr;
    unsigned long hostaddr = inet_addr(hostChar);
    
    _sock = socket(AF_INET, SOCK_STREAM, 0);
    sock_serv_addr.sin_family = AF_INET;
    sock_serv_addr.sin_port = htons(port);
    sock_serv_addr.sin_addr.s_addr = (in_addr_t)hostaddr;
    if (connect(_sock, (struct sockaddr *) (&sock_serv_addr), sizeof(sock_serv_addr)) != 0) {
        NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:400 userInfo:@{NSLocalizedDescriptionKey:@"Failed to connect"}];
        failureBlock(error);
        return;
    }
	
    /* Create a session instance */
    _session = libssh2_session_init();
    if (!_session) {
        NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:401 userInfo:@{NSLocalizedDescriptionKey : @"Create session failed"}];
        failureBlock(error);
        return;
    }
	
    /* tell libssh2 we want it all done non-blocking */
    libssh2_session_set_blocking(_session, 0);
	
    /* ... start it up. This will trade welcome banners, exchange keys,
     * and setup crypto, compression, and MAC layers
     */
    while ((_rc = libssh2_session_startup(_session, _sock)) ==
           LIBSSH2_ERROR_EAGAIN);
    if (_rc) {
        NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:402 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failure establishing SSH session: %d", _rc]}];
        failureBlock(error);
        return;
    }
    
    if ( strlen(passwordChar) != 0 ) {
		/* We could authenticate via password */
        while ((_rc = libssh2_userauth_password(_session, userChar, passwordChar)) == LIBSSH2_ERROR_EAGAIN);
		if (_rc) {
            NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:403 userInfo:@{NSLocalizedDescriptionKey : @"Authentication by password failed."}];
            failureBlock(error);
            return;
		}
	}
    successBlock();
}

- (void)executeCommand:(NSString *)command success:(void (^)(NSString *))successBlock failure:(void (^)(NSError *))failureBlock {
    if (!_session) {
        NSError *error = [NSError errorWithDomain:@"com.nestree.thsshkit" code:501 userInfo:@{NSLocalizedDescriptionKey: @"SSH client disconnect"}];
        failureBlock(error);
        return;
    }
    const char* commandChar = [command cStringUsingEncoding:NSUTF8StringEncoding];
    
	NSString *result = @"";

    /* Exec non-blocking on the remove host */
    while((_channel = libssh2_channel_open_session(_session)) == NULL &&
          libssh2_session_last_error(_session,NULL,NULL,0) == LIBSSH2_ERROR_EAGAIN)
    {
        waitsocket(_sock, _session);
    }
    if(_channel == NULL)
    {
        NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:501 userInfo:@{NSLocalizedDescriptionKey : @"No channel found."}];
        failureBlock(error);
        return;
    }
    
    while((_rc = libssh2_channel_exec(_channel, commandChar)) == LIBSSH2_ERROR_EAGAIN)
    {
        waitsocket(_sock, _session);
    }
    if(_rc != 0)
    {
        NSError *error = [NSError errorWithDomain:@"de.felixschulze.sshwrapper" code:502 userInfo:@{NSLocalizedDescriptionKey : @"Error while exec command."}];
        failureBlock(error);
        return;
    }
    for( ;; )
    {
        /* loop until we block */
        NSInteger rc1;
        do
        {
            char buffer[0x2000];
            rc1 = libssh2_channel_read(_channel, buffer, sizeof(buffer));
            if( rc1 > 0 )
            {
                result = [NSString stringWithCString:(const char *)buffer encoding:NSASCIIStringEncoding];
            }
        }
        while( rc1 > 0 );
		
        /* this is due to blocking that would occur otherwise so we loop on
		 this condition */
        if(rc1 == LIBSSH2_ERROR_EAGAIN)
        {
            waitsocket(_sock, _session);
        }
        else
            break;
    }
    while((_rc = libssh2_channel_close(_channel)) == LIBSSH2_ERROR_EAGAIN)
        waitsocket(_sock, _session);
	
    libssh2_channel_free(_channel);
    _channel = NULL;
	
    successBlock(result);
}

- (void)createRemoteTunnelWithHost:(NSString *)host user:(NSString *)user password:(NSString *)password remoteListenPort:(int)remoteListenPort forwardIP:(NSString *)forwadIP forwardPort:(int)forwardPort {
    
    const char *userChar = [user cStringUsingEncoding:NSUTF8StringEncoding];
    const char *passwordChar = [password cStringUsingEncoding:NSUTF8StringEncoding];
    
    const char *hostChar = [host cStringUsingEncoding:NSUTF8StringEncoding];
    
    const char *remoteListenhost = "localhost"; /* resolved by the server */
    unsigned int remoteWantport = remoteListenPort;
    unsigned int remoteListenport;
    
    const char *forwardIPChar = [forwadIP cStringUsingEncoding:NSUTF8StringEncoding];
    
    NSInteger rc, sock = -1, forwardsock = -1, i;
    struct sockaddr_in sin;
    socklen_t sinlen = sizeof(sin);

    LIBSSH2_SESSION *session;
    LIBSSH2_LISTENER *listener = NULL;
    LIBSSH2_CHANNEL *channel = NULL;
    const char *shost;
    unsigned int sport;
    fd_set fds;
    struct timeval tv;
    ssize_t len, wr;
    char buf[16384];
    
    int sockopt;
    
    rc = libssh2_init (0);
    if (rc != 0) {
        fprintf (stderr, "libssh2 initialization failed (%d)\n", rc);
        return;
    }
    
    /* Connect to SSH server */
    sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    sin.sin_family = AF_INET;
    if (INADDR_NONE == (sin.sin_addr.s_addr = inet_addr(hostChar))) {
        perror("inet_addr");
        return;
    }
    sin.sin_port = htons(22);
    if (connect(sock, (struct sockaddr*)(&sin),
                sizeof(struct sockaddr_in)) != 0) {
        fprintf(stderr, "failed to connect!\n");
        return;
    }
    
    /* Create a session instance */
    session = libssh2_session_init();
    if(!session) {
        fprintf(stderr, "Could not initialize SSH session!\n");
        return;
    }
    
    /* ... start it up. This will trade welcome banners, exchange keys,
     * and setup crypto, compression, and MAC layers
     */
    rc = libssh2_session_handshake(session, sock);
    if(rc) {
        fprintf(stderr, "Error when starting up SSH session: %d\n", rc);
        return;
    }
    
    if (libssh2_userauth_password(session, userChar, passwordChar)) {
        fprintf(stderr, "Authentication by password failed.\n");
        goto shutdown;
    }
    
    printf("Asking server to listen on remote %s:%d\n", remoteListenhost,
           remoteWantport);
    
    listener = libssh2_channel_forward_listen_ex(session, remoteListenhost,
                                                 remoteWantport, &remoteListenport, 1);
    if (!listener) {
        fprintf(stderr, "Could not start the tcpip-forward listener!\n"
                "(Note that this can be a problem at the server!"
                " Please review the server logs.)\n");
        goto shutdown;
    }
    
    printf("Server is listening on %s:%d\n", remoteListenhost,
           remoteListenport);
    
    printf("Waiting for remote connection\n");
    channel = libssh2_channel_forward_accept(listener);
    if (!channel) {
        fprintf(stderr, "Could not accept connection!\n"
                "(Note that this can be a problem at the server!"
                " Please review the server logs.)\n");
        goto shutdown;
    }
    
    printf("Accepted remote connection. Connecting to local server %s:%d\n",
           forwardIPChar, forwardPort);
    forwardsock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    sin.sin_family = AF_INET;
    sin.sin_port = htons(forwardPort);
    if (INADDR_NONE == (sin.sin_addr.s_addr = inet_addr(forwardIPChar))) {
        perror("inet_addr");
        goto shutdown;
    }
    if (-1 == connect(forwardsock, (struct sockaddr *)&sin, sinlen)) {
        perror("connect");
        goto shutdown;
    }
    
    printf("Forwarding connection from remote %s:%d to local %s:%d\n",
           remoteListenhost, remoteListenport, forwardIPChar, forwardPort);
    
    /* Must use non-blocking IO hereafter due to the current libssh2 API */
    libssh2_session_set_blocking(session, 0);
    
    while (1) {
        FD_ZERO(&fds);
        FD_SET(forwardsock, &fds);
        tv.tv_sec = 0;
        tv.tv_usec = 100000;
        rc = select(forwardsock + 1, &fds, NULL, NULL, &tv);
        if (-1 == rc) {
            perror("select");
            goto shutdown;
        }
        if (rc && FD_ISSET(forwardsock, &fds)) {
            len = recv(forwardsock, buf, sizeof(buf), 0);
            if (len < 0) {
                perror("read");
                goto shutdown;
            } else if (0 == len) {
                printf("The local server at %s:%d disconnected!\n",
                       forwardIPChar, forwardPort);
                goto shutdown;
            }
            wr = 0;
            do {
                i = libssh2_channel_write(channel, buf, len);
                if (i < 0) {
                    fprintf(stderr, "libssh2_channel_write: %d\n", i);
                    goto shutdown;
                }
                wr += i;
            } while(i > 0 && wr < len);
        }
        while (1) {
            len = libssh2_channel_read(channel, buf, sizeof(buf));
            if (LIBSSH2_ERROR_EAGAIN == len)
                break;
            else if (len < 0) {
                fprintf(stderr, "libssh2_channel_read: %d", (int)len);
                goto shutdown;
            }
            wr = 0;
            while (wr < len) {
                i = send(forwardsock, buf + wr, len - wr, 0);
                if (i <= 0) {
                    perror("write");
                    goto shutdown;
                }
                wr += i;
            }
            if (libssh2_channel_eof(channel)) {
                printf("The remote client at %s:%d disconnected!\n",
                       remoteListenhost, remoteListenport);
                goto shutdown;
            }
        }
    }
    
shutdown:
    
    close(forwardsock);
    
    if (channel)
        libssh2_channel_free(channel);
    if (listener)
        libssh2_channel_forward_cancel(listener);
    libssh2_session_disconnect(session, "Client disconnecting normally");
    libssh2_session_free(session);
    
    close(sock);
    
    libssh2_exit();
}

- (void)disconnect {
    if (_session) {
        libssh2_session_disconnect(_session, "Normal Shutdown, Thank you for playing");
        libssh2_session_free(_session);
        _session = nil;
    }
    close(_sock);
}

@end
