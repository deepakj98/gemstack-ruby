# Authorization

> **Status: planned — Phase 6.**

Policies are plain Ruby objects, one per resource:

```ruby
class ProductPolicy < GemStack::Policy
  def update? = user.admin? || record.owner_id == user.id
end

authorize! product, :update?     # raises GemStack::Forbidden (403)
```

Replaceable: Pundit or Action Policy can be used instead. Today, raise
`GemStack::Forbidden` from a `before` callback.
