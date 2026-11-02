#!/usr/bin/env perl
# Emit GitHub workflow command annotations for FAIL and WARN rows of results.tsv.
# usage: annotate.pl <results.tsv> [label]
use strict;
use warnings;

my ($tsv, $label) = @ARGV;
die "usage: $0 <results.tsv> [label]\n" unless defined $tsv;
exit 0 unless -f $tsv;

sub esc_data { my $s = shift; $s =~ s/%/%25/g; $s =~ s/\r/%0D/g; $s =~ s/\n/%0A/g; $s }
sub esc_prop { my $s = esc_data(shift); $s =~ s/:/%3A/g; $s =~ s/,/%2C/g; $s }

open my $fh, '<', $tsv or die "cannot read $tsv: $!\n";
<$fh>;
my %count = (FAIL => 0, WARN => 0);
while (my $line = <$fh>) {
    chomp $line;
    my ($test, $step, $subject, $status, $exit, $log, $detail) = split /\t/, $line, -1;
    next unless defined $status && exists $count{$status};
    $count{$status}++;
    my $level = $status eq 'FAIL' ? 'error' : 'warning';
    my $title = join ' ', grep { defined && length } ($label ? "[$label]" : undef), $test, $step;
    my $msg = "$subject (exit $exit)";
    $msg .= ": $detail" if defined $detail && length $detail;
    $msg .= "\nlog: $log" if defined $log && $log ne '-';
    printf "::%s title=%s::%s\n", $level, esc_prop($title), esc_data($msg);
}
printf STDERR "%d failure(s), %d warning(s) annotated\n", $count{FAIL}, $count{WARN};
