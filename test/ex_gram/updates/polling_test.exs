defmodule ExGram.Updates.PollingTest do
  use ExUnit.Case, async: false

  alias ExGram.Updates.Polling

  @moduletag :capture_log

  @token "test_polling_token"

  setup do
    ExGram.Test.set_global()

    on_exit(fn ->
      Application.delete_env(:ex_gram, :polling)
    end)

    :ok
  end

  describe "getUpdates conflicts" do
    test "backs off after a 409 conflict" do
      test_pid = self()

      ExGram.Test.stub(:get_updates, fn body ->
        send(test_pid, {:get_updates, System.monotonic_time(:millisecond), body})

        {:error, %ExGram.Error{code: 409, message: "Conflict: terminated by other getUpdates request"}}
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          start_polling()

          assert_receive {:get_updates, first_at, _body}, 1000
          assert_receive {:get_updates, second_at, _body}, 2000

          assert second_at - first_at >= 500
        end)

      assert log =~ "Conflict fetching updates"
      assert log =~ "retrying in 500ms"
    end

    test "resets the conflict counter after a successful poll" do
      test_pid = self()

      ExGram.Test.expect(:get_updates, fn _body ->
        {:error, %ExGram.Error{code: 409, message: "Conflict"}}
      end)

      ExGram.Test.stub(:get_updates, fn _body ->
        send(test_pid, :get_updates_ok)
        []
      end)

      polling_pid = start_polling()

      assert_receive :get_updates_ok, 2000

      {_bot, _token, _uid, _opts, conflicts} = :sys.get_state(polling_pid)
      assert conflicts == 0
    end
  end

  defp start_polling do
    receiver_pid = start_supervised!({ExGram.Updates.PollingTest.UpdateReceiver, []})

    start_supervised!(%{
      id: {Polling, System.unique_integer([:positive])},
      start: {Polling, :start_link, [%{bot: receiver_pid, token: @token, delete_webhook: false}]}
    })
  end

  defmodule UpdateReceiver do
    @moduledoc false
    use GenServer

    def start_link(_), do: GenServer.start_link(__MODULE__, [])
    def init(_), do: {:ok, %{}}

    def handle_call({:update, _update}, _from, state), do: {:reply, :ok, state}
  end
end
