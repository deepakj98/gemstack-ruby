# Authentication

> **Status: planned — Phase 6.** New apps deliberately have **no** authentication.

It will be added explicitly:

```bash
gemstack add auth
```

- Session cookies (HttpOnly, Secure, SameSite) for same-origin Next.js apps;
  bearer tokens for API clients.
- Password hashing via established libraries (bcrypt / argon2) — GemStack
  implements no cryptography itself.
- Generated code you own (controller, model, migration, frontend forms), plus
  a `before :authenticate` hook in `ApplicationController`.

Until then, any Rack-compatible approach works: a `before` callback reading
`request.get_header("HTTP_AUTHORIZATION")`, or middleware such as Warden.
