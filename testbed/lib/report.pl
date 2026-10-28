#!/usr/bin/env perl
# Aggregate <work>/*/status.tsv into <work>/REPORT.md and <work>/results.tsv.
use strict;
use warnings;
use File::Spec;
use File::Find;

my ($work, $repo) = @ARGV;
die "usage: report.pl <work-dir> <repo-dir>\n" unless defined $work && defined $repo;
$work = File::Spec->rel2abs($work);
$repo = File::Spec->rel2abs($repo);

my %meta;
if (open my $m, '<', "$work/meta.env") {
  while (<$m>) { chomp; my ($k, $v) = split /=/, $_, 2; $meta{$k} = $v if defined $k; }
  close $m;
}

my @steps = qw(workspace fragment repos build resolve run);
my @tests;
my %rows;     # test -> [rows]
opendir my $dh, $work or die "cannot read $work: $!\n";
for my $t (sort readdir $dh) {
  next if $t =~ /^\./ || !-f "$work/$t/status.tsv";
  push @tests, $t;
  open my $fh, '<', "$work/$t/status.tsv" or next;
  while (<$fh>) {
    chomp; s/\r$//;
    my @f = split /\t/, $_, 7;
    next unless @f >= 6;
    push @{ $rows{$t} }, { test => $f[0], step => $f[1], subject => $f[2], status => $f[3], exit => $f[4], log => $f[5], detail => $f[6] // '' };
  }
  close $fh;
}
# all-in-one last
@tests = ((grep { $_ ne 'all-in-one' } @tests), (grep { $_ eq 'all-in-one' } @tests));

# repo source lookup for subjects (project dir or project/file.bndrun)
my %source_cache;
sub source_link {
  my ($subject) = @_;
  return undef if $subject eq '-' || $subject =~ /,/;
  return $source_cache{$subject} if exists $source_cache{$subject};
  my $found;
  my $want = $subject =~ m{/} ? $subject : "$subject/bnd.bnd";
  find({ no_chdir => 1, wanted => sub {
    return if defined $found;
    return if $File::Find::name =~ m{/(\.git|testbed)(/|$)};
    if (-f $_ && $File::Find::name =~ m{/\Q$want\E$}) { $found = $File::Find::name; }
  } }, $repo);
  if (defined $found) {
    $found =~ s{/bnd\.bnd$}{} unless $subject =~ m{/};
    $found = File::Spec->abs2rel($found, $work);
    $found =~ s{\\}{/}g;
  }
  return $source_cache{$subject} = $found;
}

sub md_escape { my $s = shift // ''; $s =~ s/\|/\\|/g; $s =~ s/`/'/g; return $s; }
sub anchor { my $s = lc shift; $s =~ s/[^a-z0-9_ -]//g; $s =~ s/ /-/g; return $s; }

sub cell {
  my ($rs) = @_;
  return '' unless $rs && @$rs;
  my %c; $c{ $_->{status} }++ for @$rs;
  my @parts;
  for my $st (qw(FAIL WARN PASS SKIP)) {
    next unless $c{$st};
    push @parts, $c{$st} == @$rs ? $st : "$st($c{$st})";
  }
  return join ' ', @parts;
}

sub overall {
  my ($rs) = @_;
  my %c; $c{ $_->{status} }++ for @$rs;
  return 'FAIL' if $c{FAIL};
  return 'WARN' if $c{WARN};
  return 'PASS';
}

my @out;
push @out, "# Fragment testbed report", "";
push @out, "| | |", "|---|---|";
for my $k (qw(os arch host_platform java bnd_spec bnd_version git_sha started finished run_timeout skip_run)) {
  push @out, sprintf('| %s | `%s` |', $k, $meta{$k} // '') if exists $meta{$k};
}
push @out, "";

my ($nfail, $nwarn) = (0, 0);
push @out, "## Summary", "";
push @out, "| Test | " . join(' | ', @steps) . " | Result |";
push @out, "|---|" . ("---|" x @steps) . "---|";
for my $t (@tests) {
  my $rs = $rows{$t} || [];
  my %by; push @{ $by{ $_->{step} } }, $_ for @$rs;
  my $ov = overall($rs);
  $nfail++ if $ov eq 'FAIL'; $nwarn++ if $ov eq 'WARN';
  my $kept = -d "$work/$t/ws" ? " ([workspace kept]($t/ws))" : "";
  push @out, sprintf('| [%s](#%s) | %s | **%s**%s |', $t, anchor($t), join(' | ', map { cell($by{$_}) } @steps), $ov, $kept);
}
push @out, "", sprintf('%d test(s), %d failed, %d with warnings.', scalar @tests, $nfail, $nwarn), "";

push @out, "## Issues", "";
my $any_issue = 0;
for my $t (@tests) {
  my @iss = grep { $_->{status} eq 'FAIL' || $_->{status} eq 'WARN' } @{ $rows{$t} || [] };
  next unless @iss;
  $any_issue = 1;
  push @out, "### $t", "";
  for my $r (@iss) {
    my @links;
    push @links, "[log]($r->{log})" if $r->{log} ne '-' && -f "$work/$r->{log}";
    if ($r->{subject} ne '-' && -d "$work/$t/ws") {
      my $wsf = $r->{step} eq 'build' ? "$t/ws/$r->{subject}" : "$t/ws/$r->{subject}";
      push @links, "[workspace file]($wsf)" if -e "$work/$wsf";
    }
    my $src = source_link($r->{subject});
    push @links, "[source]($src)" if defined $src;
    push @out, sprintf('- **%s** %s `%s` (exit %s) %s', $r->{status}, $r->{step}, md_escape($r->{subject}), $r->{exit}, join(' ', @links));
    push @out, "  " . md_escape($r->{detail}) if length $r->{detail};
    if ($r->{log} ne '-' && -f "$work/$r->{log}") {
      my @tail = tail_lines("$work/$r->{log}", 30);
      if (@tail) {
        push @out, "", "  <details><summary>last " . scalar(@tail) . " log lines</summary>", "";
        push @out, "  ```text", (map { "  $_" } @tail), "  ```", "", "  </details>", "";
      }
    }
  }
  push @out, "";
}
push @out, "No issues.", "" unless $any_issue;

push @out, "## Details", "";
for my $t (@tests) {
  push @out, "### $t", "";
  push @out, "| Step | Subject | Status | Exit | Log | Detail |", "|---|---|---|---|---|---|";
  for my $r (@{ $rows{$t} || [] }) {
    my $log = ($r->{log} ne '-' && -f "$work/$r->{log}") ? "[log]($r->{log})" : '';
    push @out, sprintf('| %s | `%s` | %s | %s | %s | %s |', $r->{step}, md_escape($r->{subject}), $r->{status}, $r->{exit}, $log, md_escape($r->{detail}));
  }
  push @out, "";
}

open my $o, '>', "$work/REPORT.md" or die "cannot write REPORT.md: $!\n";
print $o map { "$_\n" } @out;
close $o;

open my $r, '>', "$work/results.tsv" or die "cannot write results.tsv: $!\n";
print $r join("\t", qw(test step subject status exit log detail)), "\n";
for my $t (@tests) { print $r join("\t", @{$_}{qw(test step subject status exit log detail)}), "\n" for @{ $rows{$t} || [] }; }
close $r;

sub tail_lines {
  my ($file, $n) = @_;
  open my $fh, '<', $file or return ();
  my @l = <$fh>; close $fh;
  @l = @l[-$n .. -1] if @l > $n;
  chomp @l; s/\r$// for @l;
  return @l;
}
