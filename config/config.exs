# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :project4b, Project4bWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "O0d2CO/WkYrOFHMsjZ+mLW6xmvgk2N09Tkrk8wxDB2Yda6ugv3vP12hRqXCCqUa5",
  render_errors: [view: Project4bWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Project4b.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger,
backends: [:console],
compile_time_purge_level: :info

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
