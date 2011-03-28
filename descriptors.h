DEVICE_DESCRIPTOR:
/*bLength*/             .byte 0x12
/*bDescriptorType*/     .byte DESC_DEVICE
/*bcdUSB*/              .word 0x0200
/*bDeviceClass*/        .byte 0xFF
/*bDeviceSubClass*/     .byte 0xFF
/*bDeviceProtocol*/     .byte 0xFF
/*bMaxPacketSize*/      .byte 0x40
/*idVendor*/            .word 0xFEED
/*idProduct*/           .word 0xFACE
/*bcdDevice*/           .word 0xF00D
/*iManufacturer*/       .byte 0x01
/*iProduct*/            .byte 0x02
/*iSerialNumber*/       .byte 0x03
/*bNumConfigurations*/  .byte 0x01

CONFIGURATION:
CONFIGURATION_DESCRIPTOR:
/*bLength*/             .byte 0x09
/*bDescriptorType*/     .byte DESC_CONFIGURATION
/*wTotalLength*/        .word END_CONFIGURATION - CONFIGURATION
/*bNumInterfaces*/      .byte 0x00
/*bConfigurationValue*/ .byte 0x01
/*iConfiguration*/      .byte 0x04
/*bmAttributes*/        .byte 0x80
/*bMaxPower*/           .byte 0xFA ;TODO: need to measure current draw
END_CONFIGURATION_DESCRIPTOR:
END_CONFIGURATION:

.macro string_descriptor index, string
    ;calculate the length of the string
    .set length, 0
    .irpc ch, \string
        .set length, length+1
    .endr

    ;output the string descriptor, as 16-bit UNICODE
    STRING_\index:
    .byte (length*2)+2
    .byte DESC_STRING

    .irpc n,\string
        ;ughughugh. using the symbol name n is an ugly ugly hack to
        ;avoid a bogus "warning, unknown escape" warning. \n actually
        ;expands into the current character from the given string, it
        ;is NOT a newline character
        .asciz "\n"
    .endr
    STRING_\index\()_END:

    ;make a note of the length of the string, for use elsewhere
    .set STRING_\index\()_LEN, (length*2)+2
.endm

;Supported Languages
STRING_0:
.byte 0x04
.byte DESC_STRING
.word 0x0409
STRING_0_END:

string_descriptor 1, "JesusFreke"
string_descriptor 2, "DataHand"
string_descriptor 3, "3.14159265358979323846264338327"
string_descriptor 4, "The Configuration of DOOOOOOOOM"

;we have to be aligned, for any code that follows
.align 2
