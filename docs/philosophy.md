# Philosophy

> The developer should write business logic. GemStack should handle the
> engineering plumbing with sensible, production-ready defaults.

## Principles

1. **Convention over configuration.** If there's an obvious sensible default,
   it is the default: `/api` prefix, autoloaded `app/`, automatic dev ports,
   JSON error envelope, request IDs.
2. **DRY across the stack.** One definition should drive Ruby, the API
   contract, TypeScript types and the frontend client (Phase 2 onwards).
3. **Production-ready defaults.** Security headers, body limits, filtered
   logs, hidden internals in production errors — on from the first request.
4. **Fast by default, proven by measurement.** Designs that are cheap by
   construction (compiled middleware, O(1) static routes, lazy parsing) and
   benchmarks before optimisations.
5. **Smart defaults, not rigid defaults.** Every default can be configured,
   swapped or replaced. The four levels are: use it · configure it · swap the
   implementation · replace the layer.

## What GemStack is not

- **Not Rails.** No feature-for-feature parity, no server-rendered views, no
  asset pipeline, no global monkey patches. Next.js is the frontend.
- **Not a walled garden.** Standard RubyGems and Bundler, standard npm. Any gem
  in the Gemfile works exactly as usual; nothing is sandboxed.
- **Not a generator of things you didn't ask for.** New apps have no users,
  auth, CRUD, or tables. Optional modules are added explicitly.
- **Not a reinvention.** Rack, Puma, Zeitwerk, Thor, TanStack Query and (soon)
  Sequel do their jobs well; GemStack integrates them. We build our own only
  where it's small and clearly better for the use case (router, dev gateway) —
  and record why in [DECISIONS.md](../DECISIONS.md).
