#!/usr/bin/perl
use strict;

BEGIN {
    do "AVR.pm";
    die $@ if ($@);
}

BEGIN {
    emit ".section .bss\n";

    #make the button event queue be 256 byte aligned, so we can easily use mod 256 arithmetic
    #we should already be aligned since this should be the beginning of the .bss section, so
    #this is mostly informational
    emit ".align 8\n";

    #a queue to hold the button press and release events generated by logic associated with timer3
    #The lower 6 bits of each item hold the button index, while the MSB indicates if it was a
    #press (1) or release (0) event
    #We shouldn't near this much space, but it makes the math much cheaper
    #since we get mod 256 arithmetic "for free"
    memory_variable "button_event_queue", 0x100;

    #The head and tail of the button queue
    memory_variable "button_event_head", 1;
    memory_variable "button_event_tail", 1;

    #done in begin section, so that declared constants can be accessed further down
    memory_variable "current_configuration";
    memory_variable "hid_idle_period";

    #contains the button states for each selector value
    #the button states are stored in the low nibble of each byte.
    #The high nibbles are not used
    memory_variable "button_states", 13;

    #contains the current state of the hid report
    memory_variable "current_report", 21;

    #An array with an entry for each modifier key, which contains a count of the number
    #of keys currently pressed that "virtually" press that modifier key (like the # key,
    #which is actually the 3 key with a virtual shift). If both the # and $ keys were
    #pressed the count for the lshift modifier would be 2
    memory_variable "modifier_virtual_count", 8;

    #A bitmask that specifies which modifier keys are currently being physically pressed
    #This does not take into account any modifier keys that are only being "virtually"
    #pressed (see comments for modifier_virtual_count)
    memory_variable "modifier_physical_status", 1;

    #The address of the press table for the current keyboard mode
    memory_variable "current_press_table", 2;

    #The address of the press table for the "persistent" mode - that is, the mode that we go back
    #to after a temporary mode switch (i.e. the nas button)
    memory_variable "persistent_mode_press_table", 2;

    #This contains a 2-byte entry for each button, which is the address of a routine to
    #execute when the button is released. The entry for a button is updated when the button
    #is pressed, to reflect the correct routine to use when it is released
    #In this way, we can correctly handle button releases when the mode changes while a
    #button is pressed
    memory_variable "release_table", 104;



    emit ".text\n";
}

use constant BUTTON_RELEASE => 0;
use constant BUTTON_PRESS => 1;

use constant LCTRL_OFFSET => 0;
use constant LSHIFT_OFFSET => 1;
use constant LALT_OFFSET => 2;
use constant LGUI_OFFSET => 3;
use constant RCTRL_OFFSET => 4;
use constant RSHIFT_OFFSET => 5;
use constant RALT_OFFSET => 6;
use constant RGUI_OFFSET => 7;

do "descriptors.pm";
die $@ if ($@);

do "usb.pm";
die $@ if ($@);

do "timer.pm";
die $@ if ($@);

sub dequeue_input_event;
sub process_input_event;
sub press_table_label;

emit_global_sub "main", sub {
    SET_CLOCK_SPEED r16, CLOCK_DIV_1;

    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_0, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_1, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_2, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_3, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_4, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_5, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_6, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_A, pin=>PIN_7, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);

    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_0, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_1, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_2, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_3, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_4, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_5, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_6, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_B, pin=>PIN_7, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);

    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_0, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_1, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_2, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_3, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_4, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_5, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_6, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_C, pin=>PIN_7, dir=>GPIO_DIR_OUT);

    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_0, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_1, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_2, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_3, dir=>GPIO_DIR_OUT);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_4, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_5, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_6, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_D, pin=>PIN_7, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);

    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_0, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_1, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_2, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_3, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_4, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_5, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_6, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_E, pin=>PIN_7, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);

    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_0, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_1, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_2, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_3, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_4, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_5, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_6, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);
    CONFIGURE_GPIO(port=>GPIO_PORT_F, pin=>PIN_7, dir=>GPIO_DIR_IN, pullup=>GPIO_PULLUP_ENABLED);

    #initialize register with commonly used "zero" value
    _clr r15_zero;

    _ldi zl, 0x00;
    _ldi zh, 0x01;

    #reset all memory to 0s
    block {
        _st "z+", r15_zero;

        _cpi zl, 0x00;
        _brne begin_label;

        _cpi zh, 0x21;
        _brne begin_label;
    };

    usb_init();

    #timer1_init();

    timer3_init();
    enable_timer3(r16);

    #enable interrupts
    _sei;

    #initialize the press tables
    _ldi r16, lo8(press_table_label("normal"));
    _sts current_press_table, r16;
    _sts persistent_mode_press_table, r16;

    _ldi r16, hi8(press_table_label("normal"));
    _sts "current_press_table + 1", r16;
    _sts "persistent_mode_press_table + 1", r16;

    block {
        #wait for an input event and dequeue it
        dequeue_input_event;
        #generate and send the hid report(s)
        process_input_event;

        #and do it all over again
        _rjmp begin_label;
    };
};

