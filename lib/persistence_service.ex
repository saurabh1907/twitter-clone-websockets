defmodule PersistenceService do
  use GenServer
  require Logger

  def start() do
    init_tables()
    GenServer.start_link(__MODULE__, :ok, name: :persistence_service)
  end

  def init(args) do
    state = args
    {:ok, state}
  end

  defp init_tables() do
    Logger.debug("creating ETS tables")
    :ets.new(:counter, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:hashtags, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:mentions, [:set, :public, :named_table, read_concurrency: true])
    # {username, status, subscribers, feed, port}
    :ets.new(:users, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(:output, [:set, :public, :named_table, read_concurrency: true])
  end

  def insert_record(table, tuple) do
    :ets.insert(table, tuple)
  end

  def update_user_data(username, pos, value) do
    :ets.update_element(:users, username, {pos, value})
  end

  def update_counter(field, factor) do
    :ets.update_counter(:counter, field, factor)
  end

  def find_user(username) do
    record = :ets.lookup(:users, username)

    if record == [] do
      false
    else
      List.first(record)
    end
  end

  def insert_data_packet(data, table) do
    :ets.insert(table, {"data_packet", data})
  end

  def get_data_packet(table) do
    packet = false

    if :ets.member(table, "data_packet") do
      packet = :ets.lookup_element(table, "data_packet", 2)
      :ets.delete(table, "data_packet")
    end
    packet
  end

  def subscriber_of_mentions(mention) do
    :ets.member(:mentions, mention)
  end

  def get_mention_tweets(mention) do
    if subscriber_of_mentions(mention) do
      :ets.lookup_element(:mentions, mention, 2)
    else
      MapSet.new()
    end
  end
end
