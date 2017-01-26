defmodule AutoApi.Provider do
  @macrocallback generate(opts :: List.t) :: Macro.t

  defmacro __using__(_opts) do
    quote do
      import AutoApi.Provider

      @behaviour AutoApi.Provider
    end
  end

  def send_response(conn, status, resource) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(status, Poison.encode!(resource))
  end
end
