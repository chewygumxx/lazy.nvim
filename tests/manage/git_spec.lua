local Git      = require("lazy.manage.git")
local Helpers  = require("helpers")
local Mocks    = require("mocks")
local MiniTest = require("mini.test")

---@param rel string
---@return string
local function repo(rel)
    return Helpers.path(rel)
end

describe("git", function()
    before_each(function()
        Helpers.fs_rm("git")
    end)

    it("head() reads the first line of .git/HEAD", function()
        Helpers.fs_write("git/r1/.git/HEAD", "ref: refs/heads/main\n")
        assert.equal("ref: refs/heads/main", Git.head(repo("git/r1")))
    end)

    it("head() returns nil when there is no .git dir", function()
        assert.equal(nil, Git.head(repo("git/missing")))
    end)

    it("ref() reads a loose ref file", function()
        Helpers.fs_write("git/r2/.git/refs/heads/main", "deadbeef1234\n")
        assert.equal("deadbeef1234", Git.ref(repo("git/r2"), "heads", "main"))
    end)

    it(
        "ref() falls back to packed-refs when the loose ref is missing",
        function()
            Helpers.fs_write(
                "git/r3/.git/packed-refs",
                "# pack-refs\ncafebabe0000 refs/heads/main\n"
            )
            assert.equal(
                "cafebabe0000",
                Git.ref(repo("git/r3"), "heads", "main")
            )
        end
    )

    it("packed_refs() parses ref lines into a name -> hash map", function()
        Helpers.fs_write(
            "git/r4/.git/packed-refs",
            "# pack-refs with: peeled fully-peeled sorted\n"
                .. "aaa111 refs/heads/main\n"
                .. "bbb222 refs/tags/v1.0.0\n"
        )
        assert.same({
            ["heads/main"] = "aaa111",
            ["tags/v1.0.0"] = "bbb222",
        }, Git.packed_refs(repo("git/r4")))
    end)

    it(
        "get_config() parses sections, quoted subsections, and keys",
        function()
            Helpers.fs_write(
                "git/r5/.git/config",
                table.concat({
                    "[core]",
                    "\trepositoryformatversion = 0",
                    '[remote "origin"]',
                    "\turl = https://example.com/foo.git",
                    "\tfetch = +refs/heads/*:refs/remotes/origin/*",
                }, "\n")
            )
            local config = Git.get_config(repo("git/r5"))
            assert.equal("0", config["core.repositoryformatversion"])
            assert.equal(
                "https://example.com/foo.git",
                config["remote.origin.url"]
            )
        end
    )

    it("get_origin() reads remote.origin.url from the config", function()
        Helpers.fs_write(
            "git/r6/.git/config",
            '[remote "origin"]\n\turl = git@example.com:foo/bar.git\n'
        )
        assert.equal(
            "git@example.com:foo/bar.git",
            Git.get_origin(repo("git/r6"))
        )
    end)

    it("get_tags() lists both loose and packed tag refs", function()
        Helpers.fs_create({ "git/r7/.git/refs/tags/v1.0.0" })
        Helpers.fs_write(
            "git/r7/.git/packed-refs",
            "ccc333 refs/tags/v2.0.0\n"
        )
        local tags = Git.get_tags(repo("git/r7"))
        table.sort(tags)
        assert.same({ "v1.0.0", "v2.0.0" }, tags)
    end)

    it("get_versions() filters and tags matching semver entries", function()
        Helpers.fs_create({
            "git/r8/.git/refs/tags/v1.0.0",
            "git/r8/.git/refs/tags/v1.5.0",
            "git/r8/.git/refs/tags/v2.0.0",
            "git/r8/.git/refs/tags/not-a-version",
        })
        local versions = Git.get_versions(repo("git/r8"), "^1.0.0")
        local tags     = vim.tbl_map(function(v)
            return v.tag
        end, versions)
        table.sort(tags)
        assert.same({ "v1.0.0", "v1.5.0" }, tags)
    end)

    it("info() resolves a branch HEAD to {branch, commit}", function()
        Helpers.fs_write("git/r9/.git/HEAD", "ref: refs/heads/main\n")
        Helpers.fs_write("git/r9/.git/refs/heads/main", "abc1230000\n")
        assert.same(
            { branch = "main", commit = "abc1230000" },
            Git.info(repo("git/r9"))
        )
    end)

    it("info() resolves a detached HEAD to a bare commit", function()
        Helpers.fs_write("git/r10/.git/HEAD", "deadbeefcafe\n")
        assert.same({ commit = "deadbeefcafe" }, Git.info(repo("git/r10")))
    end)

    it("eq() compares the first 7 characters of two commits", function()
        assert(Git.eq({ commit = "abcdefg1111" }, { commit = "abcdefg2222" }))
        assert(not Git.eq({ commit = "abcdefg1111" }, { commit = "zzzzzzz" }))
    end)

    it(
        "get_branch() prefers plugin.branch over the resolved default branch",
        function()
            assert.equal(
                "explicit",
                Git.get_branch(
                    Helpers.plugin({
                        branch = "explicit",
                        dir = repo("git/r11"),
                    })
                )
            )
        end
    )

    it(
        "get_branch() falls back to origin's default branch, then local HEAD",
        function()
            Helpers.fs_write(
                "git/r12/.git/refs/remotes/origin/HEAD",
                "ref: refs/remotes/origin/develop\n"
            )
            assert.equal(
                "develop",
                Git.get_branch(Helpers.plugin({ dir = repo("git/r12") }))
            )

            Helpers.fs_write("git/r13/.git/HEAD", "ref: refs/heads/main\n")
            assert.equal(
                "main",
                Git.get_branch(Helpers.plugin({ dir = repo("git/r13") }))
            )
        end
    )

    it("get_commit() prefers the origin ref, falling back to local", function()
        Helpers.fs_write(
            "git/r14/.git/refs/remotes/origin/main",
            "origin-commit\n"
        )
        Helpers.fs_write("git/r14/.git/refs/heads/main", "local-commit\n")
        assert.equal(
            "origin-commit",
            Git.get_commit(repo("git/r14"), "main", true)
        )
        assert.equal(
            "local-commit",
            Git.get_commit(repo("git/r14"), "main", false)
        )
    end)

    describe("get_target()", function()
        local restore_config
        before_each(function()
            restore_config = Mocks.patch_config({
                defaults = { version = false },
            })
        end)
        -- MiniTest.finally() drains at the end of the *step* it was called
        -- from, so a restore registered inside before_each would already be
        -- undone before the test body runs; after_each is the hook that
        -- actually runs after the test body.
        after_each(function()
            restore_config()
        end)

        it("returns the pinned commit when plugin.commit is set", function()
            Helpers.fs_write("git/t1/.git/HEAD", "ref: refs/heads/main\n")
            local target = Git.get_target(
                Helpers.plugin({
                    dir = repo("git/t1"),
                    commit = "pinned-commit",
                })
            )
            assert.same(
                { branch = "main", commit = "pinned-commit" },
                target
            )
        end)

        it("resolves a pinned tag via M.ref", function()
            Helpers.fs_write("git/t2/.git/HEAD", "ref: refs/heads/main\n")
            Helpers.fs_create({ "git/t2/.git/refs/tags/v1.0.0" })
            local restore_process = Mocks.stub_process({
                ["git show-ref -d tags/v1.0.0"] = {
                    lines = { "deadbeef01 refs/tags/v1.0.0" },
                },
            })
            MiniTest.finally(restore_process)

            local target = Git.get_target(
                Helpers.plugin({
                    dir = repo("git/t2"),
                    tag = "v1.0.0",
                })
            )
            assert.same({
                branch = "main",
                tag = "v1.0.0",
                commit = "deadbeef01",
            }, target)
        end)

        it(
            "falls back to the branch head when there is no commit, tag or version",
            function()
                Helpers.fs_write("git/t3/.git/HEAD", "ref: refs/heads/main\n")
                Helpers.fs_write(
                    "git/t3/.git/refs/remotes/origin/main",
                    "branch-commit\n"
                )
                local target = Git.get_target(
                    Helpers.plugin({ dir = repo("git/t3") })
                )
                assert.same(
                    { branch = "main", commit = "branch-commit" },
                    target
                )
            end
        )
    end)

    it("get_tag_refs() parses `git show-ref -d` output", function()
        local restore = Mocks.stub_process({
            ["git show-ref -d --tags"] = {
                lines = {
                    "aaa111 refs/tags/v1.0.0",
                    "bbb222 refs/tags/v1.0.0^{}",
                    "ccc333 refs/tags/v2.0.0",
                },
            },
        })
        MiniTest.finally(restore)

        local tags = Git.get_tag_refs(repo("git/r15"))
        assert.same({
            ["v1.0.0"] = "bbb222",
            ["v2.0.0"] = "ccc333",
        }, tags)
    end)

    it("count() and age() shell out and parse a single line", function()
        local restore = Mocks.stub_process({
            ["git rev-list --count aaa..bbb"] = { lines = { "5" } },
            ["git show -s --format=%cr --date=short bbb"] = {
                lines = { "2 days ago" },
            },
        })
        MiniTest.finally(restore)

        assert.equal(5, Git.count(repo("git/r16"), "aaa", "bbb"))
        assert.equal("2 days ago", Git.age(repo("git/r16"), "bbb"))
    end)
end)