#Waits for an input event and dequeues it into the given register
sub dequeue_input_event {
    block {
        _cli;

        _ldi zh, hi8(button_event_queue);
        _lds zl, button_event_head;
        _lds r16, button_event_tail;

        block {
            _cp zl, r16;
            _breq end_label;

            _ld r16, "z+";
            _sts button_event_head, zl;
            _sei;
            _rjmp end_label parent;
        };

        _sei;
        _rjmp begin_label;
    };
}

sub process_input_event {
    block {
        #we've got the input event in r16

        #extract the button index and store it in r17
        _mov r17, r16;
        _cbr r17, 0x80;
        #we really only need index*2 for address offsets/lookups (which are 2 bytes each)
        _lsl r17;

        block {
            block {
                #is it a press or release?
                _sbrc r16, 7;
                _rjmp end_label;

                #it's a release event. Load the handler address from the release table
                _ldi zl, lo8(release_table);
                _ldi zh, hi8(release_table);
                _add zl, r17;
                _adc zh, r15_zero;
                _ld r18, "z+";
                _ld r19, "z";
                _movw zl, r18;

                _rjmp end_label parent;
            };

            #it's a press event. Load the address for the current press table
            _lds zl, current_press_table;
            _lds zh, "current_press_table+1";

            #lookup the handler address from the table
            _add zl, r17;
            _adc zh, r15_zero;
            _lpm r16, "z+";
            _lpm r17, "z";
            _movw zl, r16;
        };

        _icall;
    };
}

#maps a button index to it's corresponding finger+direction
my(@index_map) = (
    #selector 0x00
    ["r1", "west"],             #0x00
    ["r1", "north"],            #0x01
    ["l4", "west"],             #0x02
    ["l4", "north"],            #0x03

    #selector 0x01
    ["r1", "down"],             #0x04
    ["r1", "east"],             #0x05
    ["l4", "down"],             #0x06
    ["l4", "east"],             #0x07

    #selector 0x02
    ["r1", "south"],            #0x08
    ["r2", "south"],            #0x09
    ["l4", "south"],            #0x0a
    ["l3", "south"],            #0x0b

    #selector 0x03
    ["r2", "west"],             #0x0c
    ["r2", "north"],            #0x0d
    ["l3", "west"],             #0x0e
    ["l3", "north"],            #0x0f

    #selector 0x04
    ["r2", "down"],             #0x10
    ["r2", "east"],             #0x11
    ["l3", "down"],             #0x12
    ["l3", "east"],             #0x13

    #selector 0x05
    ["r3", "west"],             #0x14
    ["r3", "north"],            #0x15
    ["l2", "west"],             #0x16
    ["l2", "north"],            #0x17

    #selector 0x06
    ["r3", "down"],             #0x18
    ["r3", "east"],             #0x19
    ["l2", "down"],             #0x1a
    ["l2", "east"],             #0x1b

    #selector 0x07
    ["r3", "south"],            #0x1c
    ["r4", "south"],            #0x1d
    ["l2", "south"],            #0x1e
    ["l1", "south"],            #0x1f

    #selector 0x08
    ["r4", "west"],             #0x20
    ["r4", "north"],            #0x21
    ["l1", "west"],             #0x22
    ["l1", "north"],            #0x23

    #selector 0x09
    ["r4", "down"],             #0x24
    ["r4", "east"],             #0x25
    ["l1", "down"],             #0x26
    ["l1", "east"],             #0x27

    #selector 0x0a
    ["rt", "lower_outside"],    #0x28
    ["rt", "upper_outside"],    #0x29
    ["lt", "lower_outside"],    #0x2a
    ["lt", "upper_outside"],    #0x2b

    #selector 0x0b
    ["rt", "down"],             #0x2c
    ["rt", "down_down"],        #0x2d
    ["lt", "down"],             #0x2e
    ["lt", "down_down"],        #0x2f

    #selector 0x0c
    ["rt", "inside"],           #0x30
    ["rt", "up"],               #0x31
    ["lt", "inside"],           #0x32
    ["lt", "up"]                #0x33
);

