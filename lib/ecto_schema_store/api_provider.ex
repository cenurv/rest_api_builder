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
      import EctoSchemaStore.ApiProvider

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
          conn |> send_response(404, %{errors: "Not Found"}) |> Plug.Conn.halt
        end
      end

      def show(%Plug.Conn{assigns: %{current: model}} = conn) do
        case conn.assigns.current do
          nil -> send_response conn, 404, %{errors: "Not Found"}
          model -> send_response conn, 200, Map.put(%{}, singular_name(), whitelist(unquote(store).to_map(model)))
        end
      end
      def show(conn), do: send_response conn, 404, %{errors: "Not Found"}

      def index(conn) do
        records = fetch_all conn
        send_response conn, 200, Map.put(%{}, plural_name(), whitelist(unquote(store).to_map(records)))
      end

      def create(%Plug.Conn{assigns: assigns} = conn) do
        parent_field = unquote(parent_field)
        parent = assigns[:current]
        changeset = __use_changeset__ :create

        params =
          if parent && parent_field do
            conn.body_params
            |> Map.put(parent_field, parent.id)
          else
            conn.body_params
          end

        response = unquote(store).insert params, changeset: changeset, errors_to_map: singular_name()

        case response do
          {:error, message} -> send_response conn, 403, %{errors: message}
          {:ok, record} -> send_response conn, 201, Map.put(%{}, singular_name(), whitelist(unquote(store).to_map(record)))
        end
      end

      def update(%Plug.Conn{assigns: assigns} = conn) do
        current = assigns[:current]

        case current do
          nil -> send_response conn, 404, %{errors: "Not Found"}
          model ->
            changeset = __use_changeset__ :update
            response = unquote(store).update model, conn.body_params, changeset: changeset, errors_to_map: singular_name()

            case response do
              {:error, message} -> send_response conn, 403, %{errors: message}
              {:ok, record} -> send_response conn, 200, Map.put(%{}, singular_name(), whitelist(unquote(store).to_map(record)))
            end
        end
      end

      def delete(%Plug.Conn{assigns: assigns} = conn) do
        current = assigns[:current]

        case current do
          nil -> send_response conn, 404, %{errors: "Not Found"}
          model ->
            unquote(store).delete model
            send_response conn, 204
        end
      end

      def __use_changeset__(_), do: :changeset

      defoverridable [__use_changeset__: 1]
    end
  end

  defmacro changeset(name) do
    quote do
      changeset unquote(name), :all
    end
  end

  defmacro changeset(name, :all) do
    quote do
      changeset unquote(name), [:create, :update]
    end
  end
  defmacro changeset(name, actions) when is_list actions do
    for action <- actions do
      quote do
        changeset unquote(name), unquote(action)
      end
    end
  end
  defmacro changeset(name, action) when is_binary action do
    quote do
      changeset unquote(name), String.to_atom(unquote(action))
    end
  end
  defmacro changeset(name, action) when is_binary name do
    quote do
      changeset String.to_atom(unquote(name)), unquote(action)
    end
  end
  defmacro changeset(name, action) when is_atom(action) and is_atom(name) do
    quote do
      def __use_changeset__(unquote(action)), do: unquote(name)
    end
  end
end
