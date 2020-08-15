defmodule AuthenticationServiceTest do
  use ExUnit.Case
  doctest AuthenticationService

  test "register functionality increase count" do
    init()
    GenServer.call(:authentication_service, {:register, "test1", "client"})
    assert :ets.lookup_element(:counter, "users_count", 2) == 1
  end

  test "logout functionality decrease online count and increase offline count" do
    init()
    GenServer.call(:authentication_service, {:register, "test1", "client"})
    GenServer.call(:authentication_service, {:logout, "test1"})

    assert :ets.lookup_element(:counter, "online_users", 2) == 0
    assert :ets.lookup_element(:counter, "offline_users", 2) == 1
  end

  test "login after logout functionality increase count" do
    init()
    GenServer.call(:authentication_service, {:register, "test1", "client"})
    GenServer.call(:authentication_service, {:logout, "test1"})
    GenServer.call(:authentication_service, {:login, "test1", "client"})

    assert :ets.lookup_element(:counter, "online_users", 2) == 1
    assert :ets.lookup_element(:counter, "offline_users", 2) == 0
  end

  def init() do
    PersistenceService.start()
    AuthenticationService.start()
    GenServer.start_link(StatsService, :ok, name: :stats_service)
    StatsService.init_counters()
  end
end
