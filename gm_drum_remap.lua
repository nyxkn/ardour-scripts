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
GM_MIN = 36
GM_MAX = 59

function dsp_ioconfig ()
    return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end


function dsp_params ()

    local map_scalepoints = {}
    map_scalepoints["None"] = INVALID_NOTE
    for note=0,127 do
        local name = ARDOUR.ParameterDescriptor.midi_note_name(note)
        map_scalepoints[string.format("%03d - %s", note, name)] = note
    end

    local map_params = {}

    for i = GM_MIN, GM_MAX do
        -- From and to
        table.insert(map_params, {
            ["type"] = "input",
            name = ARDOUR.ParameterDescriptor.midi_note_name(i) .. " to note:",
            min = -1,
            max = 127,
            default = INVALID_NOTE,
            integer = true,
            enum = true,
            scalepoints = map_scalepoints})

        -- map_params[note_id] = {
        table.insert(map_params, {
            ["type"] = "input",
            name = "__ to channel",
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
    for i=1, (GM_MAX - GM_MIN) do
        if not (ctrl[i] == INVALID_NOTE) then
            translation_table[i - 1 + GM_MIN] = {ctrl[i+1], ctrl[i]}
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
                end
            end

            tx_midi (time, data)
        else
            tx_midi (time, data)
        end
    end
end
