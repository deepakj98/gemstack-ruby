# Testing

Generated apps use Minitest and rack-test.

```bash
gemstack test                                   # all of test/**/*_test.rb
gemstack test test/controllers/products_controller_test.rb
cd frontend && npm run typecheck
```

## Writing API tests

```ruby
require_relative "../test_helper"

class ProductsControllerTest < GemStack::TestCase
  def test_create_requires_a_product
    post_json "/api/products", {}

    assert_error 400, "parameter_missing"
    assert_equal({ "product" => ["is required"] }, json_body["errors"])
  end

  def test_show
    get_json "/api/products/1"

    assert_status 200
    assert_equal 1, json_body["id"]
  end
end
```

| Helper | |
|---|---|
| `get_json path, params = {}, headers = {}` | GET with `Accept: application/json` |
| `post_json / put_json / patch_json / delete_json path, body = {}, headers = {}` | JSON-encoded body |
| `json_body` | parsed body of the last response |
| `assert_status 201` / `assert_status :created` | shows the body on failure |
| `assert_error 422, "validation_failed"` | status + error code |
| `last_response` | the rack-test response |

## The test database

Apps with `gemstack-db` get this in `test/test_helper.rb`:

```ruby
GemStack::DB::Testing.prepare!                                   # create + migrate the TEST_DATABASE_URL database
GemStack::TestCase.include GemStack::DB::Testing::Transactions   # each test rolls back
```

Build valid records from field declarations:

```ruby
product = Product.create(GemStack::DB::Testing.sample_attributes(Product, name: "Lamp"))
post_json "/api/products", GemStack::DB::Testing.sample_payload(Product)
```

`GemStack::TestCase` is a `Minitest::Test`; use `GemStack::Testing::Helpers` to
mix the helpers into another base class. Logs are discarded in tests unless
`GEMSTACK_LOG_LEVEL` is set.

Generators write tests too: `generate resource` creates model and controller
tests for every action (including 404 and 422 cases); `generate controller`
creates one per action.

## Testing GemStack itself

```bash
bundle exec rake                 # every gem's suite + RuboCop
bundle exec rake test:gemstack-dev
```

Database tests need PostgreSQL:
`GEMSTACK_TEST_DATABASE_URL=postgres://user:pass@localhost/gemstack_test bundle exec rake test:gemstack-db`
(they skip without it).

The suites cover the settings DSL, env files, logger, inflector, errors, error mapping,
types, schemas, serializers, models, migrations, constraint-error mapping, transactional tests,
contract/TypeScript/OpenAPI generation, resource/model/migration generators,
plugins, router (static/dynamic/glob/nesting/405/HEAD), params, controllers
(callbacks, rescue_from, rendering), every default middleware, JSON codecs,
Rack::Lint compliance, the gateway (routing, headers, 503 pages, streaming,
WebSocket upgrade), the supervisor (restart, crash recovery, shutdown), the
generators, application boot/reload/eager-load, and module-boundary rules.
