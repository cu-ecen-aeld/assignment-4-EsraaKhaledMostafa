# Makefile for writer utility
# Cross-compilation support

# Use CROSS_COMPILE if set, otherwise use native gcc
ifeq ($(CROSS_COMPILE),)
    CC = /usr/bin/gcc
    LDFLAGS = -B/usr/bin
else
    CC = $(CROSS_COMPILE)gcc
    LDFLAGS =
endif

CFLAGS = -Wall -Werror -O2
TARGET = writer

.PHONY: all clean

all: $(TARGET)

$(TARGET): writer.c
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(TARGET) writer.c

clean:
	rm -f $(TARGET) *.o
