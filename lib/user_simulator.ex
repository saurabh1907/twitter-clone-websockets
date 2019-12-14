defmodule UserSimulation do
  use GenServer
  require Logger

  def start(username, socket, users, frequency, num_msg) do
    GenServer.start_link(User, %{"type" => :simulate, "retweet_prob" => 10}, name: :"#{username}")
    UserOperations.register(socket, username)
    :timer.sleep(1000)
    bulk_subscription(socket, users, username)
    simulation_client(socket, username, frequency, num_msg)
  end

  def simulate(user_count, num_msg, server_ip, port) do
    user_set =
      1..user_count
      |> Enum.reduce(MapSet.new(), fn _, acc -> MapSet.put(acc, generate_random_username()) end)

    # table tracking incomplete packets and reusing in next iteration
    packet_table = :ets.new(:data_packet, [:set, :public, read_concurrency: true])

    const = zipf_constant(user_count)
    # Top 10%  and bootom 10% of total
    high = round(:math.ceil(user_count * 0.1))
    low = user_count - high

    {:ok, socket} = UserOperations.establish_connection(server_ip, port, "username")
    spawn(User, :listen, [socket, packet_table])

    for {username, pos} <- Enum.with_index(user_set) do
      available_subscribers = MapSet.difference(user_set, MapSet.new([username]))
      subscriber_count = zipf_prob(const, pos + 1, user_count)
      Logger.debug("user: #{username} subscriber_count: #{subscriber_count}")
      subscribers = get_subscribers(available_subscribers, subscriber_count)

      frequency =
        if pos + 1 <= high do
          :high
        else
          if pos + 1 > low do
            :low
          else
            :medium
          end
        end

      spawn(fn -> start(username, socket, subscribers, frequency, num_msg) end)
    end

    infinite_loop()
  end

  def init(state) do
    {:ok, state}
  end

  defp bulk_subscription(socket, users, username) do
    user_chunk_list = users |> Enum.chunk_every(70)

    for user_list <- user_chunk_list do
      data = %{"function" => "bulk_subscription", "users" => user_list, "username" => username}
      send_message(socket, data)
      :timer.sleep(50)
    end
  end

  defp simulation_client(socket, username, online_frequency, num_msg) do
    # send tweet
    tweet = generate_random_tweet(100)
    Logger.debug("#{username} sending tweet: #{tweet}")
    UserOperations.send_tweet(socket, tweet, username)
    # sleep
    # perform logout
    if online_frequency == :high do
      :timer.sleep(200)
      simulate_logout(socket, username, online_frequency)
    else
      if online_frequency == :medium do
        :timer.sleep(400)
        simulate_logout(socket, username, online_frequency)
      else
        :timer.sleep(800)
        simulate_logout(socket, username, online_frequency)
      end
    end

    if(num_msg > 0) do
      :timer.sleep(500) # doesn't tweet till 500ms
      simulation_client(socket, username, online_frequency, num_msg - 1)
    else
      UserOperations.perform_logout(socket, username, false)
    end
  end

  defp get_subscribers(available_subscribers, subscriber_count) do
    Enum.shuffle(available_subscribers) |> Enum.take(subscriber_count) |> MapSet.new()
  end

  defp simulate_logout(socket, username, frequency) do
    random_num = :rand.uniform(100)

    if frequency == :high and random_num <= 3 do
      UserOperations.perform_logout(socket, username, true)
    else
      if frequency == :medium and random_num <= 5 do
        UserOperations.perform_logout(socket, username, true)
      else
        if random_num <= 7 do
          UserOperations.perform_logout(socket, username, true)
        end
      end
    end
  end

  def send_message(receiver, data) do
    encoded_response = Poison.encode!(data)
    :gen_tcp.send(receiver, encoded_response)
  end

  defp generate_random_str(len, common_str) do
    list = common_str |> String.split("", trim: true) |> Enum.shuffle()

    random_str =
      1..len |> Enum.reduce([], fn _, acc -> [Enum.random(list) | acc] end) |> Enum.join("")

    random_str
  end

  defp generate_random_username(len \\ 10) do
    common_str = "abcdefghijklmnopqrstuvwxyz0123456789"
    generate_random_str(len, common_str)
  end

  defp generate_random_tweet(len) do
    common_str = "  abcdefghijklmnopqrstuvwxyz  0123456789"
    # generate_random_str(len, common_str)
    "my tweet"
  end

  defp zipf_constant(users) do
    # c = (Sum(1/i))^-1 where i = 1,2,3....n
    users = for n <- 1..users, do: 1 / n
    :math.pow(Enum.sum(users), -1)
  end

  defp zipf_prob(constant, user, users) do
    # z=c/x where x = 1,2,3...n
    round(constant / user * users)
  end

  def infinite_loop() do
    :timer.sleep(10000)
    infinite_loop()
  end

end
