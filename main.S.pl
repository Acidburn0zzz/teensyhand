#!/usr/bin/perl
use strict;

BEGIN {
    do "AVR.pm";
    die $@ if ($@);
}

BEGIN {
    #done in begin section, so that declared constants can be accessed further down
    memory_variable "current_configuration";
    memory_variable "hid_idle_period";
    emit ".text\n";
}

do "descriptors.pm";
die $@ if ($@);

do "usb.pm";
die $@ if ($@);

do "timer.pm";
die $@ if ($@);

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

    usb_init();

    #timer1_init();

    #enable interrupts
    _sei;

    block {
        _rjmp begin_label;
    };
}