sub finger_map {
    return {
        down=>shift,
        north=>shift,
        east=>shift,
        south=>shift,
        west=>shift
    };
}

sub thumb_map {
    return {
        down => shift,
        down_down => shift,
        up => shift,
        inside => shift,
        lower_outside => shift,
        upper_outside => shift
    }
}

#key map for normal mode
my(%normal_key_map) = (
    #                 d    n    e    s    w
    r1 => finger_map("h", "g", "'", "m", "d"),
    r2 => finger_map("t", "w", "`", "c", "f"),
    r3 => finger_map("n", "v", undef, "r", "b"),
    r4 => finger_map("s", "z", "\\", "l", ")"),
    #                d      dd         u       in    lo      uo
    rt => thumb_map("nas", "naslock", "func", "sp", "lalt", "bksp"),

    #                 d    n    e    s    w
    l1 => finger_map("u", "q", "i", "p", "\""),
    l2 => finger_map("e", ".", "y", "j", "`"),
    l3 => finger_map("o", ",", "x", "k", "esc"),
    l4 => finger_map("a", "/", "(", ";", "del"),
    #                d         dd          u       in     lo       uo
    lt => thumb_map("lshift", "capslock", "norm", "ret", "lctrl", "tab")
);

#key map for when the normal mode key is held down
#It's similar to normal mode, except that we add some shortcuts for
#ctrl+c, ctrl+v, ctrl+x, etc.
my(%normal_hold_key_map) = (
    #                 d    n    e    s    w
    r1 => finger_map("h", "g", "'", "m", "d"),
    r2 => finger_map("t", "w", "`", "c", "f"),
    r3 => finger_map("n", "v", undef, "r", "b"),
    r4 => finger_map("s", "z", "\\", "l", ")"),
    #                d      dd         u       in    lo      uo
    rt => thumb_map("nas", "naslock", "func", "sp", "lalt", "bksp"),

    #                 d    n    e    s    w
    l1 => finger_map("u", "q", "i", "ctrlv", "\""),
    l2 => finger_map("e", ".", "y", "ctrlc", "`"),
    l3 => finger_map("o", ",", "x", "ctrlx", "esc"),
    l4 => finger_map("a", "/", "(", ";", "del"),
    #                d         dd          u       in     lo       uo
    lt => thumb_map("lshift", "capslock", "norm", "ret", "lctrl", "tab")
);

my(%nas_key_map) = (
    #                 d    n    e    s    w
    r1 => finger_map("7", "&", undef, "+", "6"),
    r2 => finger_map("8", "*", undef, undef, "^"),
    r3 => finger_map("9", "[", "menu", undef, undef),
    r4 => finger_map("0", "]", undef, undef, "}"),
    #                d      dd         u       in    lo      uo
    rt => thumb_map("nas", "naslock", "func", "sp", "lalt", "bksp"),

    #                 d    n    e    s    w
    l1 => finger_map("4", "\$", "5", "-", undef),
    l2 => finger_map("3", "#", undef, "%", undef),
    l3 => finger_map("2", "@", undef, undef, "esc"),
    l4 => finger_map("1", "!", "{", "=", "del"),
    #                d         dd          u       in     lo       uo
    lt => thumb_map("lshift", "capslock", "norm", "ret", "lctrl", "tab")
);

