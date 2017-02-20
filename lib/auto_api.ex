defmodule RestApiBuilder do
  @moduledoc """
  Documentation for RestApiBuilder.
  """

  defmacro __using__(opts) do
    plural_name = to_string Keyword.get(opts, :plural_name, nil)
    singular_name = to_string Keyword.get(opts, :singular_name, nil)
    activate = Keyword.get opts, :activate, nil
    default_plugs = Keyword.get opts, :default_plugs, true

    output =
      quote do
        use Plug.Router

        import RestApiBuilder

        if unquote(default_plugs) do
          plugs do
            plug RestApiBuilder.DefaultEncodingPlug
          end
        end

        @link_table String.to_atom("#{__MODULE__}:links")
        @resource_path unquote(plural_name)

        # Create a eay to track link declarations in the API module.
        :ets.new @link_table, [:duplicate_bag, :public, :named_table]

        def preset_values(conn, _opts) do
          conn
          |> Plug.Conn.assign(:api_module, __MODULE__)
        end

        def plural_name, do: unquote(plural_name)

        def singular_name, do: unquote(singular_name)

        defp send_resource(%{assigns: %{api_encoder: encoder}} = conn, resource) do
          conn = Plug.Conn.assign(conn, :resource, resource)
          encoder.(conn)
        end

        defp send_errors(%{assigns: %{api_encoder: encoder}} = conn, error_code, errors) do
          conn = Plug.Conn.assign(conn, :errors, errors)
          conn = Plug.Conn.assign(conn, :error_code, error_code)
          encoder.(conn)
        end

        defp current_location(conn) do
          current_path = "#{Enum.join(conn.script_name, "/")}/#{List.first(conn.path_info)}"
          "#{conn.scheme}://#{Plug.Conn.get_req_header(conn, "host")}/#{current_path}"
        end

        defp append_resource(%{assigns: %{resources: resources}} = conn, resource) do
          references =
            if conn.assigns[:references] do
              conn.assigns[:references]
            else
              []
            end

          entry = %{
            resource: resource,
            name: singular_name(),
            href: current_location(conn)
          }

          conn
          |> assign(:references, Enum.concat(references, [entry]))
          |> assign(:resources, Enum.concat(resources, [{resource, current_location(conn)}]))
        end
        defp append_resource(%{assigns: assigns} = conn, resource) do
          append_resource Plug.Conn.assign(conn, :resources, []), resource
        end

        defp append_api_values(%Plug.Conn{assigns: %{resources: resources}} = conn, %{} = model) do
          {_current, current_href} = Enum.at resources, -1
          relative_links = [%{name: :self, href: current_href}]

          relative_links =
            if length(resources) > 1 do
              {_parent, parent_href} = Enum.at resources, -2
              Enum.concat relative_links, [%{name: :parent, href: parent_href}]
            else
              relative_links
            end

          links =
            []
            |> Enum.concat(relative_links)
            |> Enum.concat(resource_links(current_location(conn)))

          attribute_keys =
            

          model
          |> Map.put(:type, singular_name())
          |> Map.put(:links, links)
        end

        defmacro route_to("/:id", module_path) do
          path = "/:id/#{@resource_path}"
          quote do
            forward unquote(path), to: unquote(module_path)
            link unquote(module_path).plural_name, "/#{unquote(@resource_path)}"
          end
        end

        defmacro route_to("/", module_path) do
          path = "/#{@resource_path}"
          quote do
            forward unquote(path), to: unquote(module_path)
            group_link unquote(module_path).plural_name, unquote(path)
          end
        end

        def preload_plug(%Plug.Conn{params: %{"id" => id}, path_info: path_info} = conn, _opts) 
                            when path_info != [] do
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

        def group_links(_base_url \\ ""), do: []
        def resource_links(_base_url \\ ""), do: []

        defoverridable [index: 1, show: 1, create: 1, update: 1, delete: 1, preload: 1,
                        group_links: 1, resource_links: 1, group_links: 0, resource_links: 0]
      end

    output =
      if Code.ensure_compiled?(EventQueues) do
        events =
          quote do
            use EventQueues, type: :announcer
            require EventQueues

            EventQueues.defevents [:after_insert, :after_update, :after_delete, :before_insert, :before_update, :before_delete]
          end

        [output, events]
      else
        output
      end

    if activate do
      activate_output =
        quote do
          activate unquote(activate)
        end

      List.flatten [output, activate_output]
    else
      output
    end
  end

  defmacro plugs(do: block) do
    quote do
      plug :preset_values
      plug :match
      plug :preload_plug
      plug Plug.Parsers, parsers: [:json],
                        json_decoder: Poison
      unquote(block);
      plug :dispatch
    end
  end

  @doc """
  Generates the router matching for the following actions:

  * index
  * show
  * create
  * update
  * delete
  """
  defmacro activate(:all) do
    quote do
      activate [:index, :show, :create, :update, :delete]
    end
  end
  defmacro activate(:index) do
    quote do
      get "/" do
        index var!(conn)
      end
    end
  end
  defmacro activate(:show) do
    quote do
      get "/:id" do
        show var!(conn)
      end
    end
  end
  defmacro activate(:create) do
    quote do
      post "/" do
        create var!(conn)
      end
    end
  end
  defmacro activate(:update) do
    quote do
      put "/:id" do
        update var!(conn)
      end

      patch "/:id" do
        update var!(conn)
      end
    end
  end
  defmacro activate(:delete) do
    quote do
      delete "/:id" do
        delete var!(conn)
      end
    end
  end
  defmacro activate(actions) when is_list actions do
    for action <- actions do
      quote do
        activate unquote(action)
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
      unquote(module).route_to "/:id", unquote(module)
    end
  end

  defmacro feature(name, do: block) do
    quote do
      feature unquote(name), only: [:get, :post] do
        unquote(block)
      end
    end
  end

  defmacro feature(name, opts, [do: block]) do
    path = "/:id/#{name}"
    only = Keyword.get opts, :only

    output =
      for method <- only do
        quote do
          match unquote(path), via: unquote(method) do
            unquote(block)
          end
        end
      end

    link_output =
      quote do
        link unquote(name), "/#{unquote(name)}"
      end

    [output, link_output]
  end

  defmacro group_feature(name, do: block) do
    quote do
      group_feature unquote(name), only: [:get, :post] do
        unquote(block)
      end
    end
  end

  defmacro group_feature(name, opts, [do: block]) do
    path = "/#{name}"
    only = Keyword.get opts, :only

    output =
      for method <- only do
        quote do
          match unquote(path), via: unquote(method) do
            unquote(block)
          end
        end
      end

    link_output =
      quote do
        group_link unquote(name), to_string(unquote(name))
      end

    [output, link_output]
  end

  defmacro group_link(name, href) do
    quote do
      :ets.insert @link_table, {:group, unquote(name), unquote(href)}
    end
  end

  defmacro link(name, href) do
    quote do
      :ets.insert @link_table, {:resource, unquote(name), unquote(href)}
    end
  end

  defmacro export_links do
    quote do
      @group_links :ets.lookup(@link_table, :group)
      @resource_links :ets.lookup(@link_table, :resource)

      def group_links(base_url \\ "")
      def group_links(%Plug.Conn{} = conn) do
        links =
          conn
          |> current_location
          |> group_links

        references =
          if conn.assigns[:references] do
            conn.assigns[:references]
          else
            []
          end

        references = Enum.reject references, &(&1[:name] == singular_name())
        other_links =
          for resource <- references do
            %{name: resource[:name], href: resource[:href]}
          end
        
        Enum.concat links, other_links
      end
      def group_links(base_url) do
        links =
          Enum.map @group_links, fn(entry) ->
            href =
              if String.starts_with? elem(entry, 2), "http" do
                elem(entry, 2)
              else
                "#{base_url}#{elem(entry, 2)}"
              end

            %{name: elem(entry, 1), href: href}
          end

        Enum.concat links, [
          %{name: "index", href: base_url}
        ]
      end

      def resource_links(base_url \\ "")
      def resource_links(%Plug.Conn{} = conn) do
        conn
        |> current_location
        |> resource_links
      end
      def resource_links(base_url) do
        links =
          Enum.map @resource_links, fn(entry) ->
            href =
              if String.starts_with? elem(entry, 2), "http" do
                elem(entry, 2)
              else
                "#{base_url}#{elem(entry, 2)}"
              end

            %{name: elem(entry, 1), href: href}
          end
        
        Enum.concat links, [
          %{name: "self", href: base_url}
        ]
      end
    end
  end
end
