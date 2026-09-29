# Authorization

Authentication says who the user is; **policies** say what they may do. They
come with `gemstack add auth` and are plain Ruby classes, one per model:

```bash
gemstack generate policy Order     # app/policies/order_policy.rb + test
```

```ruby
class OrderPolicy < ApplicationPolicy
  def show? = owner? || user&.admin?
  def update? = owner?

  class Scope < Scope
    def resolve = user&.admin? ? scope : scope.where(user_id: user&.id)
  end

  private

  def owner? = user && record.user_id == user.id
end
```

In controllers:

```ruby
class OrdersController < ApplicationController
  before :require_login

  def index = render(paginate(policy_scope(Order.order(:id))))
  def show = render(authorize!(Order.find(params[:id])))       # OrderPolicy#show?

  def update
    order = authorize!(Order.find(params[:id]))                 # OrderPolicy#update?
    order.update(input)
    render order
  end

  def refund = authorize!(Order.find(params[:id]), :update?)    # an explicit rule
end
```

- `authorize!(record, rule = "<action>?")` returns the record, or raises
  `GemStack::Forbidden` (403 `forbidden`).
- `policy_scope(dataset)` returns what `Scope#resolve` allows — use it for
  every list.
- `policy(record).update?` for conditional rendering, e.g. a `can_edit` field.
- The policy is found by name: an order, the `Order` class and `Order.where(...)` all use
  `OrderPolicy`; pass `policy: OtherPolicy` to override.

**Deny by default**: `index?`, `show?`, `create?`,
`update?` and `destroy?` are `false` until a policy says otherwise, and a
missing `Scope#resolve` raises instead of listing everything. Anonymous users
reach policies as `user = nil`.

Pundit or Action Policy work too, if you prefer them.
