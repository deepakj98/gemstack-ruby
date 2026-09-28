# Realtime

> **Status: planned — Phase 5.** Optional: apps that don't enable it pay nothing.

```ruby
GemStack.broadcast("orders:#{order.id}", "order.updated", order)
```

```ts
realtime.subscribe(`orders:${order.id}`, (event) => {
  queryClient.invalidateQueries({ queryKey: ["orders", order.id] });
});
```

- Default transport: **Server-Sent Events** — notifications, live updates and
  dashboards, with automatic reconnect and replay. **WebSockets** as an adapter
  for bidirectional needs (chat, presence).
- Cross-process fan-out through PostgreSQL `LISTEN/NOTIFY` by default, Redis optional.
- Long-lived connections are served off Puma's request threads.
- Channel authorisation hooks.

The dev gateway already passes SSE streams and WebSocket upgrades through
untouched. See ARCHITECTURE §10.
