ardour {
    ["type"]    = "dsp",
    name        = "MIDI Note/Channel Remap",
    category    = "Utility",
    license     = "MIT",
    author      = "nyxkn",
    description = [[Remap MIDI notes to any other note and channel. Affects Note On/Off and polyphonic key pressure. Note that if a single note is mapped multiple times, the last mapping wins (MIDI events are never duplicated).]]
}

-- The number of remapping pairs to allow. Increasing this (at least in theory)
-- decreases performance, so it's set fairly low as a default. The user can
-- increase this if they have a need to.
-- 8 looks nice and keeps the UI on a single column.
N_REMAPPINGS = 8

INVALID_NOTE = -1

function dsp_ioconfig ()
    return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end


function dsp_params ()

    local map_scalepoints = {}
    map_scalepoints["None"] = INVALID_NOTE
    for note=0,127 do
        local name = ARDOUR.ParameterDescriptor.midi_note_name(note)
        map_scalepoints[string.format("%03d (%s)", note, name)] = note
    end

    local map_params = {}

    i = 1
    for mapnum = 1,N_REMAPPINGS do
        -- From and to
        for _,name in pairs({
                "#" .. mapnum .. "  Map note",
                "__ to note",}) do
            map_params[i] = {
                ["type"] = "input",
                name = name,
                min = -1,
                max = 127,
                default = INVALID_NOTE,
                integer = true,
                enum = true,
                scalepoints = map_scalepoints
            }
            i = i + 1
        end

        map_params[i] = {
            ["type"] = "input",
            name = "__ to channel",
            min = 1,
            max = 16,
            default = 1,
            integer = true,
        }
        i = i + 1
    end

    return map_params
end

function dsp_run (_, _, n_samples)
    assert (type(midiin) == "table")
    assert (type(midiout) == "table")
    local cnt = 1;

    function tx_midi (time, data)
        midiout[cnt] = {}
        midiout[cnt]["time"] = time;
        midiout[cnt]["data"] = data;
        cnt = cnt + 1;
    end

    -- We build the translation table every buffer because, as far as I can tell,
    -- there's no way to only rebuild it when the parameters have changed.
    -- As a result, it has to be updated every buffer for the parameters to have
    -- any effect.

    -- Restore translation table
    local translation_table = {}
    local ctrl = CtrlPorts:array()
    for i=1, N_REMAPPINGS*3, 3 do
        if not (ctrl[i] == INVALID_NOTE) then
            translation_table[ctrl[i]] = {ctrl[i+2], ctrl[i+1]}
        end
    end

    -- for each incoming midi event
    for _,b in pairs (midiin) do
        local time = b["time"] -- time = [ 1 .. n_samples ]
        local data = b["data"] -- get midi-event
        -- data[1] is the midi message (binary: eeeennnn) e=eventtype, n=channelnumber
        -- data[2] is the payload. e.g. note value for note events
        local event_type
        if #data == 0 then event_type = -1 else event_type = data[1] >> 4 end

        if (#data == 3) and (event_type == 9 or event_type == 8 or event_type == 10) then -- note on, note off, poly. afterpressure
            local t = translation_table[data[2]]
            local new_note = nil
            if type(t) == "table" and #t == 2 then
                new_channel = t[1] - 1
                new_note = t[2]
                data[2] = new_note
                data[1] = data[1] | new_channel
            end

            -- it's not possible for note to be invalid at this point
            -- if not (data[2] == INVALID_NOTE) then
            --     tx_midi (time, data)
            -- end
            tx_midi (time, data)
        else
            tx_midi (time, data)
        end
    end
end
