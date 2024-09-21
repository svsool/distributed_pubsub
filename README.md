# DPS

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testing

```
websocat "ws://127.0.0.1:4000/socket/websocket?vsn=2.0.0"
["1", "1", "topics:matrix", "phx_join", {}]
```
