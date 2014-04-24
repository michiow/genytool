#!/usr/bin/env perl

# genytool.pl
#
# Usage: perl genytool.pl <virtual device name>
#
# Checks for running virtual devices and starts the named device if it is not already running.

use strict;

my $GENYSHELL = '/Applications/Genymotion\ Shell.app/Contents/MacOS/genyshell';
my $GENYPLAYER = '/Applications/Genymotion.app/Contents/MacOS/player';

my ($device_name) =  @ARGV;

die 'You must specify a device name' unless $device_name;

# get_devices()
#   Get a list of the available virtual devices, with the id, status and
#   name of each device.
sub get_devices {
    my @devices;

    for my $line (`$GENYSHELL -c "devices list"`) {
        my ($id, $select, $status, $type, $addr, $name) = map { s/^\s*|\s*$//g; $_ } split /\|/, $line;

        next unless $id =~ /^\d+$/ && $name;
        
        push @devices, { id => $id, select => $select, status => $status, name => $name };
    }

    return @devices;
}

# ping_device($timeout)
#   $timeout - time in seconds before giving up
#   Returns the name of the device that responded, or undef if none responded.
sub ping_device {
    my $timeout = shift;

    do {
        for my $line (`$GENYSHELL -c "devices ping"`) {
            chomp $line;
            if ($line =~ /Genymotion virtual device selected: (.*)$/) {
                return $1;
            }
            sleep $timeout if $timeout;
        }
    } while $timeout--;

    return undef;
}
       
    
my @devices = get_devices;

# check that a different device isn't running
for my $device (@devices) {
    if ($device->{status} eq 'On') {
        die "Other devices are already running. They must be stopped first."
            unless $device->{name} eq $device_name;
    }
}

# find the device and start it if it isn't already running
for my $device (@devices) {
    if ($device->{name} eq $device_name) {
        print "Found Genymotion device $device->{name}\n";

        # if the device is not already running, then start a new instance
        if ($device->{status} eq 'On') {
            print "Device '$device->{name}' is already running\n";

        } else {
            if (fork() == 0) {
                exec ($GENYPLAYER, '--vm-name', $device->{name});
                die "Could not start device '$device->{name}'\n";
            }
            # wait a few sec for the device to really start
            sleep 20;
        }
        
        print "Trying to contact device...\n";

        my $ping = ping_device($device_name, 10);

        die "No response from device" unless $ping;
        die "The wrong device responded" unless $ping eq $device_name;

        print "Received response from device '$ping'\n";

        exit 0;
    }
}

die "Could not find device '$device_name', please check your Genymotion devices.";
