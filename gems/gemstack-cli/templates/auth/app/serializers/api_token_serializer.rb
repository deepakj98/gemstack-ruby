# frozen_string_literal: true

class ApiTokenSerializer < GemStack::Serializer
  model AuthToken
  attributes :id, :name, :last_used_at, :expires_at, :created_at
end
