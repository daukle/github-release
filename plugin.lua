--- Publishes files a toolchain built as assets on a GitHub release.
---
--- @implNote core cannot upload: there is no POST or PUT behind any verb and no
--- listing verb either, which is why this runs a tool rather than speaking to
--- the API itself. The publishing spec records that as model B and measured
--- the three core gaps model A would need.
daukle.plugin{ api = 1, uses = { "exec", "provision", "env" },
              env = { "DAUKLE_TOKEN", "GITHUB_TOKEN" } }

local gh = daukle.require("lib/gh")

local KEYS = { "repo", "tokenEnv", "tag", "files", "notes" }

local function known_keys()
  return table.concat(KEYS, ", ")
end

local function refuse_an_unknown_key(name, config)
  local allowed = {}
  for index = 1, #KEYS do allowed[KEYS[index]] = true end
  for key in pairs(config) do
    if not allowed[key] then
      error('publish.' .. name .. ' has no "' .. tostring(key) .. '". This publisher takes '
            .. known_keys(), 0)
    end
  end
end

local function required_string(name, config, key)
  local value = config[key]
  if type(value) ~= "string" or value == "" then
    error('publish.' .. name .. ' needs a "' .. key .. '"', 0)
  end
  return value
end

local function optional_string(name, config, key, fallback)
  local value = config[key]
  if value == nil then return fallback end
  if type(value) ~= "string" then
    error('publish.' .. name .. '.' .. key .. ' must be a string', 0)
  end
  return value
end

--- @implNote a function replacement so a version holding "%" is not read as a
--- capture reference, and the extra parentheses drop gsub's match count. Same
--- shape daukle/github's source plugin uses for the same substitution.
local function substitute_version(template, version)
  return (template:gsub("{version}", function() return version end))
end

local function refuse_a_repo_that_is_not_owner_name(name, repo)
  if repo:match("^[^/]+/[^/]+$") == nil then
    error('publish.' .. name .. '.repo must be "owner/name", not "' .. repo .. '". It names a'
          .. ' GitHub repository, which a daukle project id only resembles', 0)
  end
end

--[[ daukle never runs a shell, so a "*" reaches gh as a literal asterisk and it
     reports a file it cannot find. The mistake is what the shape invites, so it
     is answered here rather than by the tool. ]]
local function refuse_a_glob(name, path)
  if path:find("*", 1, true) ~= nil then
    error('publish.' .. name .. '.files holds "' .. path .. '", and there are no globs here:'
          .. ' daukle runs no shell, so spell every file and interpolate a version with'
          .. ' {version}', 0)
  end
end

local function files_of(name, config, version)
  local declared = config.files
  if type(declared) ~= "table" or #declared == 0 then
    error('publish.' .. name .. ' needs a "files" list naming at least one file to upload:'
          .. ' a release with no asset is not a publish', 0)
  end
  local files = {}
  for index = 1, #declared do
    local path = declared[index]
    if type(path) ~= "string" or path == "" then
      error('publish.' .. name .. '.files[' .. index .. '] must be a file path', 0)
    end
    refuse_a_glob(name, path)
    files[index] = substitute_version(path, version)
  end
  return files
end

local function token_of(name, config)
  local variable = optional_string(name, config, "tokenEnv", "GITHUB_TOKEN")
  local token = daukle.env(variable)
  if token == nil or token == "" then
    error('publish.' .. name .. ' reads its token from ' .. variable .. ', which is empty or'
          .. ' unset. The manifest names the VARIABLE and never a token, so set it in the'
          .. ' environment, or point "tokenEnv" at one that is set', 0)
  end
  return token
end

local function provision_gh(context)
  local pick = gh.for_host{ os = context.host.os, arch = context.host.arch }
  local root = daukle.provision{ url = pick.url, sha256 = pick.sha256,
                                 as = "gh " .. pick.version }
  return root:tool(pick.executable)
end

local function release_exists(tool, repo, tag, token)
  local probe = daukle.exec(tool, { "release", "view", tag, "--repo", repo },
                            { check = false, capture = true, env = { GH_TOKEN = token } })
  return probe.code == 0
end

--[[ Which command runs is the forge's answer and not a key: "create" fails if
     the release exists and "upload" fails if it does not, so asking the user to
     state it would be asking them for something gh already knows. --clobber
     because re-publishing the same asset is the ordinary case for a release
     that is being added to. ]]
local function publish_to_a_release(tool, repo, tag, notes, files, token)
  local options = { env = { GH_TOKEN = token } }
  if release_exists(tool, repo, tag, token) then
    local argv = { "release", "upload", tag, "--repo", repo, "--clobber" }
    for index = 1, #files do argv[#argv + 1] = files[index] end
    daukle.exec(tool, argv, options)
    return
  end
  local argv = { "release", "create", tag, "--repo", repo, "--notes", notes }
  for index = 1, #files do argv[#argv + 1] = files[index] end
  daukle.exec(tool, argv, options)
end

daukle.publisher{
  name = "github-release",
  publish = function(context)
    local name = context.publish.name
    local config = context.publish.config
    refuse_an_unknown_key(name, config)

    local repo = required_string(name, config, "repo")
    refuse_a_repo_that_is_not_owner_name(name, repo)

    local tag = substitute_version(optional_string(name, config, "tag", "{version}"),
                                   context.version)
    -- gh opens an editor when a release is created with no body, which in CI is
    -- a job that hangs rather than one that fails, so there is always a note.
    local notes = optional_string(name, config, "notes", context.project .. " " .. context.version)
    local files = files_of(name, config, context.version)
    local token = token_of(name, config)

    publish_to_a_release(provision_gh(context), repo, tag, notes, files, token)
  end,
}
