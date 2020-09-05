defmodule Condiment do
  @moduledoc """
  Add flavors to your context APIs easily!

  No need to create different functions to cater to different use cases, instead you can have one single public function and add flavors conditionally, with Condiment.
  """

  @type t :: %__MODULE__{
          token: any(),
          opts: list(),
          resolvers: list(),
          condiment_opts: list()
        }

  defstruct [:token, :opts, :resolvers, :condiment_opts]

  defmodule NotImplementedError do
    defexception [:message]
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(condiment, _opts) do
      data = condiment |> Map.from_struct() |> Enum.into([])
      concat(["#Condiment<", inspect(data), ">"])
    end
  end

  @doc """
  To use `Condiment`, you start with the `Condiment.new/2,3` interface.

  The currently available options for `condiment_opts` is:
    - `:on_unknown_fields
      one of `:nothing`, `:error`, or `:raise` (default). This option specify what to do when user supplies a field that's not resolvable.
  """
  @spec new(any, list(), list()) :: Condiment.t()
  def new(token, opts, condiment_opts \\ []) do
    %__MODULE__{
      token: token,
      opts: opts,
      resolvers: [],
      condiment_opts: condiment_opts
    }
  end

  @doc """
  `field` is what you allow users to query for. The resolver is how to resolve that query.

  The resolver has to be 2-arity, the first argument is the the result of the previously ran resolver (the first resolver gets `token` instead).
  """
  @spec add(Condiment.t(), atom, (any, map() -> any)) :: Condiment.t()
  def add(%__MODULE__{} = condiment, key, resolver)
      when is_function(resolver, 2) and is_atom(key) do
    %{condiment | resolvers: [{key, resolver} | condiment.resolvers]}
  end

  @doc """
  Runs all of the resolvers conditionally based on what user requested, it runs in the order that you defined (not the order the user supplied).
  """
  @spec run(Condiment.t()) :: any
  def run(%__MODULE__{
        token: token,
        opts: opts,
        resolvers: resolvers,
        condiment_opts: condiment_opts
      }) do
    resolvable_fields = Keyword.keys(resolvers)
    requested_fields = Keyword.keys(opts)

    validation = validate_opts(opts, resolvers)
    unknown_fields_strategy = Keyword.get(condiment_opts, :on_unknown_fields, :raise)

    case {validation, unknown_fields_strategy} do
      {{:error, field}, :error} ->
        {:error, build_message(field, resolvable_fields)}

      {{:error, field}, :raise} ->
        raise NotImplementedError, build_message(field, resolvable_fields)

      _ ->
        map_opts = opts |> Enum.into(%{})

        resolvers
        |> Enum.reverse()
        |> Enum.filter(fn {field, _resolver} ->
          field in requested_fields
        end)
        |> Enum.reduce(token, fn {_field, resolver}, acc ->
          resolver.(acc, map_opts)
        end)
    end
  end

  defp validate_opts(opts, resolvers) do
    resolvable_fields = Keyword.keys(resolvers)
    requested_fields = Keyword.keys(opts)

    requested_fields
    |> Enum.reduce_while(:ok, fn f, _acc ->
      case f in resolvable_fields do
        true ->
          {:cont, :ok}

        false ->
          {:halt, {:error, f}}
      end
    end)
  end

  defp build_message(field, resolvable_fields) do
    "Don't know how to resolve #{inspect(field)}. You can add to #{__MODULE__} with `#{__MODULE__}.add/3`. Current known resolvables: #{
      inspect(resolvable_fields)
    }"
  end
end
