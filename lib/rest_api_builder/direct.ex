defmodule RestApiBuilder.Direct do
  defmacro generate() do
    quote do
      defp __setup_assigns__(conn, assigns) when is_list assigns do
        __setup_assigns__ conn, Enum.into(assigns, %{})
      end
      defp __setup_assigns__(conn, assigns) when is_map assigns do
        Enum.reduce Map.keys(assigns), conn, fn(key, acc) ->
          Plug.Conn.assign acc, key, Map.get(assigns, key)
        end
      end

      defp __generalize_params__(params) when is_list params do
        __generalize_params__ Enum.into(params, %{})
      end
      defp __generalize_params__(params) do
        Enum.reduce Map.keys(params), %{}, fn(key, acc) ->
          Map.put acc, to_string(key), Map.get(params, key)
        end
      end

      defp __setup_headers__(conn, headers) when is_list headers do
        Enum.reduce headers, conn, fn({key, value}, acc) ->
          Plug.Conn.put_req_header conn, key, value
        end
      end
      defp __setup_headers__(conn, headers) when is_map headers do
        Enum.reduce Map.keys(headers), conn, fn(key, acc) ->
          Plug.Conn.put_req_header conn, String.downcase(key), Map.get(headers, key)
        end
      end

      @doc """
      Will create a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_create(path \\ "/", opts \\ []) do
        process :post, path, opts
      end

      @doc """
      Will create a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_create!(path \\ "/", opts \\ []) do
        case run_create path, opts do
          {:error, errors} -> throw errors
          {:ok, resource} -> resource
        end
      end

      @doc """
      Will create a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_index(path \\ "/", opts \\ []) do
        process :get, path, opts
      end

      @doc """
      Will create a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_index!(path \\ "/", opts \\ []) do
        case run_index path, opts do
          {:error, errors} -> throw errors
          {:ok, resource} -> resource
        end
      end

      @doc """
      Will show a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_show(path, opts \\ []) do
        process :get, path, opts
      end

      @doc """
      Will show a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_show!(path, opts \\ []) do
        case run_show path, opts do
          {:error, errors} -> throw errors
          {:ok, resource} -> resource
        end
      end

      @doc """
      Will update a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_update(path, opts \\ []) do
        process :put, path, opts
      end

      @doc """
      Will update a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_update!(path, opts \\ []) do
        case run_update path, opts do
          {:error, errors} -> throw errors
          {:ok, resource} -> resource
        end
      end


      @doc """
      Will delete a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_delete(path, opts \\ []) do
        process :delete, path, opts
      end

      @doc """
      Will delete a resource.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def run_delete!(path, opts \\ []) do
        case run_delete path, opts do
          {:error, errors} -> throw errors
          {:ok, resource} -> resource
        end
      end

      @doc """
      Will execute a resource or feature.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def process(method \\ :get, path \\ "/", opts \\ []) do
        params = Keyword.get opts, :params, %{}
        assigns = Keyword.get opts, :assigns, %{}
        headers = Keyword.get opts, :headers, %{}

        conn =
          Plug.Test.conn(method, path, __generalize_params__(params))
          |> Plug.Conn.assign(:direct_access, true)
          |> __setup_assigns__(assigns)
          |> __setup_headers__(headers)
          |> Plug.Conn.put_req_header("content-type", "application/json")
          |> __MODULE__.call([])
        
        case conn do
          %{status: status} when status == 204 -> :ok
          %{status: status} when status > 199 and status < 210 -> {:ok, conn.assigns.resource}
          _ -> {:error, conn.assigns.errors}
        end
      end

      @doc """
      Will execute a resource or feature.

      Options

      * `params`        - Will set the params on Plug.Conn.
      * `assigns`       - Will set values on the assigns of the Plug.Conn passed in.
      * `headers`       - Map or list of tuples with headers.
      """
      def process!(method \\ :get, path \\ "/", opts \\ []) do
        case process method, path, opts do
          {:error, errors} -> throw errors
          {:ok, resource} -> resource
        end
      end

    end
  end
end
