# Getting started

## Requirements

Ruby ≥ 4.0, Bundler, Node.js ≥ 20 and npm. New apps use SQLite, which needs
nothing else; `--database=postgresql` or `--database=mysql2` need that server
([databases](database.md)).

Install the `gemstack` command:

```bash
gem install gemstack
```

New apps get `.ruby-version` and `.tool-versions` pinned to the Ruby that created them.

## Create an application

```bash
gemstack new shop
cd shop
gemstack dev
```

`gemstack new` writes the app, runs `bundle install`, creates the database
(`gemstack db:create`), runs `npm install`, and initialises git. With
PostgreSQL or MySQL, put credentials in `config/database.yml` (or
`DATABASE_URL` / `TEST_DATABASE_URL` in `.env`) and run `gemstack db:create`.

Open **http://localhost:3000** — the starter page calls
`GET /api/health` from the browser and shows whether the Ruby API answered.

`gemstack dev` prints:

```text
  GemStack v0.2.0 · development

  ✓ Gateway    http://localhost:3000  (/api/* → Ruby, everything else → Next.js)
  … Ruby API   starting on 127.0.0.1:52011 (internal)
  … Next.js    starting on 127.0.0.1:52012 (internal)

  Application: http://localhost:3000

gemstack│ ✓ Ruby API ready (0.5s)
gemstack│ ✓ Next.js ready (1.3s)
api     │ 12:45:34.040 INFO  GET /api/health status=200 ms=3.9 id=7e6c…
```

The internal ports are chosen automatically; you only ever use port 3000
(`PORT=4000 gemstack dev` to change it). Ctrl-C stops everything.

## Add a resource

```bash
gemstack generate resource Product name:string price:decimal description:text:optional
gemstack db:migrate
```

Open **http://localhost:3000/products** — list, create, view, edit and delete
products. The pages use a TypeScript client generated from the backend
(`frontend/lib/api/generated/`), which `gemstack dev` keeps in sync as you
change serializers, schemas or routes. See [resource generation](resource-generation.md).

## Add a custom endpoint

```bash
gemstack generate controller Status show
```

creates `app/controllers/status_controller.rb`, a test, and the route
`get "/status/:id", to: "status#show"` in `config/routes.rb`. Edit the action:

```ruby
class StatusController < ApplicationController
  def show
    render({ id: params[:id], time: Time.now })
  end
end
```

Save and request it — no restart needed:

```bash
curl localhost:3000/api/status/1
# {"id":"1","time":"2026-09-28T12:00:00.000Z"}
```

Call it from the frontend (`frontend/app/page.tsx`):

```tsx
const status = useQuery({ queryKey: ["status", 1], queryFn: () => api.get<{ id: string }>("/status/1") });
```

## Run the tests

```bash
gemstack test          # Ruby (Minitest + rack-test)
cd frontend && npm run typecheck
```

## What's in the project

```text
config/app.rb        GemStack.configure — the one configuration file
config/routes.rb     routes, relative to /api
config/puma.rb       server settings (threads/workers via ENV)
app/controllers/     ApplicationController + yours; any app/<dir> autoloads (models/, serializers/, services/…)
db/migrations/       Sequel migrations; db/seeds.rb for development data
test/                GemStack::TestCase tests
frontend/            Next.js App Router + TypeScript + TanStack Query
bin/gemstack         CLI binstub for this app's bundle
```

There is no User model, no authentication and no CRUD: you decide what the
application contains. Add them when you need them: `gemstack add auth`
([authentication](authentication.md)), `gemstack add storage` ([storage](storage.md)).

Something not working? `gemstack doctor` checks your setup and says what to fix; while `gemstack dev`
runs, [http://localhost:3000/api/docs](http://localhost:3000/api/docs) lists every endpoint
([development tools](development.md)).

Next: [routing](routing.md), [controllers](controllers.md), [configuration](configuration.md).
