import Config

if config_env() == :prod do
  config :tune, TuneWeb.Endpoint, server: true
end
