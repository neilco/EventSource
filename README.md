# EventSource
**Server-Sent Events for iOS and Mac**

![Travis](https://travis-ci.org/neilco/EventSource.svg?branch=master)

## What does it do?

It creates a long-lived, unidirectional HTTP channel between your Cocoa app and a web server so that your app can receive events from the server. 

#### Listening for Named Events

Subscribing to a _named event_ is done via the `addEventListener:handler:` method, as shown below:

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source addEventListener:@"hello_event" handler:^(Event *e) {
    NSLog(@"%@: %@", e.event, e.data);
}];
```

It's super simple and will be familiar to anyone who has seen any Server-Sent Events JavaScript code.

#### Listening for All Events

There's a `onMessage:` method that will receive all message events from the server. 

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source onMessage:^(Event *e) {
    NSLog(@"%@: %@", e.event, e.data);
}];
```

#### Listening for Connection State Changes

Additionally, there are `onOpen:`,  `onError:`, and `onReadyStateChanged:` methods to receive connection state events. 

```objc
NSURL *serverURL = [NSURL URLWithString:@"http://127.0.0.1:8000/"];
EventSource *source = [EventSource eventSourceWithURL:serverURL];
[source onError:^(Event *e) {
    NSLog(@"ERROR: %@", e.data);
}];
```

With the exception of the `onError:`, the `event` and `data` properties for these events will be `null`. Check the `readyState` property on the event. 

#### Graceful Connection Handling

Reconnection attempts are automatic and seamless, even if the server goes go. How frequently reconnection attempts are made is controlled by the server by setting the `retry` key on its events. 

### Server Code

This is a simple [Node.js](http://nodejs.org/) app that will generate the Server-Sent Events. The events are created at a rate of one per second.

```
var http = require('http');

http.createServer(function (req, res) {
    res.writeHead(200, { 'Transfer-Encoding': 'chunked', 'Content-Type': 'text/event-stream' });
 
    setInterval(function() { 
        var now = new Date().getTime();
        var payload = 'event: hello_event\ndata: {"message":"' + now + '"}\n\n'; 
        res.write(payload); 
    }, 1000);
}).listen(8000);
```

The payload above doesn't include an `id` parameter, but if you include one it will be available in the `Event` object in your Cocoa code.

There is also [a simple Go Server-Sent Events server](https://github.com/neilco/EventSource/blob/master/Server/server.go). 

## Installation

The easiest way to get started is to use Carthage. Just add the following line to your Cartfile and the run `carthage update` from your terminal:

```ruby
github "neilco/EventSource"
```

If you prefer Cocoapods, add this to your Podfile and then run `pod install` from your terminal:

```ruby
pod 'EventSource'
``` 

Otherwise, just include the contents of the [EventSource directory](https://github.com/neilco/EventSource/tree/master/EventSource) manually to your project.

## Other bits

### Contact

I'm [@neilco](http://github.com/neilco) on GitHub and I'm [@neilco](https://twitter.com/neilco) on Twitter.

### License

[MIT license](http://neil.mit-license.org)

Copyright (c) 2013 Neil Cowburn (http://github.com/neilco/)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
