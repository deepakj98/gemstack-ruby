# Background jobs

> **Status: planned — Phase 4.**

```ruby
class SendWelcomeEmail < GemStack::Job
  queue :mailers
  retry_on Net::ReadTimeout, attempts: 5

  def perform(user_id)
    # ...
  end
end

SendWelcomeEmail.perform_later(user.id)
SendWelcomeEmail.perform_in(10 * 60, user.id)
```

- Asynchronous work is always explicit — nothing is moved to the background
  implicitly.
- Arguments must be JSON-serialisable primitives.
- Adapters: `:inline` (tests), `:async` (in-process, development),
  `:postgres` (default production, `FOR UPDATE SKIP LOCKED`, no Redis needed),
  `:sidekiq` (for teams already on Redis). `config.jobs.adapter = ...`.
- Retries with exponential backoff and jitter, a dead set, failure hooks and
  structured logs per execution. `gemstack dev` will run a worker alongside the API.

See ARCHITECTURE §9 and DECISIONS P-103.
