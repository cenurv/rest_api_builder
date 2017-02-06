defmodule EctoSchemaStore.ApiProvider do
  use AutoApi.Provider

  defmacro generate(opts) do
    store = Keyword.get opts, :store, nil
    parent_field = Keyword.get opts, :parent, nil

    parent_field =
      if is_binary parent_field do
        String.to_atom parent_field
      else
        parent_field
      end

    quote do
      def store, do: unquote(store)

      defp whitelist(models) when is_list models do
        Enum.map models, fn(model) -> whitelist model end
      end
      defp whitelist(model) do
        keys = EctoSchemaStore.Utils.keys unquote(store).schema
        Map.take model, keys
      end

      defp fetch_all(%Plug.Conn{assigns: %{current: parent}} = conn) do
        parent_field = unquote(parent_field)

        if parent && parent_field do
          query =
            []
            |> Keyword.put(parent_field, parent.id)

          unquote(store).all query 
        else
          unquote(store).all
        end
      end
      defp fetch_all(conn) do
        unquote(store).all
      end

      def preload(%Plug.Conn{path_params: %{"id" => id}, assigns: assigns} = conn) do
        parent_field = unquote(parent_field)

        parent = assigns[:current]
        current =
          if parent && parent_field do
            query =
              [id: id]
              |> Keyword.put(parent_field, parent.id)

            unquote(store).one query 
          else
            unquote(store).one id: id
          end

        validated =
          cond do
            is_nil(current) -> false
            is_nil(parent) or is_nil(parent_field) -> true
            true -> true
          end

        if validated do
          conn
          |> assign(:parent, parent)
          |> assign(:current, current)
        else
          conn |> send_response(404, "Not Found") |> Plug.Conn.halt
        end
      end

      def show(%Plug.Conn{assigns: %{current: model}} = conn) do
        case conn.assigns.current do
          nil -> send_response conn, 404, "Not Found"
          model -> send_response conn, 200, whitelist(unquote(store).to_map(model))
        end
      end
      def show(conn), do: send_response conn, 404, "Not Found"

      def index(conn) do
        records = fetch_all conn
        send_response conn, 200, whitelist(unquote(store).to_map(records))
      end
    end
  end
end
