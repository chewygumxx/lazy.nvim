---@diagnostic disable: missing-fields, param-type-mismatch, need-check-nil
local Helpers  = require("helpers")
local Mocks    = require("mocks")
local MiniTest = require("mini.test")
local Reloader = require("lazy.manage.reloader")

describe("reloader", function()
    before_each(function()
        Helpers.fs_rm("reloader")
        Reloader.files = {}
    end)

    describe("eq()", function()
        it("is true when size and mtime match", function()
            local a = { size = 10, mtime = { sec = 1, nsec = 2 } }
            local b = { size = 10, mtime = { sec = 1, nsec = 2 } }
            assert.is_true(Reloader.eq(a, b))
        end)

        it("is false when size differs", function()
            local a = { size = 10, mtime = { sec = 1, nsec = 2 } }
            local b = { size = 11, mtime = { sec = 1, nsec = 2 } }
            assert.is_true(not Reloader.eq(a, b))
        end)

        it("is false when either stat is nil", function()
            assert.is_true(not Reloader.eq(nil, { size = 1, mtime = {} }))
        end)
    end)

    describe("check()", function()
        ---@param files table<string, string[]>
        local function stub_lsmod(files)
            return Mocks.patch("lazy.util", {
                lsmod = function(modname, fn)
                    for _, path in ipairs(files[modname] or {}) do
                        fn(modname, path)
                    end
                end,
            })
        end

        it(
            "records newly seen files as 'added' but skips reload on start",
            function()
                local file           = Helpers.fs_write(
                    "reloader/a.lua",
                    "return 1"
                )
                local restore_lsmod  = stub_lsmod({ mymod = { file } })
                local restore_config = Mocks.patch("lazy.core.config", {
                    spec = { modules = { "mymod" } },
                })
                local restore_reload = Mocks.patch("lazy.manage.reloader", {
                    reload = function()
                        error("reload should not run when start=true")
                    end,
                })
                MiniTest.finally(function()
                    restore_lsmod()
                    restore_config()
                    restore_reload()
                end)

                Reloader.check(true)
                assert.is_not_nil(Reloader.files[file])
            end
        )

        it("detects a changed file and passes it to reload()", function()
            local file           = Helpers.fs_write(
                "reloader/b.lua",
                "return 1"
            )
            local restore_lsmod  = stub_lsmod({ mymod = { file } })
            local restore_config = Mocks.patch("lazy.core.config", {
                spec = { modules = { "mymod" } },
            })
            Reloader.files[file] = { size = -1, mtime = { sec = 0, nsec = 0 } }

            local seen           = nil
            local restore_reload = Mocks.patch("lazy.manage.reloader", {
                reload = function(changes)
                    seen = changes
                end,
            })
            MiniTest.finally(function()
                restore_lsmod()
                restore_config()
                restore_reload()
            end)

            Reloader.check(false)
            assert.equal(1, #seen)
            assert.equal(file, seen[1].file)
            assert.equal("changed", seen[1].what)
        end)

        it("detects a deleted file and prunes it from M.files", function()
            local restore_lsmod  = stub_lsmod({ mymod = {} })
            local restore_config = Mocks.patch("lazy.core.config", {
                spec = { modules = { "mymod" } },
            })
            local gone           = Helpers.path("reloader/gone.lua")
            Reloader.files[gone] = { size = 1, mtime = { sec = 0, nsec = 0 } }

            local seen           = nil
            local restore_reload = Mocks.patch("lazy.manage.reloader", {
                reload = function(changes)
                    seen = changes
                end,
            })
            MiniTest.finally(function()
                restore_lsmod()
                restore_config()
                restore_reload()
            end)

            Reloader.check(false)
            assert.equal(1, #seen)
            assert.equal("deleted", seen[1].what)
            assert.equal(nil, Reloader.files[gone])
        end)

        it("does not call reload() when nothing changed", function()
            local file           = Helpers.fs_write(
                "reloader/c.lua",
                "return 1"
            )
            local restore_lsmod  = stub_lsmod({ mymod = { file } })
            local restore_config = Mocks.patch("lazy.core.config", {
                spec = { modules = { "mymod" } },
            })
            Reloader.files[file] = vim.uv.fs_stat(file)

            local called         = false
            local restore_reload = Mocks.patch("lazy.manage.reloader", {
                reload = function()
                    called = true
                end,
            })
            MiniTest.finally(function()
                restore_lsmod()
                restore_config()
                restore_reload()
            end)

            Reloader.check(false)
            assert.is_true(not called)
        end)
    end)
end)
