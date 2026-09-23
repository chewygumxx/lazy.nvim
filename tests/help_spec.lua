local Help     = require("lazy.help")
local Helpers  = require("helpers")
local Mocks    = require("mocks")
local MiniTest = require("mini.test")
local Util     = require("lazy.util")

describe("help", function()
    before_each(function()
        Helpers.fs_rm("help")
    end)

    it(
        "index() returns {} without writing when dir/doc already exists",
        function()
            Helpers.fs_create({ "help/skip/doc/.keep" })
            local plugin  = Helpers.plugin({
                name = "skip",
                dir = Helpers.path("help/skip"),
            })
            local restore = Mocks.patch_config({
                readme = { skip_if_doc_exists = true },
            })
            MiniTest.finally(restore)

            assert.same({}, Help.index(plugin))
        end
    )

    it("index() tags every markdown header and writes a doc copy", function()
        Helpers.fs_write(
            "help/myplug/README.md",
            "# My Plugin\n\nIntro text.\n\n## Usage\n\nMore text.\n"
        )
        local plugin  = Helpers.plugin({
            name = "myplug",
            dir = Helpers.path("help/myplug"),
        })
        local restore = Mocks.patch_config({
            readme = {
                files = { "README.md" },
                root = Helpers.path("help/out"),
            },
        })
        MiniTest.finally(restore)
        vim.fn.mkdir(Helpers.path("help/out/doc"), "p")

        local tags = Help.index(plugin)
        assert.same({
            ["myplug-my-plugin"] = {
                tag = "myplug-my-plugin",
                line = "# My Plugin",
                file = "myplug.md",
            },
            ["myplug-usage"] = {
                tag = "myplug-usage",
                line = "## Usage",
                file = "myplug.md",
            },
        }, tags)

        local written = Util.read_file(Helpers.path("help/out/doc/myplug.md"))
        assert.is_true(written:find("# My Plugin", 1, true) ~= nil)
        assert.is_true(
            written:find("<!-- vim: set ft=markdown: -->", 1, true) ~= nil
        )
    end)

    it("index() escapes brackets and slashes in tag search lines", function()
        Helpers.fs_write(
            "help/esc/README.md",
            "# Setup [required]/notes\n"
        )
        local plugin  = Helpers.plugin({
            name = "esc",
            dir = Helpers.path("help/esc"),
        })
        local restore = Mocks.patch_config({
            readme = {
                files = { "README.md" },
                root = Helpers.path("help/out"),
            },
        })
        MiniTest.finally(restore)
        vim.fn.mkdir(Helpers.path("help/out/doc"), "p")

        local tags = Help.index(plugin)
        local tag  = next(tags)
        assert.equal("# Setup \\[required\\]\\/notes", tags[tag].line)
    end)

    it(
        "update() merges tags across plugins into a sorted tags file",
        function()
            Helpers.fs_write("help/update/p1/README.md", "# P1\n")
            Helpers.fs_write("help/update/p2/README.md", "# P2\n")
            local restore_config  = Mocks.patch_config({
                readme = {
                    files = { "README.md" },
                    root = Helpers.path("help/update-out"),
                },
            })
            local restore_plugins = Mocks.patch("lazy.core.config", {
                plugins = {
                    p1 = Helpers.plugin({
                        name = "p1",
                        dir = Helpers.path("help/update/p1"),
                    }),
                    p2 = Helpers.plugin({
                        name = "p2",
                        dir = Helpers.path("help/update/p2"),
                    }),
                },
            })
            MiniTest.finally(function()
                restore_config()
                restore_plugins()
            end)

            Help.update()

            local tags  = Util.read_file(
                Helpers.path("help/update-out/doc/tags")
            )
            local lines = vim.split(vim.trim(tags), "\n")
            assert.same({
                "!_TAG_FILE_ENCODING\tutf-8\t//",
                "p1-p1\tp1.md\t/# P1",
                "p2-p2\tp2.md\t/# P2",
            }, lines)
        end
    )
end)
