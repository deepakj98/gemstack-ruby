# frozen_string_literal: true

# Realtime channels browsers may subscribe to (docs/realtime.md). Anything not
# listed here is refused.
GemStack.channels do
  channel "products" # public: new products are announced to everyone browsing the shop
end
