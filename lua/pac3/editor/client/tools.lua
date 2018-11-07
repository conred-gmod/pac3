local L = pace.LanguageString
pace.Tools = {}

function pace.AddToolsToMenu(menu)
	menu.GetDeleteSelf = function() return false end
	for key, data in pairs(pace.Tools) do
		if #data.suboptions > 0 then
			local menu = menu:AddSubMenu(L(data.name))
			menu.GetDeleteSelf = function() return false end
			for key, option in pairs(data.suboptions) do
				menu:AddOption(option, function()
					if pace.current_part:IsValid() then
						data.callback(pace.current_part, key)
					end
				end)
			end
		else
			menu:AddOption(L(data.name), function()
				if pace.current_part:IsValid() then
					data.callback(pace.current_part)
				end
			end)
		end
	end
end

function pace.AddTool(name, callback, ...)
	for i,v in pairs(pace.Tools) do
		if v.name == name then
			table.remove(pace.Tools, i)
		end
	end

	table.insert(pace.Tools, {name = name, callback = callback, suboptions = {...}})
end

pace.AddTool(L"fix origin", function(part, suboption)
	if part.ClassName ~= "model" then return end

	local ent = part:GetEntity()

	part:SetPositionOffset(part:GetPositionOffset() + -ent:OBBCenter() * part.Scale * part.Size)
end)

pace.AddTool(L"replace ogg with webaudio", function(part, suboption)
	for _, part in pairs(pac.GetLocalParts()) do
		if part.ClassName == "ogg" then
			local parent = part:GetParent()

			local audio = pac.CreatePart("webaudio")
			audio:SetParent(parent)

			audio:SetURL(part:GetURL())
			audio:SetVolume(part:GetVolume())
			audio:SetPitch(part:GetPitch())
			audio:SetStopOnHide(not part:GetStopOnHide())
			audio:SetPauseOnHide(part:GetPauseOnHide())

			for k,v in ipairs(part:GetChildren()) do
				v:SetParent(audio)
			end

			part:Remove()
		end
	end
end)

pace.AddTool(L"copy global id", function(obj)
	SetClipboardText("\"" .. obj.UniqueID .. "\"")
end)

pace.AddTool(L"use legacy scale", function(part, suboption)
	for _, part in pairs(pac.GetLocalParts()) do
		if part.UseLegacyScale ~= nil then
			part:SetUseLegacyScale(suboption == 1)
		end
	end
end, L"true", L"false")

pace.AddTool(L"scale this and children", function(part, suboption)
	Derma_StringRequest(L"scale", L"input the scale multiplier (does not work well with bones)", "1", function(scale)
		scale = tonumber(scale)

		if scale and part:IsValid() then
			local function scale_parts(part, scale)
				if part.SetPosition then
					part:SetPosition(part:GetPosition() * scale)
					part:SetPositionOffset(part:GetPositionOffset() * scale)
				end

				if part.SetSize then
					part:SetSize(part:GetSize() * scale)
				end

				for _, part in ipairs(part:GetChildren()) do
					scale_parts(part, scale)
				end
			end

			scale_parts(part, scale)
		end
	end)
end)

pace.AddTool(L"free children from part" ,function(part, suboption)
	if part:IsValid() then
		local grandparent = part:GetParent()
		local parent = part
		for _, child in ipairs(parent:GetChildren()) do
				child:SetAngles(child.Angles + parent.Angles)
				child:SetPosition(child.Position + parent.Position)
				child:SetAngleOffset(child.AngleOffset + parent.AngleOffset)
				child:SetPositionOffset(child.PositionOffset + parent.PositionOffset)
				child:SetParent(grandparent)
		end
	end
end)

