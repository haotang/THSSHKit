//
//  THSSHKitDemoViewController.m
//  THSSHKitDemo
//
//  Created by Hao Tang on 13-12-24.
//  Copyright (c) 2013年 HaoTang. All rights reserved.
//

#import "THSSHKitDemoViewController.h"
#import "THSSHKit.h"

@interface THSSHKitDemoViewController ()

@property (strong, nonatomic) IBOutlet UITextField *serverField;
@property (strong, nonatomic) IBOutlet UITextField *portField;
@property (strong, nonatomic) IBOutlet UITextField *userField;
@property (strong, nonatomic) IBOutlet UITextField *passwordField;
@property (strong, nonatomic) IBOutlet UITextField *executeField;
@property (strong, nonatomic) IBOutlet UITextView  *resultTextView;
@property (strong, nonatomic) IBOutlet UIButton *connectButton;
@property (strong, nonatomic) IBOutlet UIButton *disConnectButton;
@property (strong, nonatomic) IBOutlet UIButton *executeButton;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;
@property (strong, nonatomic) THSSHClient *sshClient;

@end

@implementation THSSHKitDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.sshClient = [[THSSHClient alloc] init];
}

- (IBAction)connectButtonClicked:(id)sender {
    [self.sshClient connectToHost:self.serverField.text
                             port:[self.portField.text intValue]
                             user:self.userField.text
                         password:self.passwordField.text
                          success:^{
                              self.statusLabel.text = @"Connect success";
                              [[UIApplication sharedApplication].keyWindow endEditing:YES];
                          } failure:^(NSError *error) {
                              self.statusLabel.text = [error localizedDescription];
                              [[UIApplication sharedApplication].keyWindow endEditing:YES];
                          }];
}

- (IBAction)disConnectButtonClicked:(id)sender {
    [self.sshClient disconnect];
    self.statusLabel.text = @"Disconnect";
    [[UIApplication sharedApplication].keyWindow endEditing:YES];
}

- (IBAction)executeButtonClicked:(id)sender {
    [self.sshClient executeCommand:self.executeField.text
                           success:^(NSString *result) {
                               self.resultTextView.text = result;
                               self.statusLabel.text = @"Execute success";
                               [[UIApplication sharedApplication].keyWindow endEditing:YES];
                           } failure:^(NSError *error) {
                               self.statusLabel.text = [error localizedDescription];
                               [[UIApplication sharedApplication].keyWindow endEditing:YES];
                           }];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [[UIApplication sharedApplication].keyWindow endEditing:YES];
}

@end
