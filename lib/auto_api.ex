defmodule AutoApi do
  @moduledoc """
  Documentation for AutoApi.
  """

  defmacro __using__(opts) do
    resource_name = Keyword.get opts, :name, nil

    quote do
      use Plug.Router

      import AutoApi

      plug :match
      plug :dispatch

      def resource_name, do: to_string(unquote(resource_name))

      defp __not_ready__(conn) do
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(501, "Not yet implemented.")
      end

      def index(conn), do: __not_ready__ conn
      def show(conn), do: __not_ready__ conn
      def create(conn), do: __not_ready__ conn
      def update(conn), do: __not_ready__ conn
      def delete(conn), do: __not_ready__ conn

      defoverridable [index: 1, show: 1, create: 1, update: 1, delete: 1]

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
      # nothing
    end
  end
end
