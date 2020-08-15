defmodule SubscriptionService do
  use GenServer
  require Logger

  def start() do
    GenServer.start_link(__MODULE__, :ok, name: :subscription_service)
  end

  def init(args) do
    state = args
    {:ok, state}
  end

  def handle_call({:subscribe, username, follow},_, state) do
    for sub <- follow do
      Logger.debug("user: #{username} subscribing to: #{sub}")
      add_subscibers(sub, username)
    end

    {:reply, :ok, state}
  end

  def handle_call({:bulk_subscription, username, follwers},_, state) do
    Logger.debug("Creating Bulk subscription for user: #{username}")
    add_bulk_subscribers(username, follwers)
    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, username, unsubscribe},_, state) do
    for unsub <- unsubscribe do
      remove_subscriber(unsub, username)
    end

    {:reply, :ok, state}
  end

  defp add_subscibers(username, subscriber) do
    subs = find_user_subscribers(username) |> MapSet.put(subscriber)
    Logger.debug("user: #{username} updated subs: #{inspect(subs)}")
    PersistenceService.update_user_data(username, 3, subs)
  end

  defp add_bulk_subscribers(username, follwers) do
    existing_subs = find_user_subscribers(username)
    subs = MapSet.union(existing_subs, MapSet.new(follwers))
    PersistenceService.update_user_data(username, 3, subs)
  end

  defp remove_subscriber(username, subscriber) do
    subs = find_user_subscribers(username) |> MapSet.delete(subscriber)
    PersistenceService.update_user_data(username, 3, subs)
  end

  defp find_user_subscribers(username) do
    find_user_field(username, 2)
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
