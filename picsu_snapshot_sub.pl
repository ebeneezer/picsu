#!/usr/bin/env perl
use strict;
use warnings;

my $BROKER = $ENV{PICSU_MQTT_HOST} // '';
my $PORT   = $ENV{PICSU_MQTT_PORT} // 1883;
my $TOPIC  = $ENV{PICSU_MQTT_TOPIC} // '';
my $USER   = $ENV{PICSU_MQTT_USERNAME} // '';
my $PASS   = $ENV{PICSU_MQTT_PASSWORD} // '';
my $OUT    = $ENV{PICSU_SNAPSHOT_PATH} // '/dev/shm/picsu/snapshot.jpg';
my $DIR    = $ENV{PICSU_SNAPSHOT_DIR} // '/dev/shm/picsu';

die "PICSU_MQTT_HOST is required\n" unless length $BROKER;
die "PICSU_MQTT_TOPIC is required\n" unless length $TOPIC;

mkdir $DIR unless -d $DIR;

my @CMD = (
    'mosquitto_sub',
    '-h', $BROKER,
    '-p', $PORT,
);

push @CMD, ('-u', $USER) if length $USER;
push @CMD, ('-P', $PASS) if length $PASS;

push @CMD, (
    '-t', $TOPIC,
    '-N',
    '-F', '%l\\0%p',
);

pipe(my $read_fh, my $write_fh) or die "pipe failed: $!\n";
my $pid = fork();
die "fork failed: $!\n" unless defined $pid;

if ($pid == 0) {
    close $read_fh;
    open(STDOUT, '>&', $write_fh) or die "dup stdout failed: $!\n";
    close $write_fh;
    exec @CMD;
    die "exec mosquitto_sub failed: $!\n";
}

close $write_fh;
binmode $read_fh;

my $stopping = 0;
my $stop = sub {
    return if $stopping++;
    kill 'TERM', $pid if $pid > 0;
};
$SIG{INT}  = $stop;
$SIG{TERM} = $stop;
$SIG{HUP}  = $stop;
$SIG{QUIT} = $stop;

my $buffer = '';
my $need;

while (!$stopping) {
    my $n = sysread($read_fh, my $chunk, 65536);
    if (!defined $n) {
        next if $!{EINTR};
        last;
    }
    last if $n == 0;

    $buffer .= $chunk;

    while (1) {
        if (!defined $need) {
            my $nul = index($buffer, "\0");
            last if $nul < 0;
            my $len = substr($buffer, 0, $nul, '');
            substr($buffer, 0, 1, '');
            next unless $len =~ /^\d+$/;
            $need = 0 + $len;
        }

        last if length($buffer) < $need;
        my $payload = substr($buffer, 0, $need, '');
        my $tmp = "$OUT.tmp.$$";

        if (open(my $fh, '>', $tmp)) {
            binmode $fh;
            print {$fh} $payload;
            close $fh;
            rename($tmp, $OUT) or unlink $tmp;
        }

        undef $need;
    }
}

close $read_fh;
kill 'TERM', $pid if $pid > 0;
waitpid($pid, 0);
exit($stopping ? 0 : (($? >> 8) || (($? & 127) ? 1 : 0)));
