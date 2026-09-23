---@diagnostic disable: missing-fields, assign-type-mismatch
local Sections = require("lazy.view.sections")

---@param title string
local function section(title)
    for _, s in ipairs(Sections) do
        if s.title == title then
            return s
        end
    end
    error("no such section: " .. title)
end

---@param overrides? table
local function fake_task(overrides)
    return vim.tbl_extend("force", {
        name = "task",
        has_errors = function()
            return false
        end,
        running = function()
            return false
        end,
        output = function()
            return ""
        end,
    }, overrides or {}
    )
end

---@param v any
---@return boolean
local function truthy(v)
    return not not v
end

describe("view.sections", function()
    it("Failed matches a plugin with any errored task", function()
        local filter = section("Failed").filter
        assert.is_true(
            truthy(
                filter({
                    _ = {
                        tasks = {
                            fake_task({
                                has_errors = function()
                                    return true
                                end,
                            }),
                        },
                    },
                })
            )
        )
        assert.is_true(not truthy(filter({ _ = { tasks = { fake_task() } } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Working matches _.working or any running task", function()
        local filter = section("Working").filter
        assert.is_true(truthy(filter({ _ = { working = true } })))
        assert.is_true(
            truthy(
                filter({
                    _ = {
                        tasks = {
                            fake_task({
                                running = function()
                                    return true
                                end,
                            }),
                        },
                    },
                })
            )
        )
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Build matches _.build", function()
        local filter = section("Build").filter
        assert.is_true(truthy(filter({ _ = { build = true } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it(
        "Breaking Changes matches a log task line with a '!:' marker",
        function()
            local filter = section("Breaking Changes").filter
            assert.is_true(
                truthy(
                    filter({
                        _ = {
                            tasks = {
                                fake_task({
                                    name = "log",
                                    output = function()
                                        return "abcd123 feat!: message"
                                    end,
                                }),
                            },
                        },
                    })
                )
            )
            assert.is_true(
                not truthy(
                    filter({
                        _ = {
                            tasks = {
                                fake_task({
                                    name = "log",
                                    output = function()
                                        return "abcd123 feat: message"
                                    end,
                                }),
                            },
                        },
                    })
                )
            )
        end
    )

    it("Updated matches when _.updated.from differs from .to", function()
        local filter = section("Updated").filter
        assert.is_true(
            truthy(filter({ _ = { updated = { from = "a", to = "b" } } }))
        )
        assert.is_true(
            not truthy(filter({ _ = { updated = { from = "a", to = "a" } } }))
        )
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Installed matches _.cloned", function()
        local filter = section("Installed").filter
        assert.is_true(truthy(filter({ _ = { cloned = true } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Updates matches when _.updates is not nil", function()
        local filter = section("Updates").filter
        assert.is_true(truthy(filter({ _ = { updates = {} } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Log matches a log task with non-blank output", function()
        local filter = section("Log").filter
        assert.is_true(
            truthy(
                filter({
                    _ = {
                        tasks = {
                            fake_task({
                                name = "log",
                                output = function()
                                    return "some output"
                                end,
                            }),
                        },
                    },
                })
            )
        )
        assert.is_true(
            not truthy(
                filter({
                    _ = {
                        tasks = {
                            fake_task({
                                name = "log",
                                output = function()
                                    return "   "
                                end,
                            }),
                        },
                    },
                })
            )
        )
    end)

    it("Clean matches installed plugins marked for cleanup", function()
        local filter = section("Clean").filter
        assert.is_true(
            truthy(filter({ _ = { kind = "clean", installed = true } }))
        )
        assert.is_true(
            not truthy(filter({ _ = { kind = "clean", installed = false } }))
        )
    end)

    it("Not Installed matches uninstalled, non-disabled plugins", function()
        local filter = section("Not Installed").filter
        assert.is_true(truthy(filter({ _ = { installed = false } })))
        assert.is_true(not truthy(filter({ _ = { installed = true } })))
        assert.is_true(
            not truthy(
                filter({ _ = { installed = false, kind = "disabled" } })
            )
        )
    end)

    it("Outdated matches _.outdated", function()
        local filter = section("Outdated").filter
        assert.is_true(truthy(filter({ _ = { outdated = true } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Loaded matches when _.loaded is not nil", function()
        local filter = section("Loaded").filter
        assert.is_true(truthy(filter({ _ = { loaded = true } })))
        assert.is_true(truthy(filter({ _ = { loaded = false } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Not Loaded matches _.installed", function()
        local filter = section("Not Loaded").filter
        assert.is_true(truthy(filter({ _ = { installed = true } })))
        assert.is_true(not truthy(filter({ _ = {} })))
    end)

    it("Disabled matches _.kind == 'disabled'", function()
        local filter = section("Disabled").filter
        assert.is_true(truthy(filter({ _ = { kind = "disabled" } })))
        assert.is_true(not truthy(filter({ _ = { kind = "clean" } })))
    end)
end)
