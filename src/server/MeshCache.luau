-- Mesh fetches, shared and all at once (load time, owner 2026-10-27: "make the loading more
-- optimized and less long"). The boot rebuilt every Creator Store mesh by id one fetch after another
-- (a ranking-wall lantern alone fetched the same mesh 8 times), ~3 s before the first player could
-- join a fresh server. Main calls MeshCache.prefetch first thing: every mesh id in Config is fetched
-- in parallel, and each later fetch of an id gets a clone of the one template (a fetch still running
-- is waited for, never asked twice). Same result as pcall(AssetService.CreateMeshPartAsync, ...).
local AssetService = game:GetService("AssetService")

local MeshCache = {}

local OPTIONS = {
	CollisionFidelity = Enum.CollisionFidelity.Box,
	RenderFidelity = Enum.RenderFidelity.Automatic,
}

local templates: { [string]: MeshPart } = {}
local pending: { [string]: boolean } = {}

-- ok, a fresh MeshPart (or false, the error); a failed fetch is not kept, so a retry asks again
function MeshCache.fetch(id: string): (boolean, any)
	while pending[id] do
		task.wait()
	end
	local t = templates[id]
	if t then
		return true, t:Clone()
	end
	pending[id] = true
	local ok, mp = pcall(AssetService.CreateMeshPartAsync, AssetService, id, OPTIONS)
	pending[id] = nil
	if ok and mp then
		templates[id] = mp
		return true, mp:Clone()
	end
	return false, mp
end

local function collect(t, out, seen)
	if seen[t] then
		return
	end
	seen[t] = true
	for k, v in t do
		if type(v) == "string" and v:match("^rbxassetid://%d+$") and (k == "mesh" or (type(k) == "string" and k:match("^LOWPOLY_"))) then
			out[v] = true
		elseif type(v) == "table" then
			collect(v, out, seen)
		end
	end
end

-- every mesh id in Config (fields named `mesh`, LOWPOLY_*, the *_MESH lists) plus `extra`, fetched at once
function MeshCache.prefetch(Config, extra: { string }?)
	local ids, seen = {}, {}
	collect(Config, ids, seen)
	for key, list in Config do
		if type(key) == "string" and key:match("_MESH$") and type(list) == "table" then
			for name, id in list do
				-- not the lantern texture, nor the cloud (an old FileMesh drawn as a SpecialMesh)
				if type(id) == "string" and id:match("^rbxassetid://%d+$") and name ~= "lanternTex" and name ~= "cloud" then
					ids[id] = true
				end
			end
		end
	end
	for _, id in extra or {} do
		ids[id] = true
	end
	local n = 0
	for id in ids do
		n += 1
		task.spawn(MeshCache.fetch, id)
	end
	return n
end

return MeshCache
