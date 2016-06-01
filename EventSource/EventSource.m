//
//  EventSource.m
//  EventSource
//
//  Created by Neil on 25/07/2013.
//  Copyright (c) 2013 Neil Cowburn. All rights reserved.
//

#import "EventSource.h"
#import <CoreGraphics/CGBase.h>

static CGFloat const ES_RETRY_INTERVAL = 1.0;
static CGFloat const ES_DEFAULT_TIMEOUT = 300.0;

static NSString *const ESKeyValueDelimiter = @":";
static NSString *const ESEventSeparatorLFLF = @"\n\n";
static NSString *const ESEventSeparatorCRCR = @"\r\r";
static NSString *const ESEventSeparatorCRLFCRLF = @"\r\n\r\n";
static NSString *const ESEventKeyValuePairSeparator = @"\n";

static NSString *const ESEventDataKey = @"data";
static NSString *const ESEventIDKey = @"id";
static NSString *const ESEventEventKey = @"event";
static NSString *const ESEventRetryKey = @"retry";

@interface EventSource () <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
    BOOL wasClosed;
}

@property (nonatomic, strong) NSURL *eventURL;
@property (nonatomic, strong) NSURLConnection *eventSource;
@property (nonatomic, strong) NSMutableDictionary *listeners;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@property (nonatomic, strong) id lastEventID;
@property (nonatomic, strong) NSMutableData *buffer;

- (void)open;

@end

@implementation EventSource

+ (id)eventSourceWithURL:(NSURL *)URL
{
    return [[EventSource alloc] initWithURL:URL];
}

+ (id)eventSourceWithURL:(NSURL *)URL timeoutInterval:(NSTimeInterval)timeoutInterval
{
    return [[EventSource alloc] initWithURL:URL timeoutInterval:timeoutInterval];
}

- (id)initWithURL:(NSURL *)URL
{
    return [self initWithURL:URL timeoutInterval:ES_DEFAULT_TIMEOUT];
}

- (id)initWithURL:(NSURL *)URL timeoutInterval:(NSTimeInterval)timeoutInterval
{
    self = [super init];
    if (self) {
        _listeners = [NSMutableDictionary dictionary];
        _eventURL = URL;
        _timeoutInterval = timeoutInterval;
        _retryInterval = ES_RETRY_INTERVAL;
        _buffer = [NSMutableData data];
        _shouldReconnect = YES;
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_retryInterval * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self open];
        });
    }
    return self;
}

- (void)addEventListener:(NSString *)eventName handler:(EventSourceEventHandler)handler
{
    if (self.listeners[eventName] == nil) {
        [self.listeners setObject:[NSMutableArray array] forKey:eventName];
    }
    
    [self.listeners[eventName] addObject:handler];
}

- (void)onMessage:(EventSourceEventHandler)handler
{
    [self addEventListener:MessageEvent handler:handler];
}

- (void)onError:(EventSourceEventHandler)handler
{
    [self addEventListener:ErrorEvent handler:handler];
}

- (void)onOpen:(EventSourceEventHandler)handler
{
    [self addEventListener:OpenEvent handler:handler];
}

- (void)onClose:(EventSourceEventHandler)handler
{
    [self addEventListener:CloseEvent handler:handler];
}

- (void)open
{
    wasClosed = NO;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.eventURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:self.timeoutInterval];
    if (self.lastEventID) {
        [request setValue:self.lastEventID forHTTPHeaderField:@"Last-Event-ID"];
    }
    self.eventSource = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}

- (void)close
{
    wasClosed = YES;
    [self.eventSource cancel];
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode == 200) {
        // Opened
        Event *e = [Event new];
        e.readyState = kEventStateOpen;
        
        NSArray *openHandlers = self.listeners[OpenEvent];
        for (EventSourceEventHandler handler in openHandlers) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(e);
            });
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    Event *e = [Event new];
    e.readyState = kEventStateClosed;
    e.error = error;
    
    NSArray *errorHandlers = self.listeners[ErrorEvent];
    for (EventSourceEventHandler handler in errorHandlers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(e);
        });
    }
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.retryInterval * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self open];
    });
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.buffer appendData:data];
    NSString *bufferString = [[NSString alloc] initWithData:self.buffer encoding:NSUTF8StringEncoding];
    
    NSRange range;
    if ((range = [bufferString rangeOfString:ESEventSeparatorLFLF]).location != NSNotFound ||
        (range = [bufferString rangeOfString:ESEventSeparatorCRCR]).location != NSNotFound ||
        (range = [bufferString rangeOfString:ESEventSeparatorCRLFCRLF]).location != NSNotFound) {
        NSString *eventString = [bufferString substringToIndex:range.location];
        eventString = [eventString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        Event *e = [Event new];
        e.readyState = kEventStateOpen;

        NSArray *components = [eventString componentsSeparatedByString:ESEventKeyValuePairSeparator];
        for (NSString *component in components) {
            if (component.length == 0) {
                continue;
            }
            
            NSInteger index = [component rangeOfString:ESKeyValueDelimiter].location;
            if (index == NSNotFound || index == (component.length - 2)) {
                continue;
            }
            
            NSString *key = [[component substringToIndex:index] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *value = [[component substringFromIndex:index + ESKeyValueDelimiter.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([key isEqualToString:ESEventIDKey]) {
                e.id = value;
                self.lastEventID = e.id;
            } else if ([key isEqualToString:ESEventEventKey]) {
                e.event = value;
            } else if ([key isEqualToString:ESEventDataKey]) {
                e.data = value;
            } else if ([key isEqualToString:ESEventRetryKey]) {
                self.retryInterval = [value doubleValue];
            }
        }
        
        NSArray *messageHandlers = self.listeners[MessageEvent];
        for (EventSourceEventHandler handler in messageHandlers) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(e);
            });
        }
        
        if (e.event != nil) {
            NSArray *namedEventhandlers = self.listeners[e.event];
            for (EventSourceEventHandler handler in namedEventhandlers) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(e);
                });
            }
        }
        
        NSInteger eventStringLength = [[bufferString substringToIndex:range.location + range.length] dataUsingEncoding:NSUTF8StringEncoding].length;
        [self.buffer replaceBytesInRange:NSMakeRange(0, eventStringLength) withBytes:NULL length:0];
        [self connection:connection didReceiveData:[NSData data]];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (self.buffer.length > 0) {
        // Process last message by adding message separartor to end
        [self connection:connection didReceiveData:[ESEventSeparatorCRLFCRLF dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    Event *e = [Event new];
    e.readyState = kEventStateClosed;
    
    NSArray *errorHandlers = self.listeners[CloseEvent];
    for (EventSourceEventHandler handler in errorHandlers) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(e);
        });
    }
    
    if (!wasClosed && self.shouldReconnect) {
        [self open];
    } else {
        self.eventSource = nil;
    }
}

@end

// ---------------------------------------------------------------------------------------------------------------------

@implementation Event

- (NSString *)description
{
    NSString *state = nil;
    switch (self.readyState) {
        case kEventStateConnecting:
            state = @"CONNECTING";
            break;
        case kEventStateOpen:
            state = @"OPEN";
            break;
        case kEventStateClosed:
            state = @"CLOSED";
            break;
    }
    
    return [NSString stringWithFormat:@"<%@: readyState: %@, id: %@; event: %@; data: %@>",
            [self class],
            state,
            self.id,
            self.event,
            self.data];
}

@end

NSString *const MessageEvent = @"message";
NSString *const ErrorEvent = @"error";
NSString *const OpenEvent = @"open";
NSString *const CloseEvent = @"close";
