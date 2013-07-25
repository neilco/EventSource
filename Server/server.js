var http = require('http');

http.createServer(function (req, res) {
    res.writeHead(200, { 'Transfer-Encoding': 'chunked', 'Content-Type': 'text/event-stream' });
 
    setInterval(function() { 
        var packet = 'event: hello_event\ndata: {"message":"' + new Date().getTime() + '"}\n\n'; 
        res.write(packet); 
    }, 1000);
}).listen(8000);