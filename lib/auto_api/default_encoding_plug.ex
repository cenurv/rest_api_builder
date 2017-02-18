defmodule AutoApi.DefaultEncodingPlug do
  @moduledoc """
  A plug that reads and writes the output of a REST resource.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    assign conn, :api_encoder, &serialize/1
  end

  def serialize(%{assigns: %{errors: errors}} = conn) do
    send_resp conn, 400, Poison.encode!(%{errors: errors})
  end
  def serialize(%{assigns: %{resource: resource, api_module: api_module}} = conn) when is_list resource do
    IO.inspect resource
    plural_name = api_module.plural_name
    links = api_module.group_links

    response =
      %{}
      |> Map.put(plural_name, resource)
      |> Map.put(:links, links)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response))
  end
  def serialize(%{assigns: %{resource: resource, api_module: api_module}} = conn) do
    IO.inspect resource
    singular_name = api_module.singular_name
    links = api_module.resource_links

    response =
      %{}
      |> Map.put(singular_name, resource)
      |> Map.put(:links, links)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(response))
  end

end
