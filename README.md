# Distributed PubSub

This is a proof-of-concept implementation of Distributed PubSub using [Distributed Process Group](https://www.erlang.org/doc/apps/kernel/pg.html), [GenServer](https://hexdocs.pm/elixir/GenServer.html), [Consistent Hash Ring](https://github.com/discord/ex_hash_ring) and [Channels](https://hexdocs.pm/phoenix/channels.html). An essential component of message delivery in any chat application

Ring used to determine Topic's Node, subscribe to Topic's GenServer, and fan out messages to subscribers from there.

Direct cast helps mitigate [Bandwidth Bisection](https://en.wikipedia.org/wiki/Bisection_bandwidth) problem, to which out-of-the-box broadcast PubSub adapter is more prone to.

Topic is roughly equivalent to a Guild mentioned in [this post](https://discord.com/blog/how-discord-scaled-elixir-to-5-000-000-concurrent-users) from Discord.

**NB** Production ready system would involve dynamic topology management, replication, netsplit recovery, message queueing, overload protection and other things.

## Architecture

```plaintext
  +--------------+                                                        
  | Message Flow |                                                        
  +--------------+                                                        
                                                                          
                                                                          
  Client 1 --(Topic 1)-->  WS Server 1  -->  Topic Server 1  --------+    
                                                                     |    
                                                                     |    
  Client 2 <--(Topic 1)--  WS Server 2  <--  Topic 1 (GenServer) ----+    
                                                                          
                                                                          
                                ProcessGroup                             
                         +------------------+                             
  +------------+ Topic 1 | +--------------+ |           GenServers        
  |  Client 1  |---------| | WS Server 1  | |  +-----------------+        
  +------------+         | +-------|------+ |  | +-------------+ |        
                         |         |        |  | |   Topic 1   |-----+    
                         | +-------+------+ |  | +-------------+ |   |    
                         | |Topic Server 1|----+ +-------------+ |   |    
                         | +--------------+ |  | |   Topic X   | |   |    
                         |  |            |  |  | +-------------+ |   |    
                         |  |            |  |  +-----------------+   |    
                         |  +(Hash Ring) +  |  +-----------------+   |    
                         |  |            |  |  | +-------------+ |   |    
                         |  |            |  |  | |   Topic X   | |   |    
                         | +--------------+ |  | +-------------+ |   |    
                         | |Topic Server X|----+ +-------------+ |   |    
                         | +--------------+ |  | | Topic X + 1 | |   |    
                         |                  |  | +-------------+ |   |    
  +------------+ Topic 1 | +--------------+ |  +-----------------+   |    
  |  Client 2  |+--------|-- WS Server 2  |+-------------------------|    
  +------------+         | +--------------+ |                             
                         +------------------+                             
```

## Getting started

```
# relevant for macos
brew install asdf wxwidgets

# install erlang and elixir
asdf plugin add elixir
asdf install elixir 1.17.1-otp-27
asdf plugin add erlang
asdf install erlang 27.0

# install dependencies
mix deps.get
```

## Run cluster 

Application can be started in multiple modes: `ws` (websocket) and `ts` (topic server).

```
# start websocket servers
DPS_PORT=4000 DPS_APP=ws iex --sname dps-a -S mix phx.server
DPS_PORT=4001 DPS_APP=ws iex --sname dps-b -S mix phx.server

# start topic servers
DPS_APP=ts iex --sname dps-ts-a -S mix
DPS_APP=ts iex --sname dps-ts-b -S mix
```

Ring is static for demonstration purpose, and can be adjusted in [config/dev.exs](./config/dev.exs) given cluster changes.

## Usage 

```
# terminal 1
websocat "ws://127.0.0.1:4000/socket/websocket?vsn=2.0.0"
["1", "1", "topics:matrix", "phx_join", {}]

# terminal 2
websocat "ws://127.0.0.1:4000/socket/websocket?vsn=2.0.0"
["1", "1", "topics:matrix", "phx_join", {}]
["1", "1", "topics:matrix", "publish", ["event", { "message": "red pill or blue pill?"}]]

# => a new message should appear in the `terminal 1`
```

## Commands 

```
# tests
mix test

# quality
mix quality

# debugging
:observer.start()
```

## Resources

- [How Discord Scaled Elixir to 5M Concurrent Users](https://discord.com/blog/how-discord-scaled-elixir-to-5-000-000-concurrent-users)
- [How Discord Serves 15M Users on One Server](https://blog.bytebytego.com/p/how-discord-serves-15-million-users)
- [How WhatsApp Scaled Erlang Cluster to 10000 Nodes](https://www.youtube.com/watch?v=FJQyv26tFZ8)
- [RPC in WhatsApp with 40000+ Nodes](https://www.youtube.com/watch?v=A5bLRH-PoMY)

