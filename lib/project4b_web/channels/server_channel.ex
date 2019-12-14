defmodule Project4b.ServerChannel do
  use Phoenix.Channel
  require Logger


  def join("twitter", _payload, socket) do
    # Logger.info "incoming payload: #{inspect(payload)}"
    # ServerUtil.insert_record(:users, {payload["username"], :online, MapSet.new, :queue.new, socket})
    # ServerUtil.increase_counter("total_users")
    # ServerUtil.increase_counter("online_users")
    IO.puts "joined channel"
    {:ok, socket}
  end

  def handle_in("request", params, socket) do
    :ets.insert(:output, {"socket", socket})
    IO.puts "reached in request"
    spawn(fn -> Project4b.Application.start_simulation(parse_ip("127.0.0.1"), 500, 20) end)

    # response = Server.handle_request(params, socket)
    out_socket = :ets.lookup_element(:output, "socket",2)
    broadcast! out_socket, "output", %{msg: "71"}
    {:noreply, socket}
  end


  defp parse_ip(input) do
    # parse string to ip format
    [a, b, c, d] = String.split(input, ".")
    {String.to_integer(a), String.to_integer(b), String.to_integer(c), String.to_integer(d)}
  end
  # def send_response(client, data) do
  #   encoded_response = Poison.encode!(data)
  #   push(client, "response", encoded_response)
  # end
end