pace.AddTool(L"square model scales...", function(part, suboption)
	Derma_StringRequest(L"model", L"input the model name that should get squared", "default.mdl", function(model)
		for _, part in pairs(pac.GetLocalParts()) do
			if part:IsValid() and part.GetModel then
				local function square_scale(part)
					if part.SetSize then
						part:SetSize(part:GetSize() * part:GetSize())
					end

					if part.SetScale then
						part:SetScale(part:GetScale() * part:GetScale())
					end
				end
				if string.find(part:GetModel(),model) then
					square_scale(part)
				end
			end
		end
	end)
end)

pace.AddTool(L"show only with active weapon", function(part, suboption)
	local event = part:CreatePart("event")
	local owner = part:GetOwner(true)
	if not owner.GetActiveWeapon or not owner:GetActiveWeapon():IsValid() then
		owner = pac.LocalPlayer
	end

	local class_name = owner:GetActiveWeapon():GetClass()

	event:SetEvent("weapon_class")
	event:SetOperator("equal")
	event:SetInvert(true)
	event:SetRootOwner(true)

	event:ParseArguments(class_name, suboption == 1)

end, L"hide weapon", L"show weapon")

pace.AddTool(L"import editor tool from file...", function()
	local allowcslua = GetConVar("sv_allowcslua")
	if allowcslua:GetBool() then
		Derma_StringRequest(L"filename", L"relative to garrysmod/data/pac3_editor/tools/", "mytool.txt", function(toolfile)
			if file.Exists("pac3_editor/tools/" .. toolfile,"DATA") then
				local toolstr = file.Read("pac3_editor/tools/" .. toolfile,"DATA")
				ctoolstr = [[pace.AddTool(L"]] .. toolfile .. [[", function(part, suboption) ]] .. toolstr .. " end)"
				RunStringEx(ctoolstr, "pac_editor_import_tool")
				LocalPlayer():ConCommand("pac_editor") --close and reopen editor
			else
				Derma_Message("File " .. "garrysmod/data/pac3_editor/tools/" .. toolfile .. " not found.","Error: File Not Found","OK")
			end
		end)
	else
		Derma_Message("Importing pac editor tools is disallowed on this server.","Error: Clientside Lua Disabled","OK")
	end
end)

pace.AddTool(L"import editor tool from url...", function()
	if GetConVar("sv_allowcslua"):GetBool() then
		Derma_StringRequest(L"URL", L"URL to PAC Editor tool txt file", "http://www.example.com/tool.txt", function(toolurl)
			function ToolDLSuccess(body)
				local toolname = pac.PrettifyName(toolurl:match(".+/(.-)%."))
				local toolstr = body
				ctoolstr = [[pace.AddTool(L"]] .. toolname .. [[", function(part, suboption)]] .. toolstr .. " end)"
				RunStringEx(ctoolstr, "pac_editor_import_tool")
				LocalPlayer():ConCommand("pac_editor") --close and reopen editor
			end

			pac.HTTPGet(toolurl,ToolDLSuccess,function(err)
				Derma_Message("HTTP Request Failed for " .. toolurl,err,"OK")
			end)
		end)
	else
		Derma_Message("Importing pac editor tools is disallowed on this server.","Error: Clientside Lua Disabled","OK")
	end
end)

function round_pretty(val)
	return math.Round(val, 2)
end

pace.AddTool(L"round numbers", function(part)
	local function ify_parts(part)
		for _, key in pairs(part:GetStorableVars()) do
			local val = part["Get" .. key](part)

			if type(val) == "number" then
				part["Set" .. key](part, round_pretty(val))
			elseif type(val) == "Vector" then
				part["Set" .. key](part, Vector(round_pretty(val.x), round_pretty(val.y), round_pretty(val.z)))
			elseif type(val) == "Angle" then
				part["Set" .. key](part, Angle(round_pretty(val.p), round_pretty(val.y), round_pretty(val.r)))
			end
		end

		for _, part in ipairs(part:GetChildren()) do
			ify_parts(part)
		end
	end

	ify_parts(part)
end)

do

	local function fix_name(str)
		str = str:lower()
		str = str:gsub("_", " ")
		return str
	end

	local hue =
	{
		"red",
		"orange",
		"yellow",
		"green",
		"turquoise",
		"blue",
		"purple",
		"magenta",
	}

	local sat =
	{
		"pale",
		"",
		"strong",
	}

	local val =
	{
		"dark",
		"",
		"bright"
	}

	local function HSVToNames(h,s,v)
		return
			hue[math.Round(1 + (h / 360) * #hue)] or hue[1],
			sat[math.ceil(s * #sat)] or sat[1],
			val[math.ceil(v * #val)] or val[1]
	end

	local function ColorToNames(c)
		return HSVToNames(ColorToHSV(Color(c.r, c.g, c.b)))
	end

	pace.AddTool(L"clear names", function(part, suboptions)
		for k,v in pairs(pac.GetLocalParts()) do
			v:SetName("")
		end
		pace.RefreshTree(true)
	end)

end

pace.AddTool(L"Convert group of models to Expression 2 holograms", function(part)

	local str_ref =
	[[

    I++, HN++, HT[HN,table] = table(I, Base, Base, 0, POSITION, ANGLES, SCALE, MODEL, MATERIAL, vec4(COLOR, ALPHA), SKIN)
	]]

	local str_header =
	[[
@name [NAME]
#-- Entity input directives
@inputs [Base]:entity
#-- Spawning code directives
@persist [HT CT]:table [SpawnStatus CoreStatus]:string [HN CN I SpawnCounter]
@persist [ScaleFactor ToggleColMat ToggleShading] Indices
@persist [DefaultColor DefaultScale]:vector
#-- Hologram index directives
@persist []

if (first() | dupefinished()) {
    Chip = entity()

    Indices = 1
    ScaleFactor = 1
    ToggleColMat = 1
    ToggleShading = 0

	   #-- Data structure
	   #-- HN++, HT[HN, table] = table(Index, Local Entity (Entity:toWorld()), Parent Entity, ScaleType (Default 0), Pos, Ang, Scale, Model, Material, Color, Skin)
	   #-- CN++, CT[CN, table] = table(Index, Clip Index, Pos, Ang)

	   #-- Editing holograms
	   #-- Scroll down to the bottom of the code to find where to insert your holo() code. In order to reference indexes
	   #-- add a ", I_HologramName"" to the end of that holograms data line with "HologramName" being of your choosing.
	   #-- Finally add this to a @persist directive eg "@persist [I_HologramName]", now you can address this in your holo() code.
	   #-- For example, "holoBodygroup(I_HologramName, 2, 3)" which would be put in the "InitPostSpawn" section.

	   # # # # # # # # # HOLOGRAM DATA START # # # # # # # # #
	]]

	local str_footer =
	[[

	   # # # # # # # # # HOLOGRAM DATA END # # # # # # # # #

	   #-- Create a hologram from data array
    function table:holo() {
        local Index = This[1, number] * Indices
        if (This[2,entity]:isValid()) { Entity = This[2,entity] } else { Entity = holoEntity(This[2,number]) }
        if (This[3,entity]:isValid()) { Parent = This[3,entity] } else { Parent = holoEntity(This[3,number]) }
        local Rescale = (This[7, vector] / (This[4, number] ? 12 : 1)) * ScaleFactor

        holoCreate(Index, Entity:toWorld(This[5, vector] * ScaleFactor), Rescale, Entity:toWorld(This[6, angle]), DefaultColor, This[8, string] ?: "cube")
        holoParent(Index, Parent)

        if (ToggleColMat) {
            holoMaterial(Index, This[9, string])
            holoColor(Index, This[10, vector4])
            holoSkin(Index, This[11, number])
        }

        if (ToggleShading) { holoDisableShading(Index, 1) }
    }

    #-- Clip a hologram from data array
    function table:clip() {
        holoClipEnabled(This[1, number] * Indices, This[2, number], 1)
        holoClip(This[1, number] * Indices, This[2, number], This[3, vector] * ScaleFactor, This[4, vector], 0)
    }

    #-- Load the contraption
    function loadContraption() {
        switch (SpawnStatus) {
            case "InitSpawn",
                if (clk("Start")) {
                    SpawnStatus = "LoadHolograms"
                }
                Chip:soundPlay("Blip", 0, "@^garrysmod/content_downloaded.wav", 0.212)
            break

            case "LoadHolograms",
                while (perf() & holoCanCreate() &  SpawnCounter < HN) {
                    SpawnCounter++
                    HT[SpawnCounter, table]:holo()

                    if (SpawnCounter >= HN) {
                        SpawnStatus = CN > 0 ? "LoadClips" : "PrintStatus"
                        SpawnCounter = 0
                        break
                    }
                }
            break

            case "LoadClips",
                while (perf() & SpawnCounter < CN) {
                    SpawnCounter++
                    CT[SpawnCounter, table]:clip()

                    if (SpawnCounter >= CN) {
                        SpawnStatus = "PrintStatus"
                        SpawnCounter = 0
                        break
                    }
                }
            break

            case "PrintStatus",
                printColor( vec(222,37,188), "PAC to Holo: ", vec(255,255,255), "Loaded " + HN + " holograms and " + CN + " clips." )

                HT:clear()
                CT:clear()

                CoreStatus = "InitPostSpawn"
                SpawnStatus = ""
            break
        }
    }

    CoreStatus = "InitSpawn"
    SpawnStatus = "InitSpawn"

    DefaultColor = vec(255, 255, 255)

    runOnTick(1)
    timer("Start", 500)
}

#-- Credit to Shadowscion for the initial base hologram spawning code.

elseif (CoreStatus == "InitSpawn") {
    loadContraption()
}
elseif (CoreStatus == "InitPostSpawn") {
    #-- This is your "if (first())" section of the code.

    CoreStatus = "RunThisCode"
}
elseif (CoreStatus == "RunThisCode") {
    #-- This is your "interval()" ran section of the code.

    runOnTick(0)
}
	]]

	local function tovec(vec) return ("%s, %s, %s"):format(math.Round(vec.x, 4), math.Round(vec.y, 4), math.Round(vec.z, 4)) end
	local function toang(vec) return ("%s, %s, %s"):format(math.Round(vec.p, 4), math.Round(vec.y, 4), math.Round(vec.r, 4)) end

	local function part_to_holo(part)
		local str_holo = str_ref

		for CI, clip in ipairs(part:GetChildren()) do
			if clip.ClassName == "clip" and not clip:IsHidden() then
				local pos, ang = clip.Position, clip:CalcAngles(clip.Angles)
				local normal = ang:Forward()
				str_holo = str_holo .. "    CN++, CT[CN,table] = table(I, " .. CI .. ", vec(" .. tovec(pos + normal) .. "), vec(" .. tovec(normal) .. "))\n"
			end
		end

		local scale = part:GetSize() * part:GetScale()

		local holo = str_holo
		:gsub("ALPHA", part:GetAlpha() * 255)
		:gsub("COLOR", tovec(part:GetColor()))
		:gsub("SCALE", "vec(" .. tovec(Vector(scale.x, scale.y, scale.z)) .. ")")
		:gsub("ANGLES", "ang(" .. toang(part:GetAngles()) .. ")")
		:gsub("POSITION", "vec(" .. tovec(part:GetPosition()) .. ")")
		:gsub("MATERIAL", ("%q"):format(part:GetMaterial()))
		:gsub("MODEL", ("%q"):format(part:GetModel()))
		:gsub("SKIN", part:GetSkin())
		:gsub("PARENT", "entity()")

		return holo
	end

	local function convert(part)
		local out = string.Replace(str_header, "[NAME]", part:GetName() or "savedpacholos")

		for key, part in ipairs(part:GetChildren()) do
			if part.is_model_part and not part:IsHidden() and not part.wavefront_mesh then
				out = out .. part_to_holo(part)
			end
		end

		out = out .. str_footer

		LocalPlayer():ChatPrint("PAC --> Code saved in your Expression 2 folder under [expression2/pac/" .. part:GetName() .. ".txt" .. "].")

		return out
	end

	file.CreateDir("expression2/pac")
	file.Write("expression2/pac/" .. part:GetName() .. ".txt", convert(part))
end)

pace.AddTool(L"record surrounding props to pac", function(part)
	local base = pac.CreatePart("group")
	base:SetName("recorded props")

	local origin = base:CreatePart("model")
	origin:SetName("origin")
	origin:SetBone("none")
	origin:SetModel("models/dav0r/hoverball.mdl")

	for key, ent in pairs(ents.FindInSphere(pac.EyePos, 1000)) do
		if
			not ent:IsPlayer() and
			not ent:IsNPC() and
			not ent:GetOwner():IsPlayer()
		then
			local mdl = origin:CreatePart("model")
			mdl:SetModel(ent:GetModel())

			local lpos, lang = WorldToLocal(ent:GetPos(), ent:GetAngles(), pac.EyePos, pac.EyeAng)

			mdl:SetMaterial(ent:GetMaterial())
			mdl:SetPosition(lpos)
			mdl:SetAngles(lang)
			local c = ent:GetColor()
			mdl:SetColor(Vector(c.r,c.g,c.b))
			mdl:SetAlpha(c.a / 255)
			mdl:SetName(ent:GetModel():match(".+/(.-)%.mdl"))
		end
	end
end)

pace.AddTool(L"populate with bones", function(part,suboption)
	local target = part.GetEntity or part.GetOwner
	local ent = target(part)
	local bones = pac.GetModelBones(ent)

	for bone,tbl in pairs(bones) do
		if not tbl.is_special then
			local child = pac.CreatePart("bone")
			child:SetParent(part)
			child:SetBone(bone)
		end
	end

	pace.RefreshTree(true)
end)

pace.AddTool(L"populate with dummy bones", function(part,suboption)
	local target = part.GetEntity or part.GetOwner
	local ent = target(part)
	local bones = pac.GetModelBones(ent)

	for bone,tbl in pairs(bones) do
		if not tbl.is_special then
			local child = pac.CreatePart("model")
			child:SetParent(part)
			child:SetName(bone .. "_dummy")
			child:SetBone(bone)
			child:SetScale(Vector(0,0,0))
		end
	end

	pace.RefreshTree(true)
end)

pace.AddTool(L"print part info", function(part)
	PrintTable(part:ToTable())
end)

pace.AddTool(L"dump player submaterials", function()
	local ply = LocalPlayer()
	for id,mat in pairs(ply:GetMaterials()) do
		chat.AddText(("%d %s"):format(id,tostring(mat)))
	end
end)

pace.AddTool(L"stop all custom animations", function()
	boneanimlib.StopAllEntityAnimations(LocalPlayer())
	boneanimlib.ResetEntityBoneMatrix(LocalPlayer())
end)

pace.AddTool(L"copy from faceposer tool", function(part, suboption)
	local group = pac.CreatePart("group")
	local ent = LocalPlayer()

	for i = 0, ent:GetFlexNum() - 1 do
		local name = ent:GetFlexName(i)
		local fp_flex = GetConVar("faceposer_flex" .. i):GetFloat()
		local fp_scale = GetConVar("faceposer_scale"):GetFloat()
		local weight = fp_flex * fp_scale
		pac.Message(name, weight)
		if weight ~= 0 then
			local flex = group:CreatePart("flex")
			flex:SetFlex(name)
			flex:SetWeight(weight)
		end
	end
end)
