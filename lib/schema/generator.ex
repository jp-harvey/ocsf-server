defmodule Schema.Generator do
  @moduledoc """
  Random data generator using the event schema.
  """

  use Agent
  use Bitwise

  alias __MODULE__

  require Logger

  defstruct ~w[countries names words files]a

  def new(countries, names, words, files) do
    %Generator{
      countries: countries,
      files: files,
      names: names,
      words: words
    }
  end

  @spec start :: {:error, any} | {:ok, pid}
  def start(), do: Agent.start(fn -> init() end, name: __MODULE__)

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(_), do: Agent.start_link(fn -> init() end, name: __MODULE__)

  @data_dir "priv/data"

  @countries_file "country-and-continent-codes-list.json"
  @files_file "files.txt"
  @names_file "names.txt"
  @words_file "words.txt"

  @doc """
  Generate an event intance using the given class.
  """
  def event(nil), do: nil

  def event(class) do
    Logger.info("class: #{inspect(class.name)}")

    data = generate(class)
    uid = data.class_id * 1000 + (data.outcome_id &&& 0xFFFF)

    Map.put(data, :event_uid, uid)
  end

  def generate(class) do
    case class.type do
      "location" ->
        location()

      "fingerprint" ->
        fingerprint()

      _ ->
        Enum.reduce(class.attributes, Map.new(), fn {name, field} = attribute, map ->
          if field[:is_array] == true do
            Map.put(map, name, generate_array(attribute))
          else
            case field[:type] do
              "object_t" ->
                Map.put(map, name, generate_object(attribute))

              nil ->
                Logger.error("Missing class: #{name}")
                map

              _other ->
                generate(attribute, map)
            end
          end
        end)
    end
  end

  defp generate_array({:coordinates, _field}) do
    [random_float(360, 180), random_float(180, 90)]
  end

  defp generate_array({:loaded_modules, _field}) do
    Enum.map(1..random(5), fn _ -> file_name(4) end)
  end

  defp generate_array({:fingerprints, _field}) do
    Enum.map(1..random(5), fn _ -> fingerprint() end)
  end

  defp generate_array({:image_labels, _field}) do
    words(5)
  end

  defp generate_array({:groups, _field}) do
    words(5)
  end

  defp generate_array({name, field} = attribute) do
    n = random(5)

    case field[:type] do
      "object_t" ->
        generate_objects(n, attribute)

      type ->
        Enum.map(1..n, fn _ -> data(name, type, field) end)
    end
  end

  defp generate_object({_name, field}) do
    field.object_type
    |> String.to_atom()
    |> Schema.objects()
    |> generate()
  end

  defp generate_objects(n, {_name, field}) do
    object =
      field.object_type
      |> String.to_atom()
      |> Schema.objects()

    Enum.map(1..n, fn _ -> generate(object) end)
  end

  defp generate({:version, _field}, map), do: Map.put(map, :version, "1.0")
  defp generate({:lang, _field}, map), do: Map.put(map, :lang, "en")
  defp generate({:uuid, _field}, map), do: Map.put(map, :uuid, uuid())
  defp generate({:uid, _field}, map), do: Map.put(map, :uid, uuid())
  defp generate({:domain, _field}, map), do: Map.put(map, :domain, domain())
  defp generate({:hostname, _field}, map), do: Map.put(map, :hostname, domain())
  defp generate({:name, _field}, map), do: Map.put(map, :name, String.capitalize(word()))
  defp generate({:full_name, _field}, map), do: Map.put(map, :full_name, full_name(2))
  defp generate({:shell, _field}, map), do: Map.put(map, :shell, shell())
  defp generate({:timezone, _field}, map), do: Map.put(map, :timezone, timezone())
  defp generate({:company_name, _field}, map), do: Map.put(map, :company_name, full_name(2))
  defp generate({:owner, _field}, map), do: Map.put(map, :owner, full_name(2))
  defp generate({:md5, _field}, map), do: Map.put(map, :md5, md5())
  defp generate({:sha1, _field}, map), do: Map.put(map, :sha1, sha1())
  defp generate({:sha256, _field}, map), do: Map.put(map, :sha256, sha256())
  defp generate({:unmapped, _field}, map), do: Map.put(map, :unmapped, words(4))
  defp generate({:raw_data, _field}, map), do: map

  defp generate({name, field}, map) do
    requirement = field[:requirement]

    #  Generate all required and 20% of the optional fields
    if requirement == "required" or random(100) > 90 do
      Map.put(map, name, data(name, field.type, field))
    else
      map
    end
  end

  defp data(key, "string_t", _field) do
    name = Atom.to_string(key)

    if String.ends_with?(name, "_uid") or String.ends_with?(name, "_id") do
      uuid()
    else
      sentence(3)
    end
  end

  defp data(_name, "timestamp_t", _field), do: time()

  defp data(_name, "ip_t", _field), do: ipv4()

  defp data(_name, "subnet_t", _field), do: ipv4()

  defp data(_name, "mac_t", _field), do: mac()

  defp data(_name, "ipv4_t", _field), do: ipv4()

  defp data(_name, "ipv6_t", _field), do: ipv6()

  defp data(_name, "directory_t", _field), do: dir_file(random(6))

  defp data(_name, "file_t", _field), do: file_name(random(6))

  defp data(_name, "email_t", _field), do: email()

  defp data(_name, "port_t", _field), do: random(65536)

  defp data(_name, "long_t", _field), do: random(65536 * 65536)

  defp data(_name, "integer_t", field) do
    case field[:enum] do
      nil ->
        random(100)

      enum ->
        random(enum)
    end
  end

  defp data(_name, "boolean_t", _field), do: random_boolean()

  defp data(_name, "float_t", _field), do: random_float(100, 100)

  defp data(_name, _, _), do: word()

  def init() do
    dir = Application.app_dir(:schema_server, @data_dir)

    Logger.info("Loading data files: #{dir}")

    countries = read_countries(Path.join(dir, @countries_file))
    files = read_file_types(Path.join(dir, @files_file))
    names = read_data_file(Path.join(dir, @names_file))
    words = read_data_file(Path.join(dir, @words_file))

    new(countries, names, words, files)
  end

  def name() do
    Agent.get(__MODULE__, fn %Generator{names: {len, names}} -> random_word(len, names) end)
  end

  def names(n) do
    Agent.get(__MODULE__, fn %Generator{names: {len, names}} ->
      Enum.map(1..n, fn _ -> random_word(len, names) end)
    end)
  end

  def full_name(len) do
    names(len) |> Enum.join(" ")
  end

  def word() do
    Agent.get(__MODULE__, fn %Generator{words: {len, words}} -> random_word(len, words) end)
  end

  def words(n) do
    Agent.get(__MODULE__, fn %Generator{words: {len, words}} ->
      Enum.map(1..n, fn _ -> random_word(len, words) end)
    end)
  end

  def sentence(len) do
    words(len) |> Enum.join(" ")
  end

  def file_name(len) do
    name = "/" <> (words(len) |> Path.join())

    Path.join(name, file_ext())
  end

  def dir_file(len) do
    "/" <> (words(len) |> Path.join())
  end

  def file_ext() do
    [ext, _] =
      Agent.get(__MODULE__, fn %Generator{files: {len, words}} ->
        random_word(len, words)
      end)

    ext
  end

  def algorithm() do
    Enum.random(["md5", "sha1", "sha256"])
  end

  def sha256() do
    :crypto.hash(:sha256, Schema.Generator.word()) |> Base.encode16()
  end

  def sha1() do
    :crypto.hash(:sha, Schema.Generator.word()) |> Base.encode16()
  end

  def md5() do
    :crypto.hash(:md5, Schema.Generator.word()) |> Base.encode16()
  end

  def shell() do
    Enum.random(["bash", "zsh", "fish", "sh"])
  end

  def ipv4() do
    Enum.map(1..4, fn _n -> random(256) end) |> Enum.join(".")
  end

  # 00:25:96:FF:FE:12:34:56
  def mac() do
    Enum.map(1..8, fn _n -> random(256) |> Integer.to_string(16) end)
    |> Enum.join(":")
  end

  # 2001:0000:3238:DFE1:0063:0000:0000:FEFB
  def ipv6() do
    Enum.map(1..8, fn _n ->
      random(65536)
      |> Integer.to_string(16)
      |> String.pad_leading(4, "0")
    end)
    |> Enum.join(":")
  end

  def email() do
    [name(), "@", domain()] |> Enum.join()
  end

  def domain() do
    [word(), extension()] |> Enum.join(".")
  end

  def time() do
    :os.system_time(:millisecond)
  end

  def uuid() do
    UUID.uuid1()
  end

  def timezone() do
    (12 - random(24)) * 60
  end

  def random_boolean() do
    random(2) == 1
  end

  def country() do
    Agent.get(__MODULE__, fn %Generator{countries: {len, names}} -> random_word(len, names) end)
  end

  def location() do
    country = country()

    %{
      coordinates: coordinates(),
      continent: country.continent_name,
      country: country.two_letter_country_code,
      city: sentence(2) |> String.capitalize(),
      desc: country.country_name
    }
  end

  def coordinates() do
    [random_float(360, 180), random_float(180, 90)]
  end

  def random_float(n, r), do: Float.ceil(r - :rand.uniform_real() * n, 4)

  def fingerprint() do
    algorithm = algorithm()

    value =
      case algorithm do
        "md5" -> md5()
        "sha1" -> sha1()
        "sha256" -> sha256()
      end

    Map.new()
    |> Map.put(:algorithm, algorithm)
    |> Map.put(:value, value)
  end

  defp random(n) when is_integer(n), do: :rand.uniform(n) - 1

  defp random(enum) do
    {name, _} = Enum.random(enum)
    name |> Atom.to_string() |> String.to_integer()
  end

  defp random_word(len, words) do
    :array.get(random(len), words)
  end

  def extension() do
    Enum.random([
      "aero",
      "arpa",
      "biz",
      "cat",
      "com",
      "coop",
      "edu",
      "firm",
      "gov",
      "info",
      "int",
      "jobs",
      "mil",
      "mobi",
      "museum",
      "name",
      "nato",
      "net",
      "org",
      "pro",
      "store",
      "travel",
      "web"
    ])
  end

  defp read_data_file(filename) do
    list = File.stream!(filename) |> Stream.map(&String.trim_trailing/1) |> Enum.to_list()

    {length(list), :array.from_list(list)}
  end

  defp read_file_types(filename) do
    list =
      File.stream!(filename)
      |> Stream.map(&String.trim_trailing/1)
      |> Stream.map(fn s -> String.split(s, "\t") end)
      |> Stream.map(fn [ext, desc] -> [String.downcase(ext), desc] end)
      |> Enum.to_list()

    {length(list), :array.from_list(list)}
  end

  defp read_countries(filename) do
    list = File.read!(filename) |> Jason.decode!(keys: :atoms)

    {length(list), :array.from_list(list)}
  end
end
