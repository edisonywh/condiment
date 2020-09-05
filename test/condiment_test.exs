defmodule CondimentTest do
  use ExUnit.Case
  doctest Condiment

  describe "Condiment.new/2" do
    test "should always return %Condiment{}" do
      condiment = create_condiment()

      assert %Condiment{token: _token, opts: _opts, resolvers: _resolvers} = condiment
    end

    test "token, opts are set correctly" do
      token = %{a: 1, b: 2, c: 3}
      opts = [c: 8]

      condiment = create_condiment(token: token, opts: opts)

      assert condiment.token == token
      assert condiment.opts == opts
      assert condiment.resolvers == []
    end
  end

  describe "Condiment.add/3" do
    test "should set resolvers correctly" do
      token = %{a: 1, b: 2, c: 3}
      opts = [c: 8]

      condiment = create_condiment(token: token, opts: opts)

      condiment =
        condiment
        |> Condiment.add(:field1, fn _token, _requests -> nil end)
        |> Condiment.add(:field2, fn _token, _requests -> nil end)

      assert is_list(condiment.resolvers) == true
      assert length(condiment.resolvers) == 2
    end
  end

  describe "Condiment.run/1" do
    test "final result is the result of the last resolver" do
      token = %{}
      opts = [first: 1, second: 2]

      condiment = create_condiment(token: token, opts: opts)

      condiment =
        condiment
        |> Condiment.add(:first, fn token, %{first: first} ->
          Map.put(token, :field1, first)
        end)

      condiment1 =
        condiment |> Condiment.add(:second, fn token, _opts -> Map.put(token, :result, :hey) end)

      condiment2 = condiment |> Condiment.add(:second, fn _token, _opts -> nil end)

      assert Condiment.run(condiment1) == %{result: :hey, field1: 1}
      assert Condiment.run(condiment2) == nil
    end

    test "should run in order of resolvers added, not user-specified" do
      token = %{}
      opts = [second: 2, first: 1]

      condiment = create_condiment(token: token, opts: opts)

      result =
        condiment
        |> Condiment.add(:first, fn _token, %{first: first} -> 1 end)
        |> Condiment.add(:second, fn _oken, _opts -> 2 end)
        |> Condiment.run()

      assert result == 2
    end

    test "should run resolvers for requested fields only" do
      token = %{}
      opts = [first: 1]

      condiment = create_condiment(token: token, opts: opts)

      result =
        condiment
        |> Condiment.add(:first, fn token, %{first: first} ->
          Map.put(token, :field1, first)
        end)
        |> Condiment.add(:second, fn token, %{second: second} ->
          Map.put(token, :from_field_2, second)
        end)
        |> Condiment.run()

      assert result == %{field1: 1}
    end

    test "should run in order" do
      token = []
      opts = [second: 2, first: 1]

      condiment = create_condiment(token: token, opts: opts)

      result =
        condiment
        |> Condiment.add(:first, fn token, %{first: first} ->
          token ++ [first]
        end)
        |> Condiment.add(:second, fn token, %{second: second} ->
          token ++ [second]
        end)
        |> Condiment.run()

      assert result == [1, 2]
    end

    test "should return error tuple on unknown field if on_unknown_fields: :error" do
      token = []
      opts = [unresolvable_field: true, condiment_opts: [on_unknown_fields: :error]]

      condiment = create_condiment(token: token, opts: opts)

      result =
        condiment
        |> Condiment.add(:first, fn _token, _ -> nil end)
        |> Condiment.add(:second, fn _token, _ -> nil end)

      assert {:error, _message} = Condiment.run(result)
    end

    test "should not raise error on unknown field if on_unknown_fields: :nothing" do
      token = []
      opts = [unresolvable_field: true, condiment_opts: [on_unknown_fields: :nothing]]

      condiment = create_condiment(token: token, opts: opts)

      result =
        condiment
        |> Condiment.add(:first, fn _token, _ -> nil end)
        |> Condiment.add(:second, fn _token, _ -> nil end)

      assert [] == Condiment.run(result)
    end

    test "should raise error on unknown field if on_unknown_fields: :raise" do
      token = []
      opts = [unresolvable_field: true, condiment_opts: [on_unknown_fields: :raise]]

      condiment = create_condiment(token: token, opts: opts)

      result =
        condiment
        |> Condiment.add(:first, fn _token, _ -> nil end)
        |> Condiment.add(:second, fn _token, _ -> nil end)

      assert_raise Condiment.NotImplementedError, fn ->
        Condiment.run(result)
      end
    end
  end

  defp create_condiment(opts \\ []) do
    token = Keyword.get(opts, :token, %{one: 1, two: 2, three: 3})
    opts = Keyword.get(opts, :opts, [])
    condiment_opts = Keyword.get(opts, :condiment_opts, [])

    Condiment.new(token, opts, condiment_opts)
  end
end