my(%func_key_map) = (
    #                 d    n    e    s    w
    r1 => finger_map("home", "up", "right", "down", "left"),
    r2 => finger_map(undef, "f8", undef, "f7", "end"),
    r3 => finger_map("printscreen", "f10", "lgui", "f9", "ins"),
    r4 => finger_map("pause", "pgup", "f12", "pgdn", "f11"),
    #                d      dd         u       in    lo      uo
    rt => thumb_map("nas", "naslock", "func", "sp", "lalt", "bksp"),

    #                 d    n    e    s    w
    l1 => finger_map("home", "up", "right", "down", "left"),
    l2 => finger_map(undef, "f6", undef, "f5", undef),
    l3 => finger_map(undef, "f4", "numlock", "f3", "esc"),
    l4 => finger_map(undef, "f2", "scrolllock", "f1", "del"),
    #                d         dd          u       in     lo       uo
    lt => thumb_map("lshift", "capslock", "norm", "ret", "lctrl", "tab")
);

my(%key_maps) = (
    "normal" => \%normal_key_map,
    "normal_hold" => \%normal_hold_key_map,
    "nas" => \%nas_key_map,
    "func" => \%func_key_map
);

sub press_table_label {
    my($name) = shift;
    return "press_table_$name";
}

#maps an action name to a sub that can generate the press and release code for that action
my(%action_map);
#generate actions for a-z and A-Z
for (my($i)=ord("a"); $i<=ord("z"); $i++) {
    $action_map{chr($i)} = simple_keycode($i - ord("a") + 0x04);
    $action_map{uc(chr($i))} = modified_keycode($i - ord("a") + 0x04, LSHIFT_OFFSET);
}
#generate actions for 1-9
for (my($i)=ord("1"); $i<=ord("9"); $i++) {
    $action_map{chr($i)} = simple_keycode($i - ord("1") + 0x1e);
}
#0 comes before 1 in ascii, but after 9 in usb's keycodes
$action_map{"0"} = simple_keycode(0x27);

$action_map{"!"} = modified_keycode(0x1e, LSHIFT_OFFSET);
$action_map{"@"} = modified_keycode(0x1f, LSHIFT_OFFSET);
$action_map{"#"} = modified_keycode(0x20, LSHIFT_OFFSET);
$action_map{"\$"} = modified_keycode(0x21, LSHIFT_OFFSET);
$action_map{"%"} = modified_keycode(0x22, LSHIFT_OFFSET);
$action_map{"^"} = modified_keycode(0x23, LSHIFT_OFFSET);
$action_map{"&"} = modified_keycode(0x24, LSHIFT_OFFSET);
$action_map{"*"} = modified_keycode(0x25, LSHIFT_OFFSET);
$action_map{"("} = modified_keycode(0x26, LSHIFT_OFFSET);
$action_map{")"} = modified_keycode(0x27, LSHIFT_OFFSET);

$action_map{"ret"} = simple_keycode(0x28);
$action_map{"esc"} = simple_keycode(0x29);
$action_map{"bksp"} = simple_keycode(0x2a);
$action_map{"tab"} = simple_keycode(0x2b);
$action_map{"sp"} = simple_keycode(0x2c);

$action_map{"-"} = simple_keycode(0x2d);
$action_map{"_"} = modified_keycode(0x2d, LSHIFT_OFFSET);
$action_map{"="} = simple_keycode(0x2e);
$action_map{"+"} = modified_keycode(0x2e, LSHIFT_OFFSET);
$action_map{"["} = simple_keycode(0x2f);
$action_map{"{"} = modified_keycode(0x2f, LSHIFT_OFFSET);
$action_map{"]"} = simple_keycode(0x30);
$action_map{"}"} = modified_keycode(0x30, LSHIFT_OFFSET);
$action_map{"\\"} = simple_keycode(0x31);
$action_map{"|"} = modified_keycode(0x31, LSHIFT_OFFSET);
$action_map{";"} = simple_keycode(0x33);
$action_map{":"} = modified_keycode(0x33, LSHIFT_OFFSET);
$action_map{"'"} = simple_keycode(0x34);
$action_map{"\""} = modified_keycode(0x34, LSHIFT_OFFSET);
$action_map{"`"} = simple_keycode(0x35);
$action_map{"~"} = modified_keycode(0x35, LSHIFT_OFFSET);
$action_map{","} = simple_keycode(0x36);
$action_map{"<"} = modified_keycode(0x36, LSHIFT_OFFSET);
$action_map{"."} = simple_keycode(0x37);
$action_map{">"} = modified_keycode(0x37, LSHIFT_OFFSET);
$action_map{"/"} = simple_keycode(0x38);
$action_map{"?"} = modified_keycode(0x38, LSHIFT_OFFSET);

