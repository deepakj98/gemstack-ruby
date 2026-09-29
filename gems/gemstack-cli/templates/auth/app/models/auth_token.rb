# frozen_string_literal: true

# API tokens (and single-use reset/verification tokens) — see GemStack::Auth::Tokens.
class AuthToken < GemStack::Model
  field :purpose, :string, null: false
  field :name, :string, size: 100
  field :last_used_at, :datetime
  field :expires_at, :datetime

  belongs_to :user

  dataset_module do
    def api = where(purpose: "api")
  end
end
