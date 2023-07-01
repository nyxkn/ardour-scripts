# Ardour Scripts

## MIDI Note/Channel Remap

Remap any MIDI note to any other note and channel.

## GM MIDI Drum Note/Channel Remap

Remap the GM standard drum notes to any other note and channel.

Same function as the previous script, but streamlined to work in only the GM Drum Map range.

This is useful if you have synthesizer drums on their own tracks and you want to play them with your
keyboard in the standard GM drums map.

### Usage

You can have a main "input" track that listens to your MIDI keyboard and sends the MIDI to all the other 
drum synth tracks. Each synth track should listen on different MIDI channels.
Then in the plugin, for example, set D2 (which is the snare in the GM drum map) to send a G3 note on a different channel, where your snare synthesizer is listening.
Do this for your other tracks as well, and you can now play all your drums on the keyboard.

