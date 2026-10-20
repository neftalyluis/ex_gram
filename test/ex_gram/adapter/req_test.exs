if Code.ensure_loaded?(Req) do
  defmodule ExGram.Adapter.ReqTest do
    use ExUnit.Case, async: false

    alias ExGram.Adapter.Req, as: ReqAdapter

    setup do
      Application.delete_env(:ex_gram, :adapter_opts)

      on_exit(fn ->
        Application.delete_env(:ex_gram, :adapter_opts)
      end)

      :ok
    end

    defp new_req do
      Req.Request.new(method: :post, url: "/test")
    end

    describe "put_finch_options/2" do
      test "includes connect_options when no named finch is provided" do
        req = ReqAdapter.put_finch_options(new_req(), [])

        assert req.options[:connect_options] == [timeout: 30_000]
        assert req.options[:finch] == nil
        assert req.options[:pool_timeout] == 5_000
        assert req.options[:receive_timeout] == 60_000
      end

      test "omits connect_options when a named finch is provided" do
        req = ReqAdapter.put_finch_options(new_req(), finch: :my_finch)

        refute Map.has_key?(req.options, :connect_options)
        assert req.options[:finch] == :my_finch
      end

      test "uses a named finch from global adapter_opts" do
        Application.put_env(:ex_gram, :adapter_opts, finch: :global_finch)

        req = ReqAdapter.put_finch_options(new_req(), [])

        refute Map.has_key?(req.options, :connect_options)
        assert req.options[:finch] == :global_finch
      end

      test "per-call options override global adapter_opts" do
        Application.put_env(:ex_gram, :adapter_opts, finch: :global_finch)

        req = ReqAdapter.put_finch_options(new_req(), finch: :call_finch)

        refute Map.has_key?(req.options, :connect_options)
        assert req.options[:finch] == :call_finch
      end

      test "merges custom connect_options with the default timeout" do
        req =
          ReqAdapter.put_finch_options(new_req(),
            connect_options: [protocols: [:http1], inet6: true]
          )

        assert req.options[:connect_options] == [
                 timeout: 30_000,
                 protocols: [:http1],
                 inet6: true
               ]
      end

      test "uses custom connect_timeout when no named finch is provided" do
        req = ReqAdapter.put_finch_options(new_req(), connect_timeout: 10_000)

        assert req.options[:connect_options] == [timeout: 10_000]
      end
    end
  end
end