$action_map{"capslock"} = simple_keycode(0x39);

#generate actions for f1-f12
for(my($i)=1; $i<=12; $i++) {
    $action_map{"f$i"} = simple_keycode(0x3A + $i - 1);
}

$action_map{"printscreen"} = simple_keycode(0x46);
$action_map{"scrolllock"} = simple_keycode(0x47);
$action_map{"pause"} = simple_keycode(0x48);
$action_map{"ins"} = simple_keycode(0x49);
$action_map{"home"} = simple_keycode(0x4a);
$action_map{"pgup"} = simple_keycode(0x4b);
$action_map{"del"} = simple_keycode(0x4c);
$action_map{"end"} = simple_keycode(0x4d);
$action_map{"pgdn"} = simple_keycode(0x4e);
$action_map{"right"} = simple_keycode(0x4f);
$action_map{"left"} = simple_keycode(0x50);
$action_map{"down"} = simple_keycode(0x51);
$action_map{"up"} = simple_keycode(0x52);
$action_map{"numlock"} = simple_keycode(0x53);
$action_map{"menu"} = simple_keycode(0x65);

$action_map{"ctrlx"} = modified_keycode(0x1b, LCTRL_OFFSET);
$action_map{"ctrlc"} = modified_keycode(0x06, LCTRL_OFFSET);
$action_map{"ctrlv"} = modified_keycode(0x19, LCTRL_OFFSET);

$action_map{"lctrl"} = modifier_keycode(0xe0);
$action_map{"lshift"} = modifier_keycode(0xe1);
$action_map{"lalt"} = modifier_keycode(0xe2);
$action_map{"lgui"} = modifier_keycode(0xe3);
$action_map{"rctrl"} = modifier_keycode(0xe4);
$action_map{"rshift"} = modifier_keycode(0xe5);
$action_map{"ralt"} = modifier_keycode(0xe6);
$action_map{"rgui"} = modifier_keycode(0xe7);

$action_map{"nas"} = temporary_mode_action("nas");
$action_map{"naslock"} = persistent_mode_action("nas");
$action_map{"func"} = persistent_mode_action("func");
$action_map{"norm"} = temporary_mode_action("normal_hold", "normal");

foreach my $key_map_name (keys(%key_maps)) {
    my($key_map) = $key_maps{$key_map_name};

    #iterate over each physical button, and lookup and emit the code for the
    #press and release actions for each
    my(@press_actions);
    my(@release_actions);
    for (my($i)=0; $i<0x34; $i++) {
        #get the finger+direction combination for this button index
        my($index_map_item) = $index_map[$i];

        my($finger_name) = $index_map_item->[0];
        my($finger_dir) = $index_map_item->[1];

        #get the direction map for a specific finger
        my($finger_map) = $key_map->{$finger_name};

        die "couldn't find map for finger $finger_name" unless (defined($finger_map));

        #get the name of the action associated with this particular button
        my($action_name) = $finger_map->{$finger_dir};
        if (!defined($action_name)) {
            my($labels) = &{undefined_action()}($i);
            push @press_actions, $labels->[BUTTON_PRESS];
            push @release_actions, $labels->[BUTTON_RELEASE];
            next;
        }

        #now look up the action
        my($action) = $action_map{$action_name};
        if (!defined($action)) {
            die "invalid action - $action_name";
        }

        #this will emit the code for the press and release action
        #and then we save the names in the two arrays, so we can emit a jump table afterwards
        my($actions) = &$action($i);
        push @press_actions, $actions->[BUTTON_PRESS];
        push @release_actions, $actions->[BUTTON_RELEASE];
    }

    #now emit the jump table for press actions
    emit_sub press_table_label($key_map_name), sub {
        for (my($i)=0; $i<0x34; $i++) {
            my($action_label) = $press_actions[$i];
            if (defined($action_label)) {
                emit ".word pm($action_label)\n";
            } else {
                emit ".word pm(no_action)\n";
            }
        }
    };
}

