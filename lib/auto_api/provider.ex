defmodule AutoApi.Provider do
  @macrocallback generate(opts :: List.t) :: Macro.t

  defmacro __using__(_opts) do
    quote do
      import AutoApi.Provider

      @behaviour AutoApi.Provider
    end
  end

  # def send_resource(conn, resource) do
  #   conn
  #   |> Plug.Conn.assign(:resource, resource)
  # end

  # defp send_errors(conn, errors) do
  #   conn
  #   |> Plug.Conn.assign(:errors, errors)
  # end

  # def send_response(conn, status, resource) do
  #   conn
  #   |> Plug.Conn.put_resp_content_type("application/json")
  #   |> Plug.Conn.send_resp(status, Poison.encode!(resource))
  # end

  # def send_response(conn, status) do
  #   conn
  #   |> Plug.Conn.send_resp(status, "")
  # end
end
