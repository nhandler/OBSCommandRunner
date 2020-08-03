-- OBS Command Runner
-- By Nathan Handler <nathan.handler@gmail.com>

-- Copyright 2020 Nathan Handler <nathan.handler@gmail.com>

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

obs = obslua

source_name = ""
command = ""
refresh = 300000

output = ""
previous_output = ""

function script_properties()
    local properties = obs.obs_properties_create()

    local property_list = obs.obs_properties_add_list(properties, "source_name", "Text Source (In Scene)", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
            source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_ft2_source_v2" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(property_list, name, name)
			end
		end
	end
	obs.source_list_release(sources)

    obs.obs_properties_add_text(properties, "command", "Command to execute", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_int(properties, "refresh", "Refresh Interval (ms)", 0, 36000000, 1)
	return properties
end

function script_defaults(settings)
    obs.obs_data_set_default_string(settings, "command", "/bin/cat /usr/share/dict/words | /usr/bin/sort -R | /usr/bin/head | /usr/bin/paste -s -d' ' -")
    obs.obs_data_set_default_int(settings, "refresh", 300000)
end

function script_description()
    local description = [[
    OBS Command Runner

    Executes an arbitrary shell command at a specific refresh interval.
    Output is displayed in a Text Source

    Author: Nathan Handler <nathan.handler@gmail.com>
    ]]
	return description
end

function script_update(settings)
	source_name = obs.obs_data_get_string(settings, "source_name")
    command = obs.obs_data_get_string(settings, "command")
    refresh = obs.obs_data_get_int(settings, "refresh")
end

function os.capture(cmd)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return s
end

function run_command()
    obs.script_log(obs.LOG_INFO, "Executing command: " .. command)
    output = os.capture(command)
    obs.script_log(obs.LOG_INFO, "Output: " .. output)
    set_source_text()
end

function set_source_text()
    if output ~= previous_output then
        local source = obs.obs_get_source_by_name(source_name)
        if source ~= nil then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "text", output)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end
    previous_output = output
end

function source_is_active(source_name_query)
    local sources = obs.obs_enum_sources()
    local source = find_source_by_name_in_list(sources, source_name_query)
    local is_active = obs.obs_source_active(source)
    obs.source_list_release(sources)
    return is_active
end

function timer_callback()
    if not source_is_active(source_name) then
        return
    end
    run_command()
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		run_command()
		obs.timer_add(timer_callback, refresh)
	else
		obs.timer_remove(timer_callback)
	end
end

function activate_signal(call_data, activating)
	local source = obs.calldata_source(call_data, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(call_data)
	activate_signal(call_data, true)
end

function source_deactivated(call_data)
	activate_signal(call_data, false)
end

function script_load(settings)
	local signal_handler = obs.obs_get_signal_handler()
	obs.signal_handler_connect(signal_handler, "source_activate", source_activated)
	obs.signal_handler_connect(signal_handler, "source_deactivate", source_deactivated)
end
