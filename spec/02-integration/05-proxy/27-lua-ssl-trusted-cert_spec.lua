local helpers = require "spec.helpers"

for _, strategy in helpers.each_strategy() do
  local bp

  describe("lua_ssl_trusted_cert with single entry #" .. strategy, function()
    lazy_setup(function()
      bp = helpers.get_db_utils(strategy, {
        "routes",
        "services",
        "plugins",
      })

      local r = bp.routes:insert({ hosts = {"test.dev"} })

      bp.plugins:insert({
        name = "pre-function",
        route = { id = r.id },
        config = {
          access = {
            string.format([[
                local tcpsock = ngx.socket.tcp()
                assert(tcpsock:connect("%s", %d))

                assert(tcpsock:sslhandshake(
                  nil,         -- reused_session
                  nil,         -- server_name
                  true,        -- ssl_verify
                  true         -- send_status_req
                ))

                assert(tcpsock:close())
              ]],
              helpers.mock_upstream_ssl_host,
              helpers.mock_upstream_ssl_port
            )
          },
        },
      })
    end)

    it("works with single entry", function()
      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        lua_ssl_trusted_certificate = "spec/fixtures/kong_spec.crt",
      }))
      finally(function()
        assert(helpers.stop_kong())
      end)

      local proxy_client = helpers.proxy_client()

      local res = proxy_client:get("/", {
        headers = { host = "test.dev" },
      })
      assert.res_status(200, res)
    end)

    it("works with multiple entries", function()
      assert(helpers.start_kong({
        database   = strategy,
        nginx_conf = "spec/fixtures/custom_nginx.template",
        lua_ssl_trusted_certificate = "spec/fixtures/kong_clustering_ca.crt,spec/fixtures/kong_clustering.crt",
        ssl_cert = "spec/fixtures/kong_clustering.crt",
        ssl_cert_key = "spec/fixtures/kong_clustering.key",
      }))
      finally(function()
        assert(helpers.stop_kong())
      end)

      local proxy_client = helpers.proxy_client()

      local res = proxy_client:get("/", {
        headers = { host = "test.dev" },
      })
      assert.res_status(200, res)
    end)

  end)
end