emit_sub "no_action", sub {
    _ret;
};

#handle the press of a simple (non-shifted) key
#r16 should contain the keycode to send
emit_sub "handle_simple_press", sub {
    #first, we need to check if a purely virtual modifier key is being pressed
    #if so, we need to release the virtual modifier before sending the keycode
    block {
        #grab the modifier byte from the hid report
        _lds r17, "current_report + 20";

        #and also grab the physical status
        _lds r18, modifier_physical_status;

        #check if there are any bits that are 1 in the hid report, but 0 in the physical status
        _com r18;
        _and r18, r17;

        #if not, we don't need to clear any virtual keys, and can proceed to send the actual key press
        _breq end_label;

        #otherwise, we need to clear the virtual modifiers and send a report
        _com r18;
        _and r17, r18;
        _sts "current_report + 20", r17;
        _call "send_hid_report";
    };
    _rjmp "send_keycode_press";
};

#handle the release of a simple (non-shifted) key
#r16 should contain the keycode to release
emit_sub "handle_simple_release", sub {
    _rjmp "send_keycode_release";
};

#adds a keycode to the hid report and sends it
#r16 should contain the keycode to send
emit_sub "send_keycode_press", sub {
    #find the first 0 in current_report, and store the new keycode there
    _ldi zl, lo8(current_report);
    _ldi zh, hi8(current_report);

    _mov r24, zl;
    _adiw r24, 0x20;

    #TODO: we need to handle duplicate keys. e.g. if two buttons are pressed
    #and one is a shifted variant of the other

    block {
        _ld r17, "z+";
        _cp r17, r15_zero;

        block {
            _breq end_label;

            #have we reached the end?
            _cp r24, zl;
            _breq end_label parent;

            _rjmp begin_label parent;
        };

        _st "-z", r16;

        _rjmp "send_hid_report";
    };
    #couldn't find an available slot in the hid report - just return
    #TODO: should report ErrorRollOver in all fields
    _ret;
};

#sends a simple, non-modified key release
#r16 should contain the keycode to release
emit_sub "send_keycode_release", sub {
    #find the keycode in current_report, and zero it out
    _ldi zl, lo8(current_report);
    _ldi zh, hi8(current_report);

    _mov r24, zl;
    _adiw r24, 0x20;

    block {
        _ld r17, "z+";
        _cp r16, r17;

        block {
            _breq end_label;

            #have we reached the end?
            _cp r24, zl;
            _breq end_label parent;

            _rjmp begin_label parent;
        };

        _st "-z", r15_zero;
        _rjmp "send_hid_report";
    };
    #huh? couldn't find the keycode in the hid report. just return
    _ret;
};

#handle a modifier key press
#r16 should contain a mask that specifies which modifier should be sent
#the mask should use the same bit ordering as the modifier byte in the
#hid report
emit_sub "handle_modifier_press", sub {
    #first, check if the modifier key is already pressed
    block {
        #grab the modifier byte from the hid report and check if the modifier is already pressed
        _lds r17, "current_report + 20";
        _mov r18, r17;
        _and r17, r16;
        _brne end_label;

        #set the modifier bit and store it
        _or r18, r16;
        _sts "current_report + 20", r18;

        _rjmp "send_hid_report";
    };
    _ret;
};

#handle a modifier key release
#r16 should contain a mask that specifies which modifier should be sent
#the mask should use the same bit ordering as the modifier byte in the
#hid report
emit_sub "handle_modifier_release", sub {
    #clear the modifier bit and store it
    _lds r17, "current_report + 20";
    _com r16;
    _and r17, r16;
    _sts "current_report + 20", r17;

    _rjmp "send_hid_report";
};

