# Routing

Routes live in `config/routes.rb` and are **relative to `config.http.api_path`**
(`/api` by default). The same setting tells the dev gateway which requests go to
Ruby, so the two can never disagree.

```ruby
GemStack.routes do
  get "/status", to: "status#show"          # GET /api/status → StatusController#show
  post "/webhooks/stripe", to: "webhooks#stripe"

  resources :products                        # index create show update destroy
  resources :orders, only: %i[index show]
  resources :inventory_items, path: "/inventory", controller: "stock"

  resources :products do
    member { post "/publish", action: :publish }      # POST /api/products/:id/publish
    collection { get "/search", action: :search }     # GET  /api/products/search
    resources :reviews, only: %i[index create]        # /api/products/:product_id/reviews
  end

  namespace :admin do                                  # /api/admin/..., Admin::*Controller
    resources :users, only: :index
  end
  scope "/v2", module: "v2" do
    get "/ping", to: "ping#show"                       # V2::PingController
  end

  get "/ping", to: ->(env) { [200, {}, ["pong"]] }    # any Rack app
  mount Sidekiq::Web, at: "/sidekiq"                   # /api/sidekiq and below
end
```

`gemstack routes` lists the table:

```text
GET     /api/products      products#index
POST    /api/products      products#create
GET     /api/products/:id  products#show
...
```

## Resources

| Action | Verb | Path |
|---|---|---|
| index | GET | `/products` |
| create | POST | `/products` |
| show | GET | `/products/:id` |
| update | PATCH, PUT | `/products/:id` |
| destroy | DELETE | `/products/:id` |

There are no `new`/`edit` routes — forms live in Next.js. Multi-word names are
dasherized in URLs: `resources :line_items` → `/api/line-items`, handled by
`LineItemsController`.

## Parameters

- `:name` matches one segment; values are percent-decoded
  (`/tags/hello%20world` → `"hello world"`).
- A trailing `*name` matches one or more remaining segments
  (`/files/*path` → `"a/b/c.txt"`).
- Static segments beat parameters, parameters beat globs, so
  `/products/featured` can coexist with `/products/:id`.

## Matching behaviour

- Trailing slashes and repeated slashes are normalised.
- `HEAD` is answered by the matching `GET` route with the body removed.
- Unknown paths → `404 route_not_found`; known paths with the wrong verb →
  `405 method_not_allowed` with an `Allow` header.
- Duplicate routes raise at boot.

## Performance

Fully static paths are one hash lookup. Paths with parameters are matched in a
per-verb segment trie, so lookup cost depends on path depth, not the number of
routes (see [performance](performance.md)).

In development the file reloads when saved.
