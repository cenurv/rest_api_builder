defmodule RestApiBuilder.Direct do
  defmacro generate() do
    quote do
      def execute_get(path) do
        conn =
          Plug.Test.conn(:get, path)
          |> Plug.Conn.assign(:direct_execute, true)
          |> __MODULE__.call([])
        
        case conn do
          %{status: status} when status > 199 and status < 210 -> {:ok, conn.assigns.resource}
          _ -> {:error, conn.assigns.errors}
        end
      end
    end
  end
end
