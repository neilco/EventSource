//
//  ViewController.m
//  EventViewer
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import "ViewController.h"
#import "EventSource.h"

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    EventSource *source = [EventSource eventSourceWithURL:[NSURL URLWithString:@"http://127.0.0.1:8000/"]];
    [source onReadyStateChanged:^(Event *event) {
        NSLog(@"READYSTATE: %@", event);
    }];

    [source onMessage:^(Event *event) {
        NSLog(@"%@", event);
    }];
}

@end
