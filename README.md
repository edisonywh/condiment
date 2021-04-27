# Condiment

> Important: I used this in my app [Slick Inbox](http://slickinbox.com/) for awhile but I have since decided to move off it. I find that even though it's easy to see allowed query options, it's pretty difficult to reuse queries.

> Right now I'm using the traditional `Enum.reduce(options, query, ...` way with a Query module for now (still a single unified API), I am still testing that out, but I might at some point switch back to non-unified API I outlined below (each function does a specific task), so just letting you know that this is not currently in used anymore, so use at your own risk. 

Add flavors to your context function without the hassles.

No need to create different functions to cater to different use cases, instead you can have one single public function and add flavors conditionally.

`Condiment` is a very simple library, the API is largely influenced by libraries such as `Ecto.Multi`, `TokenOperator`, `Sage`, `Absinthe` etc. Scroll down to read about why you would use `Condiment`.

## Usage

### Example
```elixir
def list_posts(opts \\ []) do
  posts_query() # this can be anything you want
  |> Condiment.new(opts)
  |> Condiment.add(:featured, &featured_query/2)
  |> Condiment.add(:user_id, &by_user_query/2)
  |> Condiment.run()
  |> Repo.all()
end
```

### Condiment.new(token, opts, condiment_opts \\ [])
To use `Condiment`, you start with the `Condiment.new/2` interface.

The first argument is the `token`. It will be passed down to each of the condiment you define later on.

The second argument is the list of keys that Condiment should act on. Typically it's a list of user-supplied fields.

The third argument is `condiment_opts`, currently available options are:

- `:on_unknown_fields` - one of `:nothing`, `:error`, or `:raise` (default). This option specify what to do when user supplies a field that's not resolvable.

### Condiment.add(condiment, field, resolver)
`field` is what you allow users to query for. The resolver is how to resolve that query.

The resolver has to be 2-arity, the first argument is the the result of the previously ran resolver (the first resolver gets `token` instead).

### Condiment.run(condiment)
Runs all of the resolvers conditionally based on what user requested, it runs in the order that you defined (not the order the user supplied).

For example,

```elixir
def test(opts \\ []) do
  token
  |> Condiment.new(opts)
  |> Condiment.add(:first, &query/2)
  |> Condiment.add(:second, &query/2)
  |> Condiment.run()
end
```

If the user did this:

```elixir
Blog.test(second: true, first: true)
```

Even though `second` is the first in the list, `first` is still going to run first, because of how you added the resolvers.

## Why would I use Condiment?
Phoenix helpfully nudges us to group domain logic and separate it from querying layers like controller directly.

In theory that is great, but in practice, I often see cases where we start adding a bunch of functions in context like this, where we have multiple functions that largely do the same thing, but differ ever so slightly that requires us to add a new function to cover a new use case.

```elixir
def list_posts() do
  Repo.all(Post)
end

def list_featured_posts() do
  Post
  |> where([p], p.featured == true)
  |> Repo.all()
end

def list_posts_by_user(user) do
  Post
  |> where([p], p.user_id == user_id)
  |> Repo.all()
end

def list_featured_posts_by_user(user_id) do
  Post
  |> where([p], p.featured == true)
  |> where([p], p.user_id == user_id)
  |> Repo.all()
end
```

### Ecto composable queries

Now, the amazing Ecto allow us to compose our queries, so we can in fact, simplify it to look a lot nicer.

```elixir
# We can separate them into different queries
defp posts_query(), do: Post
defp featured_post_query(query, featured), do: query |> where([q], q.featured == ^featured)
defp by_user_query(query, user_id), do: query |> where([q], q.user_id == ^user_id)

# And then we can use them like so:
def list_posts_by_user(user_id) do
  posts_query()
  |> by_user_query(user_id)
end

def list_featured_posts() do
  posts_query()
  |> featured_post_query(true)
end

def list_featured_posts_by_user(user_id) do
  posts_query()
  |> featured_post_query(true)
  |> by_user_query(user_id)
end
```

This is great since it allows me to reuse my queries, and is what I've been using, but it still requires me to build different functions for different use cases.

My ideal scenario would be to have one a single unified interface, so I could query like this:

```elixir
Blog.list_posts(user_id: user_id, featured: true)
```

### Maybe it's `maybe_*`?
One idea that this could work, is with `maybe_*` functions. This is a pattern that I've seen around and I *mostly* like it, an example would look like this:

```elixir
def list_posts(opts \\ []) do
  Post
  |> maybe_featured(opts)
  |> maybe_by_user(opts)
end
```

This allows me to have one public interface, and delegate all conditional logic to the `maybe_*` functions, but I dislike this approach for the following reasons:

- You need to always pass in something to your `maybe_*` functions (opts in this case).
- You don't know what condition the `maybe` is based on.
- You need to dig into each function to see what actually gets applied.
- It is not clear what options you can pass in.

Enter `Condiment`!

### Condiment

With `Condiment`, you get the best of all the other approaches I mentioned above. Your context function can now look like this:

```elixir
def list_posts(opts \\ []) do
  posts_query()
  |> Condiment.new(opts)
  |> Condiment.add(:featured, &featured_query/2)
  |> Condiment.add(:user_id, &by_user_query/2)
  |> Condiment.run()
  |> Repo.all()
end
```

Great thing is, it is immediately obvious what API you have defined (`featured`, `user_id`), you don't need to hop around functions to figure it out.

`Condiment` conditionally resolve fields for you, based on what your users are asking for, so:

```elixir
Blog.list_posts() # returns all posts, skipping Condiment
Blog.list_posts(featured: true) # returns all featured posts
Blog.list_posts(user_id: 1) # returns all posts by user
Blog.list_posts(featured: true, user_id: 1) # returns all featured posts by user
```

## How does it work?
`Condiment` is nothing but a glorified `Enum.reduce` with condition checks built-in.

This means your `token` is really just an initial `accumulator` to `Enum.reduce`!

This allow you to do some cool tricks like:

- inject default queries
- build up data conditionally
- optimize REST API by resolving only fields that user requested for (like GraphQL)

## Why is it named Condiment?
Imagine in a restaurant where chefs cook dishes, different patrons have different taste buds, some prefer extra salt, others crave for extra black pepper.

One way you can cater to that is to allow patrons to specify `saltyness` level or `black pepper` amount with their order, and the chef can cater to the requests accordingly. This is a lot of work, for example for every customization you want to add, you now need to re-print your menu to tell user about the new available customizable option.

With condiments, the restaurant can just put an assortment of condiments on the table, and the patrons can decide for themselves how much salt/pepper they want.

I find that this translates perfectly to what the library is doing - you being the restaurant, put an assortment of condiments (with `Condiment.add/3`), and your patrons can use them however they like.

Also, because this library *conditionally* adds stuffs into the dish, I thought that sounded quite like `Condiment`, so why not? :)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `condiment` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:condiment, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/condiment](https://hexdocs.pm/condiment).

