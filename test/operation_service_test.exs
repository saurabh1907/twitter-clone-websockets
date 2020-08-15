defmodule OperationServiceTest do
  use ExUnit.Case
  doctest OperationService

  test "send 1 tweet with one subscriber" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(["sub1"]), :queue.new(), "client"}
      )
    GenServer.call(:operation_service, {:tweet, "username", "tweet"})
    assert :ets.lookup_element(:counter, "tweets", 2) == 1
  end

  test "send tweet with no subscriber" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(), :queue.new(), "client"}
      )
    GenServer.call(:operation_service, {:tweet, "username", "tweet"})
    assert :ets.lookup_element(:counter, "tweets", 2) == 0
  end

  test "send tweet with many subscribers" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), "client"}
      )
    GenServer.call(:operation_service, {:tweet, "username", "tweet #test"})
    assert :ets.lookup_element(:counter, "tweets", 2) == 3
  end

  test "save hashtags" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), "client"}
      )

    GenServer.call(:operation_service, {:tweet, "username", "tweet #test"})
    expected = "#test"
    assert :ets.lookup_element(:hashtags, "#test", 1) == expected
  end

  test "save hashtag tweet" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), "client"}
      )

    GenServer.call(:operation_service, {:tweet, "username", "tweet #test"})
    actual = :ets.lookup_element(:hashtags, "#test", 2)
    assert MapSet.size(actual) == 1
  end

  test "multiple users using same hashtag" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), "client"}
      )

      PersistenceService.insert_record(
        :users,
        {"username2", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), "client"}
      )
    GenServer.call(:operation_service, {:tweet, "username", "tweet #test"})

    GenServer.call(:operation_service, {:tweet, "username2", "tweet2 #test"})
    actual = :ets.lookup_element(:hashtags, "#test", 2)
    assert MapSet.size(actual) == 2
  end

  test "save mention tweet" do
    init()
    PersistenceService.insert_record(
        :users,
        {"username", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), "client"}
      )

    GenServer.call(:operation_service, {:tweet, "username", "tweet @test"})
    actual = :ets.lookup_element(:mentions, "@test", 2)
    assert MapSet.size(actual) == 1
  end

  test "see all tweet in which user is mentioned" do
    init()
    {:ok, socket} = get_mock_socket()

    PersistenceService.insert_record(
        :users,
        {"user1", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), socket}
      )
      PersistenceService.insert_record(
        :users,
        {"user2", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), socket}
      )
      PersistenceService.insert_record(
        :users,
        {"user3", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), socket}
      )

    GenServer.call(:operation_service, {:tweet, "user1", "hellow @user2"})
    GenServer.call(:operation_service, {:tweet, "user3", "whats up @user2"})
    actual = :ets.lookup_element(:mentions, "@user2", 2)
    assert MapSet.size(actual) == 2
  end

  test "no tweet if user is not mentioned" do
    init()
    {:ok, socket} = get_mock_socket()

    PersistenceService.insert_record(
        :users,
        {"user1", :online, MapSet.new(["sub1", "sub2", "sub3"]), :queue.new(), socket}
      )
    actual = :ets.lookup(:mentions, "@user2")
    assert actual == []
  end

def get_mock_socket() do
  :gen_tcp.listen(4000, [
    :binary,
    {:ip, {0, 0, 0, 0}},
    {:packet, 0},
    {:active, false},
    {:reuseaddr, true}
  ])
  end

  def init() do
    PersistenceService.start()
    OperationService.start()
    GenServer.start_link(StatsService, :ok, name: :stats_service)
    StatsService.init_counters()
  end
end
