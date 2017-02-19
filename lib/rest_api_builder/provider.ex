defmodule RestApiBuilder.Provider do
  @macrocallback generate(opts :: List.t) :: Macro.t

  defmacro __using__(_opts) do
    quote do
      import RestApiBuilder.Provider

      @behaviour RestApiBuilder.Provider
    end
  end
end
