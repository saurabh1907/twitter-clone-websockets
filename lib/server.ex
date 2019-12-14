defmodule Server do
  use GenServer
  require Logger

  def start(port) do
    PersistenceService.start() # Database Module. Intitialize first
    StatsService.start()
    AuthenticationService.start()
    OperationService.start()
    SubscriptionService.start()
    {:ok, socket} = :gen_tcp.listen(port, [:binary,{:ip, {0, 0, 0, 0}},{:packet, 0}, {:active, false},
        {:reuseaddr, true}])
    GenServer.start_link(__MODULE__, socket, name: :server)

    Logger.info("Server ready for connection")
    # spawn(__MODULE__, :accept_connections, [socket])
    accept_connections(socket)
  end

  defp handle_connection(client, data_packet) do
    {status, request} = :gen_tcp.recv(client, 0)

    if status == :ok do
      # this will handle the case when there are more than one
      Logger.debug("Request: #{inspect(request)}")
      multiple_data = request |> String.split("}", trim: true)

      for data <- multiple_data do
        Logger.debug("Encoded data: #{inspect(data)}")
        data_packet_data = PersistenceService.get_data_packet(data_packet)

        if data_packet_data != false do
          data = "#{data_packet_data}#{data}"
          Logger.debug("Data packet converted to: #{data}")
        end

        try do
          data = Poison.decode!("#{data}}")
          Logger.debug("received data from client #{inspect(client)} data: #{inspect(data)}")
          handle_request(data, client)
        rescue
          Poison.SyntaxError ->
            Logger.debug("Error parsing data using poison: #{data}")
            PersistenceService.insert_record(data_packet, {"data_packet", data})
        end
      end
    end
    handle_connection(client, data_packet)
  end

  def handle_request(data, client) do
    case Map.get(data, "function") do
      "register" ->
        GenServer.call(:authentication_service, {:register, data["username"], client})

      "login" ->
        GenServer.call(:authentication_service, {:login, data["username"], client})

      "logout" ->
        GenServer.call(:authentication_service, {:logout, data["username"]})

      "hashtag" ->
        GenServer.call(
          :operation_service,
          {:hashtag, data["hashtag"], data["username"], client}
        )

      "mention" ->
        GenServer.call(
          :operation_service,
          {:mention, data["mention"], data["username"], client}
        )

      "tweet" ->
        GenServer.call(:operation_service, {:tweet, data["username"], data["tweet"]})

      "subscribe" ->
        GenServer.call(:subscription_service, {:subscribe, data["username"], data["users"]})

      "unsubscribe" ->
        GenServer.call(
          :subscription_service,
          {:unsubscribe, data["username"], data["users"]}
        )

      "bulk_subscription" ->
        GenServer.call(
          :subscription_service,
          {:bulk_subscription, data["username"], data["users"]}
        )

      _ ->
        Logger.error("Request unidentified: #{inspect(data)}")
    end
  end

  def accept_connections(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Logger.debug("Alloted new connection socket")
    data_packet = :ets.new(:data_packet, [:set, :public, read_concurrency: true])
    # Provide server operations to each new connection indendently
    spawn(fn -> handle_connection(client, data_packet) end)
    # Loop for accepting future connections
    accept_connections(socket)
  end

  def init(state) do
    {:ok, state}
  end
end