#sends current_report as an hid report
emit_sub "send_hid_report", sub {
    #now, we need to send the hid report
    SELECT_EP r17, EP_1;

    block {
        _lds r17, UEINTX;
        _sbrs r17, RWAL;
        _rjmp begin_label;
    };

    _ldi zl, lo8(current_report);
    _ldi zh, hi8(current_report);

    _ldi r17, 21;

    block {
        _ld r18, "z+";
        _sts UEDATX, r18;
        _dec r17;
        _brne begin_label;
    };

    _lds r17, UEINTX;
    _cbr r17, MASK(FIFOCON);
    _sts UEINTX, r17;
    _ret;
};

#stores the address for the release routine
sub store_release_pointer {
    my($button_index) = shift;
    my($release_label) = shift;

    _ldi r16, lo8(pm($release_label));
    _sts "release_table + " . ($button_index * 2), r16;
    _ldi r16, hi8(pm($release_label));
    _sts "release_table + " . (($button_index * 2) + 1), r16;
}


my($action_count);
BEGIN {
     $action_count = 0;
}
sub simple_keycode {
    my($keycode) = shift;

    return sub {
        my($button_index) = shift;

        my($press_label) = "simple_press_action_$action_count";
        my($release_label) = "simple_release_action_$action_count";
        $action_count++;

        emit_sub $press_label, sub {
            store_release_pointer($button_index, $release_label);

            _ldi r16, $keycode;
            _jmp "handle_simple_press";
        };

        emit_sub $release_label, sub {
            _ldi r16, $keycode;
            _jmp "handle_simple_release";
        };

        return [$release_label, $press_label];
    }
}

sub modified_keycode {
    my($keycode) = shift;
    my($modifier_offset) = shift;

    return sub {
        my($button_index) = shift;

        my($press_label) = "modified_press_action_$action_count";
        my($release_label) = "modified_release_action_$action_count";
        $action_count++;

        emit_sub $press_label, sub {
            #store the address for the release routine
            store_release_pointer($button_index, $release_label);

            _ldi r16, $keycode;

            #TODO: the following logic should be factored out into separate methods - one for each modifier

            #increment the virtual press counter for this modifier
            _lds r17, "modifier_virtual_count + $modifier_offset";
            _inc r17;
            _sts "modifier_virtual_count + $modifier_offset", r17;

            block {
                #we need to send the modifier key only if it's not already pressed

                #grab the modifier byte from the hid report and check if it is pressed
                _lds r17, "current_report + 20";
                _sbrc r17, $modifier_offset;
                _rjmp end_label;

                #set the modifier bit in the hid report
                _sbr r17, MASK($modifier_offset);
                _sts "current_report + 20", r17;
                _call "send_hid_report";
            };

            _jmp "send_keycode_press";
        };

        emit_sub $release_label, sub {
            _ldi r16, $keycode;

            _call "send_keycode_release";

            #decrement the virtual count for the modifier key
            _lds r17, "modifier_virtual_count + $modifier_offset";
            _dec r17;
            _sts "modifier_virtual_count + $modifier_offset", r17;

            block {
                #we need to release the key when (all of):
                #1. The modifier virtual count is 0 (after decrementing for this release)
                #2. The physical status for the modifier is 0
                #3. The modifier in the hid report is shown as being pressed

                #check if the modifier virtual count is 0 (after decrement)
                _cpi r17, 0;
                _brne end_label;

                #check the physical flag
                _lds r17, modifier_physical_status;
                _sbrc r17, $modifier_offset;
                _rjmp end_label;

                #check if the modifier is pressed in the hid report
                _lds r17, "current_report + 20";
                _sbrs r17, $modifier_offset;
                _rjmp end_label;

                #clear the modifier bit in the report and send
                _cbr r17, MASK($modifier_offset);
                _sts "current_report + 20", r17;
                _jmp "send_hid_report";
            };

            _ret;
        };

        return [$release_label, $press_label];
    }
}

