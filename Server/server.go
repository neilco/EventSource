package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

type EventServer struct {
	notifier chan []byte
	accept   chan chan []byte
	closing  chan chan []byte
	clients  map[chan []byte]bool
}

func NewEventServer() (server *EventServer) {
	server = &EventServer{
		notifier: make(chan []byte, 1),
		accept:   make(chan chan []byte),
		closing:  make(chan chan []byte),
		clients:  make(map[chan []byte]bool),
	}

	go server.listen()

	return
}

func (server *EventServer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	// Make sure that the writer supports flushing.
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming unsupported", http.StatusInternalServerError)
		return
	}

	client := make(chan []byte)
	server.accept <- client

	defer func() {
		server.closing <- client
	}()

	// Listen to connection close and un-register messageChan
	notify := w.(http.CloseNotifier).CloseNotify()
	go func() {
		<-notify
		server.closing <- client
	}()

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Transfer-Encoding", "chunked")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	w.WriteHeader(http.StatusOK)

	for {

		// Write to the ResponseWriter
		// Server Sent Events compatible
		fmt.Fprintf(w, "data: %s\n\n", <-client)

		// Flush the data immediatly instead of buffering it for later.
		flusher.Flush()
	}
}

func (server *EventServer) Publish(data string) {
	server.notifier <- []byte(data)
}

func (server *EventServer) listen() {
	for {
		select {
		case s := <-server.accept:

			// A new client has connected.
			// Register their message channel
			server.clients[s] = true
			log.Printf("Client added. %d registered clients", len(server.clients))
		case s := <-server.closing:

			// A client has dettached and we want to
			// stop sending them messages.
			delete(server.clients, s)
			log.Printf("Removed client. %d registered clients", len(server.clients))
		case event := <-server.notifier:
			// We got a new event from the outside!
			// Send event to all connected clients
			for client, _ := range server.clients {
				client <- event
			}
		}
	}
}

func main() {
	server := NewEventServer()

	go func() {
		for {
			time.Sleep(50 * time.Millisecond)
			go func() {
				eventString := fmt.Sprintf("the time is %v", time.Now())
				log.Println("Receiving event")
				server.Publish(eventString)
			}()
		}
	}()

	http.ListenAndServe(":8000", server)
}
