defmodule Project4b.Application do
  use Application
  require Logger
  @port 5000
  @server_ip "127.0.0.1"

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      Project4bWeb.Endpoint
      # Starts a worker by calling: Project4b.Worker.start_link(arg)
      # {Project4b.Worker, arg},
    ]

    opts = [strategy: :one_for_one, name: Project4b.Supervisor]
    Supervisor.start_link(children, opts)
    args = System.argv()
    if(length(args) == 0)do

      Server.start(@port)
    else
      type = Enum.at(args, 0)
      server_ip = parse_ip(@server_ip)
      if type == "user" do
        start_client(server_ip)
      else
        # type == simulation
        num_user = Enum.at(args, 0)|> String.to_integer()
        num_msg = Enum.at(args, 1)|> String.to_integer()
        start_simulation(server_ip, num_user, num_msg)
      end
    end
  end

  defp start_client(server_ip) do
    Logger.info("Establishing Server connection")
    username = IO.gets("Enter username to register: ")
    username = String.trim(username)
    User.start(username, server_ip, @port)
  end

  def start_simulation(server_ip, num_user, num_msg) do
    Logger.info("Starting Sumulation")
    no_connections = div(num_user, 4)
    remaining= rem(num_user,4)
    Enum.each(1..no_connections, fn _x ->
      spawn(fn -> UserSimulation.simulate(4, num_msg, server_ip, @port) end)
    end)

    if(remaining != 0)do
      spawn(fn -> UserSimulation.simulate(remaining, num_msg, server_ip, @port) end)
    end
    infinite_loop()
  end

  defp parse_ip(input) do
    # parse string to ip format
    [a, b, c, d] = String.split(input, ".")
    {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
  end

  def infinite_loop() do
    :timer.sleep(10000)
    infinite_loop()
  end

  def config_change(changed, _new, removed) do
    Project4bWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
