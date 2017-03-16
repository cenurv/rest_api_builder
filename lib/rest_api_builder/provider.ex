defmodule RestApiBuilder.Provider do
  @macrocallback generate(opts :: List.t) :: Macro.t

  @callback handle_delete(conn :: Plug.Conn.t, resource :: Module.t, opts :: List.t) :: Plug.Conn.t
  @callback handle_create(conn :: Plug.Conn.t, resource :: Module.t, opts :: List.t) :: Plug.Conn.t

  defmacro __using__(_opts) do
    quote do
      import RestApiBuilder.Provider

      @behaviour RestApiBuilder.Provider
    end
  end
end
