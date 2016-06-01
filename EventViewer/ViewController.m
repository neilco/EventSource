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
    
    EventSource *sourceMainThread = [EventSource eventSourceWithURL:[NSURL URLWithString:@"http://127.0.0.1:8000/"]];
    [sourceMainThread addEventListener:@"hello_event" handler:^(Event *e) {
        NSLog(@"%@ -> %@: %@", [NSThread isMainThread] ? @"Main Thread" : @"Background Thread", e.event, e.data);
    }];
    
    EventSource *sourceBackgroundThread = [EventSource eventSourceWithURL:[NSURL URLWithString:@"http://127.0.0.1:8000/"] timeoutInterval:30 queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)];
    [sourceBackgroundThread addEventListener:@"hello_event" handler:^(Event *e) {
        NSLog(@"%@ -> %@: %@", [NSThread isMainThread] ? @"Main Thread" : @"Background Thread", e.event, e.data);
    }];
}

@end
