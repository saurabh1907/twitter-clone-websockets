defmodule UserOperations do
  require Logger

  def register(server, username) do
    data = %{function: :register, username: username}
    send_message(server, data)
  end

  def send_tweet(socket, tweet, username) do
    data = %{"function" => "tweet", "username" => username, "tweet" => tweet}
    send_message(socket, data)
  end

  def hashtag_query(socket, hashtag, username) do
    data = %{"function" => "hashtag", "username" => username, "hashtag" => hashtag}
    send_message(socket, data)
  end

  def mention_query(socket, mention, username) do
    data = %{"function" => "mention", "mention" => mention, "username" => username}
    send_message(socket, data)
  end

  def subscribe(socket, users, username) do
    data = %{"function" => "subscribe", "users" => users, "username" => username}
    send_message(socket, data)
  end

  def unsubscribe(socket, users, username) do
    data = %{"function" => "unsubscribe", "users" => users, "username" => username}
    send_message(socket, data)
  end

  def establish_connection(server_ip, port, username) do
    :gen_tcp.connect(server_ip, port, [:binary, {:active, false}, {:packet, 0}])

    # Logger.debug("Connecting to server")
    # {:ok, pid} = PhoenixChannelClient.start_link()
    # timeline_channel = channel_connect(pid, username, server_ip, port)

    # if(status == :ok) do
    #   Logger.debug("Connected")
    # else
    #   Logger.info "Server is not running"
    #   Logger.info("Start server with: mix run proj4 server")
    #   Logger.info("Start simulation on another console with: mix run proj4 num_user num_msg")
    #   exit(:shutdown)
    # end
  end

  def perform_login(server, username) do
    data = %{"function" => "login", "username" => username}
    Logger.debug("Sending login message to server")
    send_message(server, data)
  end

  def perform_logout(server, username, autologin \\ false) do
    # send logout message
    data = %{"function" => "logout", "username" => username}
    send_message(server, data)

    if autologin do
      # sleep for some random time between 1 to 5000 milliseconds
      sec = :rand.uniform(5000)
      Logger.debug("#{username} sleeping for #{sec} seconds")
      :timer.sleep(sec)
      # send login back to server
      perform_login(server, username)
    end
  end

  def send_message(receiver, data) do
    encoded_response = Poison.encode!(data)
    :gen_tcp.send(receiver, encoded_response)
  end

  defp channel_connect(pid, username, server_ip, port) do
    {:ok, socket} = PhoenixChannelClient.connect(pid,
    host: server_ip,
    port: 4000,
    path: "/socket/websocket",
    params: %{token: "something"},
    secure: false)

  channel = PhoenixChannelClient.channel(socket, "timeline:feed", %{name: "Ryo"})

  case PhoenixChannelClient.join(channel) do
    {:ok, %{message: message}} -> IO.puts(message)
    {:error, %{reason: reason}} -> IO.puts(reason)
    :timeout -> IO.puts("timeout")
    {:exception, error} -> raise error
  end
  channel
  end


end
