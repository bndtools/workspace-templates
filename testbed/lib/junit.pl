#!/usr/bin/env perl
# Summarize JUnit XML reports for GitHub.
# usage: junit.pl <out-dir> <check-name> <TEST-*.xml>...
# stdout: ::error annotations for failed test cases
# <out-dir>/junit-summary.md: job summary markdown
# <out-dir>/junit-check.json: check-run payload (head_sha from $TESTBED_SHA)
use strict;
use warnings;
use JSON::PP;

my ($out, $name, @files) = @ARGV;
die "usage: $0 <out-dir> <check-name> <xml>...\n" unless defined $name;

sub unxml {
    my $s = shift // '';
    $s =~ s/<!\[CDATA\[(.*?)\]\]>/$1/gs;
    $s =~ s/&lt;/</g; $s =~ s/&gt;/>/g; $s =~ s/&quot;/"/g; $s =~ s/&apos;/'/g;
    $s =~ s/&#(\d+);/chr($1)/ge; $s =~ s/&amp;/&/g;
    $s;
}
sub attrs {
    my %a; my $s = shift;
    $a{$1} = unxml($2) while $s =~ /([\w:-]+)="([^"]*)"/g;
    \%a;
}
sub esc_data { my $s = shift; $s =~ s/%/%25/g; $s =~ s/\r/%0D/g; $s =~ s/\n/%0A/g; $s }
sub esc_prop { my $s = esc_data(shift); $s =~ s/:/%3A/g; $s =~ s/,/%2C/g; $s }
sub cell { my $s = shift // ''; $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g; $s =~ s/\|/\\|/g; $s =~ s/\s+/ /g; $s }

my @sources = grep { !m{^testbed/} } split /\n/, `git ls-files '*.java' 2>/dev/null`;

# repository source and line of the deepest frame in the test class
sub locate {
    my ($class, $trace) = @_;
    (my $outer = $class) =~ s/\$.*//;
    (my $rel = $outer) =~ s{\.}{/}g;
    my ($path) = grep { m{(?:^|/)\Q$rel\E\.java$} } @sources;
    return unless $path;
    my $line = 1;
    $line = $1 if $trace =~ /at \Q$outer\E[\w\$.]*\([^:()]+\.java:(\d+)\)/;
    ($path, $line);
}

my (%t, @rows, @fails);
for my $f (@files) {
    open my $fh, '<', $f or next;
    my $xml = do { local $/; <$fh> };
    my ($suite) = $xml =~ /<testsuite\b([^>]*)>/;
    my $sname = $suite ? attrs($suite)->{name} // $f : $f;
    my $group = $f =~ m{([^/\\]+)[/\\]logs[/\\]junit-[^/\\]+[/\\][^/\\]+$} ? $1 : '';
    while ($xml =~ /<testcase\b([^>]*?)(?:\/>|>(.*?)<\/testcase>)/gs) {
        my ($a, $body) = (attrs($1), $2 // '');
        my $status = 'passed';
        my ($msg, $trace) = ('', '');
        if ($body =~ /<(failure|error)\b([^>]*?)(?:\/>|>(.*?)<\/\1>)/s) {
            $status = $1 eq 'error' ? 'error' : 'failed';
            my $fa = attrs($2);
            $msg = $fa->{message} // $fa->{type} // $status;
            $trace = unxml($3);
        } elsif ($body =~ /<skipped\b/) {
            $status = 'skipped';
        }
        $t{$status}++; $t{total}++; $t{time} += $a->{time} // 0;
        my $cls = $a->{classname} // $sname;
        push @rows, [$status, $group, $cls, $a->{name} // '?', $a->{time} // ''];
        next unless $status eq 'failed' || $status eq 'error';
        my ($path, $line) = locate($cls, $trace);
        push @fails, { class => $cls, test => $a->{name} // '?', msg => $msg, trace => $trace, path => $path, line => $line };
    }
}

my $bad = ($t{failed} // 0) + ($t{error} // 0);
my $icon = !$t{total} ? ':grey_question:' : $bad ? ':x:' : ':white_check_mark:';
my $title = sprintf '%d test(s), %d passed, %d failed, %d skipped', $t{total} // 0,
    $t{passed} // 0, $bad, $t{skipped} // 0;

my %mark = (passed => ':white_check_mark:', failed => ':x:', error => ':x:', skipped => ':heavy_minus_sign:');
my $md = "### $icon $name\n\n$title";
$md .= sprintf ' in %.1fs', $t{time} if $t{total};
$md .= "\n\n";
if (@rows) {
    $md .= "| | Group | Test | Class | Time (s) |\n|---|---|---|---|---|\n";
    $md .= sprintf "| %s | %s | %s | `%s` | %s |\n", $mark{$_->[0]}, cell($_->[1]), cell($_->[3]), cell($_->[2]), $_->[4] for @rows;
    $md .= "\n";
}
for my $x (@fails) {
    $md .= "<details><summary>:x: <code>$x->{class}.$x->{test}</code>: " . cell($x->{msg}) . "</summary>\n\n```text\n";
    my @tl = split /\n/, $x->{trace};
    splice @tl, 40 if @tl > 40;
    $md .= join "\n", @tl;
    $md .= "\n```\n\n</details>\n\n";
}

for my $x (@fails) {
    my $loc = $x->{path} ? sprintf('file=%s,line=%d,', esc_prop($x->{path}), $x->{line}) : '';
    printf "::error %stitle=%s::%s\n", $loc, esc_prop("$name: $x->{test}"), esc_data("$x->{msg}\n$x->{trace}");
}

my @ann = map {
    { path => $_->{path}, start_line => $_->{line} + 0, end_line => $_->{line} + 0,
      annotation_level => 'failure', title => "$_->{class}.$_->{test}",
      message => substr("$_->{msg}\n$_->{trace}", 0, 60000) }
} grep { $_->{path} } @fails;
splice @ann, 50 if @ann > 50;

my $check = {
    name => $name,
    head_sha => $ENV{TESTBED_SHA} // '',
    status => 'completed',
    conclusion => !$t{total} ? 'neutral' : $bad ? 'failure' : 'success',
    output => { title => $title, summary => substr($md, 0, 65000), annotations => \@ann },
};

open my $o, '>', "$out/junit-summary.md" or die "cannot write $out/junit-summary.md: $!\n";
print $o $md;
close $o;
open $o, '>', "$out/junit-check.json" or die "cannot write $out/junit-check.json: $!\n";
print $o JSON::PP->new->utf8->canonical->encode($check);
close $o;
print STDERR "$name: $title\n";
