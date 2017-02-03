defmodule AutoApi do
  @moduledoc """
  Documentation for AutoApi.
  """

  defmacro __using__(opts) do
    resource_name = to_string Keyword.get(opts, :name, nil)

    quote do
      use Plug.Router

      import AutoApi

      plug :match
      plug :preload_plug
      plug :dispatch

      @resource_path unquote(resource_name)

      defp send_response(conn, status, resource) do
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, Poison.encode!(resource))
      end

      defmacro route_to(prepend_path, module_path) do
        path = "#{prepend_path}/#{@resource_path}"
        quote do
          forward unquote(path), to: unquote(module_path)
        end
      end

      def preload_plug(%Plug.Conn{path_params: %{"id" => id}} = conn, _opts) do
        preload conn
      end
      def preload_plug(conn, _opts) do
        conn
      end

      defp __not_ready__(conn) do
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(501, "Not yet implemented.")
      end

      def preload(conn), do: conn
      def index(conn), do: __not_ready__ conn
      def show(conn), do: __not_ready__ conn
      def create(conn), do: __not_ready__ conn
      def update(conn), do: __not_ready__ conn
      def delete(conn), do: __not_ready__ conn

      defoverridable [index: 1, show: 1, create: 1, update: 1, delete: 1, preload: 1]

      get "/" do
        index var!(conn)
      end

      get "/:id" do
        show var!(conn)
      end

      post "/" do
        create var!(conn)
      end

      put "/:id" do
        update var!(conn)
      end

      delete "/:id" do
        delete var!(conn)
      end
    end
  end

  defmacro provider(provider_module, opts) do
    quote do
      require unquote(provider_module)
      unquote(provider_module).generate unquote(opts)
    end
  end

  defmacro include(module) do
    quote do
      require unquote(module)
      unquote(module).route_to "/", unquote(module)
    end
  end

  defmacro children(module) do
    quote do
      require unquote(module)
      unquote(module).route_to "/:id/", unquote(module)
    end
  end

  defmacro feature(name, do: block) do
    path = "/:id/#{name}"
    quote do
      post unquote(path) do
        unquote(block)
      end
    end
  end
end