sub modifier_keycode {
    my($keycode) = shift;
    my($modifier_offset) = $keycode - 0xe0;

    return sub {
        my($button_index) = shift;

        my($press_label) = "modifier_press_action_$action_count";
        my($release_label) = "modifier_release_action_$action_count";
        $action_count++;

        emit_sub $press_label, sub {
            store_release_pointer($button_index, $release_label);

            #set the bit in the modifier_physical_status byte
            _lds r16, modifier_physical_status;
            _sbr r16, MASK($modifier_offset);
            _sts modifier_physical_status, r16;

            _ldi r16, MASK($modifier_offset);
            _jmp "handle_modifier_press";
        };

        emit_sub $release_label, sub {
            block {
                #clear the bit in the modifier_physical_status byte
                _lds r16, modifier_physical_status;
                _cbr r16, MASK($modifier_offset);
                _sts modifier_physical_status, r16;

                #don't release the modifier if it's virtual count is still > 0
                _lds r16, "modifier_virtual_count + $modifier_offset";
                _cpi r16, 0;
                _breq end_label;

                _ret;
            };

            _ldi r16, MASK($modifier_offset);
            _jmp "handle_modifier_release";
        };

        return [$release_label, $press_label];
    }
}

sub temporary_mode_action {
    #this is the temporary mode that will be in effect only while this key is pressed
    my($mode) = shift;

    #we can optionally change the persistent mode - that is, the mode that will become
    #active once the key for the temporary mode is released
    my($persistent_mode) = shift;

    return sub {
        my($button_index) = shift;

        my($press_label) = "temporary_mode_press_action_$action_count";
        my($release_label) = "temporary_mode_release_action_$action_count";
        $action_count++;

        emit_sub $press_label, sub {
            store_release_pointer($button_index, $release_label);

            if ($persistent_mode) {
                #update the persistent mode press table pointer for the nas press table
                _ldi r16, lo8(press_table_label($persistent_mode));
                _sts persistent_mode_press_table, r16;
                _ldi r16, hi8(press_table_label($persistent_mode));
                _sts "persistent_mode_press_table + 1", r16;
            }

            #update the press table pointer for the nas press table
            _ldi r16, lo8(press_table_label($mode));
            _sts current_press_table, r16;
            _ldi r16, hi8(press_table_label($mode));
            _sts "current_press_table + 1", r16;

            _ret;
        };

        emit_sub $release_label, sub {
            block {
                #make sure that we're still in the same temporary mode. If the mode is different
                #than what we expect, don't change modes. For example, if the user presses and holds
                #the nas button, and then presses and hold a different temporary mode button, and
                #then releases the nas button, we don't want to switch back to the persistent mode
                #while the other temporary mode button is being held
                _lds r16, current_press_table;
                _cpi r16, lo8(press_table_label($mode));
                _brne end_label;

                _lds r16, "current_press_table + 1";
                _cpi r16, hi8(press_table_label($mode));
                _brne end_label;

                #restore the press table pointer from persistent_mode_press_table
                _lds r16, persistent_mode_press_table;
                _sts current_press_table, r16;
                _lds r16, "persistent_mode_press_table + 1";
                _sts "current_press_table + 1", r16;
            };
            _ret;
        };

        return [$release_label, $press_label];
    };
}

sub persistent_mode_action {
    #this is the persistent mode to switch to
    my($mode) = shift;

    return sub {
        my($button_index) = shift;

        my($press_label) = "persistent_mode_press_action_$action_count";
        my($release_label) = "persistent_mode_release_action_$action_count";
        $action_count++;

        emit_sub $press_label, sub {
            store_release_pointer($button_index, $release_label);

            #update the press table pointers to point to the nas press table
            _ldi r16, lo8(press_table_label($mode));
            _sts current_press_table, r16;
            _sts persistent_mode_press_table, r16;
            _ldi r16, hi8(press_table_label($mode));
            _sts "current_press_table + 1", r16;
            _sts "persistent_mode_press_table + 1", r16;

            _ret;
        };

        emit_sub $release_label, sub {
            _ret;
        };

        return [$release_label, $press_label];
    }
}

sub undefined_action {
    return sub {
        my($button_index) = shift;

        my($press_label) = "undefined_press_action_$action_count";
        my($release_label) = "undefined_release_action_$action_count";
        $action_count++;

        emit_sub $press_label, sub {
            store_release_pointer($button_index, $release_label);
            _ret;
        };

        emit_sub $release_label, sub {
            _ret;
        };

        return [$release_label, $press_label];
    }
}
