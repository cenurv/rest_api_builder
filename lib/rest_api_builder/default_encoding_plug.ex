defmodule RestApiBuilder.DefaultEncodingPlug do
  @moduledoc """
  A plug that reads and writes the output of a REST resource.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%{assigns: %{api_module: api_module}} = conn, _opts) do
    if conn.body_params[api_module.singular_name] do
      conn
      |> Map.put(:body_params, conn.body_params[api_module.singular_name])
      |> assign(:api_encoder, &serialize/1)
    else
      assign conn, :api_encoder, &serialize/1
    end    
  end

  def serialize(%{assigns: %{errors: errors, error_code: error_code}} = conn) do
    if conn.assigns[:direct_access] do
      conn
      |> send_resp(error_code, "")
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(error_code, Poison.encode!(%{errors: errors}))
    end
  end
  def serialize(%{assigns: %{resource: resources, api_module: api_module}} = conn) when is_list resources do
    plural_name = api_module.plural_name
    links = api_module.group_links conn

    resources =
      for resource <- resources do
        resource_links = api_module.resource_links(Map.put(conn, :path_info, Enum.concat(conn.path_info, [to_string(resource[:id])])))
        resource_links = Enum.concat links, resource_links

        if length(resource_links) > 0 do
          Map.put(resource, :links, prepare_links(resource_links))
        else
          resource
        end
      end

    response =
      %{}
      |> Map.put(plural_name, resources)

    response =
      if length(links) > 0 do
        Map.put(response, :links, prepare_links(links))
      else
        response
      end

    if conn.assigns[:direct_access] do
      conn
      |> send_resp(success_code(conn), "")
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(success_code(conn), Poison.encode!(response))
    end
  end
  def serialize(%{assigns: %{resource: nil}} = conn) do
    conn
    |> send_resp(success_code(conn), "")
  end
  def serialize(%{assigns: %{resource: resource, api_module: api_module}} = conn) do
    singular_name = api_module.singular_name
    links = api_module.resource_links(Map.put(conn, :path_info, [resource[:id]]))
    group_links = api_module.group_links(Map.put(conn, :path_info, []))
    links = Enum.concat group_links, links

    resource =
      if length(links) > 0 do
        Map.put(resource, :links, prepare_links(links))
      else
        resource
      end

    response =
      %{}
      |> Map.put(singular_name, resource)

    if conn.assigns[:direct_access] do
      conn
      |> send_resp(success_code(conn), "")
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(success_code(conn), Poison.encode!(response))
    end
  end

  defp prepare_links(links, acc \\ %{})
  defp prepare_links([], acc), do: acc
  defp prepare_links([h | t], acc) do
    prepare_links t, Map.put(acc, h.name, h.href)
  end

  defp success_code(%{method: "GET"}), do: 200
  defp success_code(%{method: "POST"}), do: 201
  defp success_code(%{method: "PUT"}), do: 200
  defp success_code(%{method: "PATCH"}), do: 200
  defp success_code(%{method: "DELETE"}), do: 204

end
