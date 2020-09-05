defmodule CondimentTest do
  use ExUnit.Case
  doctest Condiment

  test "greets the world" do
    assert Condiment.hello() == :world
  end
end
