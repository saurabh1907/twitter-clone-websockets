defmodule StatsService do
  use GenServer
  require Logger

  def start() do
    init_counters()
    GenServer.start_link(__MODULE__, :ok, name: :stats_service)
    spawn fn -> print_statistics() end
  end

  def init(args) do
    state = args
    {:ok, state}
  end

  def init_counters() do
    PersistenceService.insert_record(:counter, {"tweets", 0})
    PersistenceService.insert_record(:counter, {"users_count", 0})
    PersistenceService.insert_record(:counter, {"online_users", 0})
    PersistenceService.insert_record(:counter, {"offline_users", 0})
  end

  defp print_statistics(period \\ 4000, last_tweet_count \\ 0) do
    # Period is how fast stats are displayed
    :timer.sleep(period)
    current_tweet_count = :ets.lookup_element(:counter, "tweets", 2)
    tweet_per_sec = (current_tweet_count - last_tweet_count) / (10000 / 1000)
    users_count = :ets.lookup_element(:counter, "users_count", 2)
    online_users = :ets.lookup_element(:counter, "online_users", 2)
    offline_users = :ets.lookup_element(:counter, "offline_users", 2)

    Logger.info(
      "Server Statistics\nUsers Count: #{users_count} | Tweet Rate: #{tweet_per_sec} | Online Users: #{online_users} | Offline Users: #{offline_users}")
      print_statistics(period, current_tweet_count)
  end

  def increment_counter(field) do
    PersistenceService.update_counter(field, 1)
  end

  def decrement_counter(field) do
    PersistenceService.update_counter(field, -1)
  end
end
