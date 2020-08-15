defmodule Project4b.ServerChannel do
  use Phoenix.Channel
  require Logger


  def join("twitter", _payload, socket) do
    IO.puts "joined channel"
    {:ok, socket}
  end

  def handle_in("request", params, socket) do
    :ets.insert(:output, {"socket", socket})
    # Start simulation with given numbr of numuser and nummsg
    spawn(fn -> Project4b.Application.start_simulation(parse_ip("127.0.0.1"), 500,8) end)
    {:noreply, socket}
  end


  defp parse_ip(input) do
    # parse string to ip format
    [a, b, c, d] = String.split(input, ".")
    {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
  end
end
