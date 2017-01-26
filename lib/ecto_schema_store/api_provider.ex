defmodule EctoSchemaStore.ApiProvider do
  use AutoApi.Provider

  defmacro generate(opts) do
    store = Keyword.get opts, :store, nil

    quote do
      def show(conn) do
        id = conn.params["id"]

        case unquote(store).one id, to_map: true do
          nil -> send_response conn, 404, "Not Found"
          resource -> send_response conn, 200, resource
        end
      end
    end
  end
end
