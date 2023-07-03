ardour {
    ["type"]    = "dsp",
    name        = "GM MIDI Drum Note/Channel Remap",
    category    = "Utility",
    license     = "MIT",
    author      = "nyxkn",
    description = [[Remap the GM drums map to any other note and channel. Affects Note On/Off and polyphonic key pressure. Note that if a single note is mapped multiple times, the last mapping wins (MIDI events are never duplicated).]]
}

-- The number of remapping pairs to allow. Increasing this (at least in theory)
-- decreases performance, so it's set fairly low as a default. The user can
-- increase this if they have a need to.
-- 8 looks nice and keeps the UI on a single column.
N_REMAPPINGS = 8

INVALID_NOTE = -1
SAME_NOTE = -2

-- range of notes that we want to remap
-- note that you only have 16 midi channels so you can't send more than 16 notes to its own channel
GM_MIN = 36
GM_MAX = 59

-- range of note remap choice. a smaller range makes the dropdown menu easier to navigate
-- use 0,127 for any note
-- 21,108 for piano range
MIDI_MIN = 21
MIDI_MAX = 108

function dsp_ioconfig ()
    return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end


function dsp_params ()

    local map_scalepoints = {}
    map_scalepoints["Same"] = SAME_NOTE
    map_scalepoints["Off"] = INVALID_NOTE
    for note=MIDI_MIN,MIDI_MAX do -- piano range
        local name = ARDOUR.ParameterDescriptor.midi_note_name(note)
        map_scalepoints[string.format("%03d - %s", note, name)] = note
    end

    local map_params = {}

    for i = GM_MIN, GM_MAX do
        -- From and to
        table.insert(map_params, {
            ["type"] = "input",
            name = string.format("%-4s", ARDOUR.ParameterDescriptor.midi_note_name(i)) .. " to note:",
            min = -2,
            max = 127,
            default = INVALID_NOTE,
            integer = true,
            enum = true,
            scalepoints = map_scalepoints})

        table.insert(map_params, {
            ["type"] = "input",
            -- need two spaces to show one
            name = "      _ to channel:",
            min = 1,
            max = 16,
            default = 1,
            integer = true,})
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
    -- for i=1, N_REMAPPINGS*2, 2 do
    local ctrl_itr = 1
    for i=GM_MIN, GM_MAX do
        if (ctrl[ctrl_itr] == INVALID_NOTE) then
            -- do nothing. emtpy table actually not required
            translation_table[i] = {}
        elseif (ctrl[ctrl_itr] == SAME_NOTE) then
            -- change channel but keep same note
            translation_table[i] = {ctrl[ctrl_itr+1], i}
        else
            -- change both note and channel
            translation_table[i] = {ctrl[ctrl_itr+1], ctrl[ctrl_itr]}
        end

        ctrl_itr = ctrl_itr + 2
    end

    -- for each incoming midi event
    for _,b in pairs (midiin) do
        local time = b["time"] -- time = [ 1 .. n_samples ]
        local data = b["data"] -- get midi-event
        -- data[1] is the midi message (binary: eeeennnn) e=eventtype, n=channelnumber
        -- data[2] is the payload. e.g. note value for note events
        local event_type
        if #data == 0 then event_type = -1 else event_type = data[1] >> 4 end

        -- note on, note off, poly. afterpressure
        if (#data == 3) and (event_type == 9 or event_type == 8 or event_type == 10) then

            if data[2] >= GM_MIN and data[2] <= GM_MAX then
                local t = translation_table[data[2]]
                local new_note = nil
                if type(t) == "table" and #t == 2 then
                    new_channel = t[1] - 1
                    new_note = t[2]
                    data[2] = new_note
                    data[1] = data[1] | new_channel
                    -- we only send the message if we have a translation
                    -- otherwise the note is blocked
                    tx_midi (time, data)
                end
            else
                -- block if outside of our gm range
                -- tx_midi (time, data)
            end
        else
            -- pass through all other non-note events
            tx_midi (time, data)
        end
    end
end
