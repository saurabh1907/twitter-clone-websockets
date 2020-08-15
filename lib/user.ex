defmodule User do
  use GenServer
  require Logger

  def start(username, server_ip, port) do
    :ets.new(:data_packet, [:set, :public, :named_table, read_concurrency: true])
    {:ok, socket} = UserOperations.establish_connection(server_ip, port, username)
    spawn_link(__MODULE__, :listen, [socket, :data_packet])

    GenServer.start_link(__MODULE__, %{"type"=> :standalone, "retweet_prob"=> 10}, name: :"#{username}")
    UserOperations.register(socket, username)
    standalone_client(socket, username)
  end


  defp standalone_client(socket, username) do
    option =
      IO.gets(
        "Options:\n1. Tweet\n2. Hashtag query\n3. Mention query\n4. Subscribe\n5. Unsubscribe\n6. Login\n7. Logout\nEnter your choice: "
      )

    case String.trim(option) do
      "1" ->
        tweet = IO.gets("Enter tweet: ")
        UserOperations.send_tweet(socket, String.trim(tweet), username)

      "2" ->
        hashtag = IO.gets("Enter hashtag to query for: ")
        UserOperations.hashtag_query(socket, String.trim(hashtag), username)

      "3" ->
        mention = IO.gets("Enter the username(add @ in begining) to look for: ")
        UserOperations.mention_query(socket, String.trim(mention), username)

      "4" ->
        user = IO.gets("Enter the username you want to follow(without @ in begining): ")
        UserOperations.subscribe(socket, String.split(user, [" ", "\n"], trim: true), username)

      "5" ->
        user = IO.gets("Enter the username you want to unsubscribe(without @ in begining): ")
        UserOperations.unsubscribe(socket, String.split(user, [" ", "\n"], trim: true), username)

      "6" ->
        UserOperations.perform_login(socket, username)

      "7" ->
        UserOperations.perform_logout(socket, username)

      _ ->
        IO.puts("Invalid option. Please try again")
    end

    standalone_client(socket, username)
  end

  def handle_cast({:register, data}, map) do
    if data["status"] != "success" do
      Logger.debug("registeration failed")
    end

    {:noreply, map}
  end

  def handle_cast({:mention, tweets}, map) do
    for tweet <- tweets do
      Logger.debug("Tweet: #{tweet}")
    end

    {:noreply, map}
  end

  def handle_cast({:hashtag, tweets}, map) do
    for tweet <- tweets do
      Logger.debug("Tweet: #{tweet}")
    end

    {:noreply, map}
  end

  def handle_cast({:tweet, username, sender, tweet, socket}, map) do
    Logger.debug("Tweet Recieved from username:#{username} sender: #{sender} msg: #{tweet}")
    # with probability od 10% do retweet
    type = map["type"]

    if type != :standalone and :rand.uniform(100) <= map["retweet_prob"] do
      Logger.debug("username:#{username} doing retweet")
      data = %{"function" => "tweet", "username" => username, "tweet" => tweet}
      send_message(socket, data)
    end

    if type == :standalone do
      input = IO.gets("Retweet(y/n)? ")
      input = String.trim(input)

      if input == "y" do
        Logger.debug("username:#{username} doing retweet")
        data = %{"function" => "tweet", "username" => username, "tweet" => tweet}
        send_message(socket, data)
      end
    end

    {:noreply, map}
  end

  def handle_cast({:feed, feed}, map) do
    Logger.debug("Unseen feed")

    for item <- feed do
      Logger.debug("Tweet: #{item}")
    end

    {:noreply, map}
  end

  def listen(socket, packet_table) do
    {status, request} = :gen_tcp.recv(socket, 0)

    if status == :ok do
      multiple_data = request |> String.split("}", trim: true)

      for data <- multiple_data do
        Logger.debug("data to be decoded: #{inspect(data)}")
        data_packet = PersistenceService.get_data_packet(packet_table)

        if data_packet != false do
          data = "#{data_packet}#{data}"
          Logger.debug("Found data_packet and modified to: #{data}")
        end

        try do
          data = Poison.decode!("#{data}}")
          username = data["username"]
          Logger.debug("received data at user #{username} data: #{inspect(data)}")
          process_request(data, socket)
        rescue
          Poison.SyntaxError ->
            Logger.debug("Error in user while decoding data using poison: #{data}")
            PersistenceService.insert_data_packet(data, packet_table)
        end
      end
    end
    listen(socket, packet_table)
  end

  def process_request(data, socket) do
    username = data["username"]
    case data["function"] do
      "register" ->
        GenServer.cast(:"#{username}", {:register, data})

      "hashtag" ->
        GenServer.cast(:"#{username}", {:hashtag, data["tweets"]})

      "mention" ->
        GenServer.cast(:"#{username}", {:mention, data["tweets"]})

      "tweet" ->
        GenServer.cast(
          :"#{username}",
          {:tweet, username, data["sender"], data["tweet"], socket}
        )

      "feed" ->
        GenServer.cast(:"#{username}", {:feed, data["feed"]})

      _ ->
        Logger.error("unmatched clause for data: #{inspect(data)}")
    end
  end

  def send_message(receiver, data) do
    encoded_response = Poison.encode!(data)
    :gen_tcp.send(receiver, encoded_response)
  end

  def init(map) do
    state = map
    {:ok, state}
  end
end
