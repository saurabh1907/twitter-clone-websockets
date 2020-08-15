defmodule AuthenticationService do
  use GenServer
  require Logger

  def start() do
    GenServer.start_link(__MODULE__, :ok, name: :authentication_service)
  end

  def init(args) do
    state = args
    {:ok, state}
  end

  def handle_call({:register, username, client}, _from, state) do
    user = PersistenceService.find_user(username)

    if user != false do
      response = %{
        "function" => "register",
        "username" => username,
        "status" => "error",
        "message" => "Username already exists"
      }

    else
      Logger.debug("New user added: #{username}")

      PersistenceService.insert_record(
        :users,
        {username, :online, MapSet.new(), :queue.new(), client}
      )
      StatsService.increment_counter("users_count")
      StatsService.increment_counter("online_users")
    end

    {:reply, :ok, state}
  end

  def handle_call({:login, username, client},_, state) do
    if member_of_users(username) do
      offline_users = :ets.lookup_element(:counter, "offline_users", 2)

      if offline_users > 0 do
        StatsService.decrement_counter("offline_users")
      end

      update_user_status(username, :online)

      if has_new_feed(username) do
        Logger.debug("New Feeds for user : #{username}")
        spawn(fn -> send_feed(username, client) end)
      end

      StatsService.increment_counter("online_users")
    end

    {:reply, :ok, state}
  end

  def handle_call({:logout, username},_, state) do
    if member_of_users(username) do
      update_user_status(username, :offline)
      StatsService.increment_counter("offline_users")
      StatsService.decrement_counter("online_users")
    end

    {:reply, :ok, state}
  end

  defp member_of_users(username) do
    :ets.member(:users, username)
  end

  defp update_user_status(username, status) do
    PersistenceService.update_user_data(username, 2, status)
  end

  defp has_new_feed(username) do
    feed = find_user_feed(username)

    if feed == :queue.new() do
      false
    else
      true
    end
  end

  def send_response(client, data) do
    encoded_response = Poison.encode!(data)
    :gen_tcp.send(client, encoded_response)
  end

  defp send_feed(username, client) do
    feeds = find_user_feed(username) |> :queue.to_list() |> Enum.chunk_every(5)

    for feed <- feeds do
      data = %{"function" => "feed", "feed" => feed, "username" => username}
      send_response(client, data)
      :timer.sleep(50)
    end

    clear_user_feed(username)
  end

  defp find_user_feed(username) do
    find_user_field(username, 3)
  end

  defp clear_user_feed(username) do
    PersistenceService.update_user_data(username, 4, :queue.new())
  end

  defp find_user_field(username, position) do
    user = PersistenceService.find_user(username)

    if user != false do
      user |> elem(position)
    else
      false
    end
  end
end
