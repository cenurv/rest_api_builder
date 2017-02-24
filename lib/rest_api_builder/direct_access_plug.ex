defmodule RestApiBuilder.DirectAccessPlug do
  @moduledoc """
  A plug that sets up the connection when direct access is applied.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%{assigns: %{direct_access: true}, method: method} = conn, _opts) do
    conn
    |> Map.put(:query_params, conn.params)
    |> Map.put(:body_params, conn.params)
  end
  def call(conn, _opts), do: conn

end
