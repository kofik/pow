defmodule Pow.Store.CredentialsCacheTest do
  use ExUnit.Case
  doctest Pow.Store.CredentialsCache

  alias Pow.Store.{Backend.EtsCache, CredentialsCache}
  alias Pow.Test.Ecto.Users.{User, UsernameUser}

  @ets Pow.Test.EtsCacheMock

  setup do
    @ets.init()

    {:ok, ets: @ets}
  end

  test "stores sessions", %{ets: ets} do
    user_1 = %User{id: 1}
    user_2 = %User{id: 2}
    user_3 = %UsernameUser{id: 1}
    config = [backend: ets]
    backend_config = []

    CredentialsCache.put(config, backend_config, "key_1", user_1)
    CredentialsCache.put(config, backend_config, "key_2", user_1)
    CredentialsCache.put(config, backend_config, "key_3", user_2)
    CredentialsCache.put(config, backend_config, "key_4", user_3)

    assert CredentialsCache.get(config, backend_config, "key_1") == user_1
    assert CredentialsCache.get(config, backend_config, "key_2") == user_1
    assert CredentialsCache.get(config, backend_config, "key_3") == user_2
    assert CredentialsCache.get(config, backend_config, "key_4") == user_3

    assert CredentialsCache.user_session_keys(config, backend_config, User) == ["pow/test/ecto/users/user_sessions_1", "pow/test/ecto/users/user_sessions_2"]
    assert CredentialsCache.user_session_keys(config, backend_config, UsernameUser) == ["pow/test/ecto/users/username_user_sessions_1"]

    assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_1", "key_2"]
    assert CredentialsCache.sessions(config, backend_config, user_2) == ["key_3"]
    assert CredentialsCache.sessions(config, backend_config, user_3) == ["key_4"]

    assert ets.get(config, "#{Macro.underscore(User)}_sessions_1") == %{user: user_1, sessions: ["key_1", "key_2"]}

    CredentialsCache.put(config, backend_config, "key_2", %{user_1 | email: :updated})
    assert CredentialsCache.get(config, backend_config, "key_1") == %{user_1 | email: :updated}

    CredentialsCache.delete(config, backend_config, "key_1")
    assert CredentialsCache.get(config, backend_config, "key_1") == :not_found
    assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_2"]

    CredentialsCache.delete(config, backend_config, "key_2")
    assert CredentialsCache.sessions(config, backend_config, user_1) == []

    assert ets.get(config, "#{Macro.underscore(User)}_sessions_1") == :not_found
  end

  test "handles purged values" do
    user_1 = %User{id: 1}
    config = [backend: EtsCache]
    backend_config = [namespace: "credentials_cache:test"]

    CredentialsCache.put(config, backend_config ++ [ttl: 150], "key_1", user_1)
    :timer.sleep(50)
    CredentialsCache.put(config, backend_config ++ [ttl: 200], "key_2", user_1)
    :timer.sleep(50)

    assert CredentialsCache.get(config, backend_config, "key_1") == user_1
    assert CredentialsCache.get(config, backend_config, "key_2") == user_1
    assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_1", "key_2"]

    :timer.sleep(50)
    assert CredentialsCache.get(config, backend_config, "key_1") == :not_found
    assert CredentialsCache.get(config, backend_config, "key_2") == user_1
    assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_1", "key_2"]

    CredentialsCache.put(config, backend_config ++ [ttl: 100], "key_2", user_1)
    :timer.sleep(50)
    assert CredentialsCache.sessions(config, backend_config, user_1) == ["key_2"]

    :timer.sleep(50)
    assert CredentialsCache.get(config, backend_config, "key_1") == :not_found
    assert CredentialsCache.get(config, backend_config, "key_2") == :not_found
    assert CredentialsCache.sessions(config, backend_config, user_1) == []
    assert EtsCache.get(config, "#{Macro.underscore(User)}_sessions_1") == :not_found
  end
end
