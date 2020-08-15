defmodule StatsServiceTest do
  use ExUnit.Case
  doctest StatsService

  test "increase tweets count" do
    init()
    StatsService.increment_counter("tweets")
    assert :ets.lookup_element(:counter, "tweets", 2) == 1
  end

  test "decrease tweets count" do
    init()
    StatsService.decrement_counter("tweets")
    assert :ets.lookup_element(:counter, "tweets", 2) == -1
  end

  test "increase users_count count" do
    init()
    StatsService.increment_counter("users_count")
    assert :ets.lookup_element(:counter, "users_count", 2) == 1
  end

  test "decrease users_count count" do
    init()
    StatsService.decrement_counter("users_count")
    assert :ets.lookup_element(:counter, "users_count", 2) == -1
  end

  def init() do
    PersistenceService.start()
    GenServer.start_link(StatsService, :ok, name: :stats_service)
    StatsService.init_counters()
  end
end
