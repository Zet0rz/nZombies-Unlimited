
-- Overwrite this later if you wish
function nzu.IsAdmin(ply) return ply:IsAdmin() end

function nzu.HasPermission(ply, perm)
	if nzu.IsAdmin(ply) then return true end
	local hook_val = hook.Run("nzu_HasPermission", ply, perm)
	if hook_val ~= nil then return hook_val end
	return false
end