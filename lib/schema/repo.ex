defmodule Schema.Repo do
  @moduledoc """
  This module keeps a cache of the schema files.
  """
  use Agent

  require Logger

  alias Schema.Cache

  @spec start :: {:error, any} | {:ok, pid}
  def start(), do: Agent.start(fn -> Cache.init() end, name: __MODULE__)

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_), do: Agent.start_link(fn -> Cache.init() end, name: __MODULE__)

  @spec version :: String.t()
  def version(), do: Agent.get(__MODULE__, fn schema -> Cache.version(schema) end)

  @spec categories :: map()
  def categories(), do: Agent.get(__MODULE__, fn schema -> Cache.categories(schema) end)

  @spec categories(atom) :: nil | Cache.category_t()
  def categories(id) do
    Logger.info("category: #{id}")
    Agent.get(__MODULE__, fn schema -> Cache.categories(schema, id) end)
  end

  @spec dictionary :: Cache.dictionary_t()
  def dictionary(), do: Agent.get(__MODULE__, fn schema -> Cache.dictionary(schema) end)

  @spec classes() :: list()
  def classes(), do: Agent.get(__MODULE__, fn schema -> Cache.classes(schema) end)

  @spec classes(atom) :: nil | Cache.class_t()
  def classes(id) do
    Logger.info("class: #{id}")
    Agent.get(__MODULE__, fn schema -> Cache.classes(schema, id) end)
  end

  @spec objects() :: map()
  def objects(), do: Agent.get(__MODULE__, fn schema -> Cache.objects(schema) end)

  @spec objects(atom) :: nil | Cache.class_t()
  def objects(id) do
    Logger.info("object: #{id}")
    Agent.get(__MODULE__, fn schema -> Cache.objects(schema, id) end)
  end
end
