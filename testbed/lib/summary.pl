#!/usr/bin/env perl
use strict;
use warnings;

my ($root, $workflow_result, $repository, $run_id) = @ARGV;
die "usage: summary.pl <reports-dir> <workflow-result> <repository> <run-id>\n"
  unless defined $run_id;

my (@jobs, %fragment_results);
my ($total_tests, $total_failed, $total_warnings) = (0, 0, 0);
my ($failed_jobs, $warning_jobs, $missing_reports) = (0, 0, 0);

for my $dir (sort glob("$root/testbed-*")) {
  next unless -d $dir;
  (my $job = $dir) =~ s{^.*/}{};
  $job =~ s/^testbed-//;
  my $file = "$dir/REPORT.md";
  my %entry = (job => $job, bnd => '?', java => '?', tests => 0, failed => 0, warnings => 0);

  if (!-f $file) {
    $entry{result} = 'FAIL (no report)';
    $missing_reports++;
    $failed_jobs++;
    push @jobs, \%entry;
    next;
  }

  my $has_summary = 0;
  open my $fh, '<', $file or die "cannot read $file: $!\n";
  while (my $line = <$fh>) {
    if ($line =~ /^\| bnd_version \| `([^`]*)` \|/) { $entry{bnd} = $1; }
    if ($line =~ /^\| java \| `([^`]*)` \|/) { $entry{java} = $1; }
    if ($line =~ /^(\d+) test\(s\), (\d+) failed, (\d+) with warnings\./) {
      @entry{qw(tests failed warnings)} = ($1, $2, $3);
      $has_summary = 1;
    }
    if ($line =~ /^\| \[([^\]]+)\]\(#[^)]+\).*?\*\*(PASS|WARN|FAIL)\*\*/) {
      my ($fragment, $status) = ($1, $2);
      next if $fragment eq 'all-in-one';
      $fragment_results{$fragment}{$status}++;
      $fragment_results{$fragment}{JOBS}++;
    }
  }
  close $fh;

  if (!$has_summary) {
    $entry{result} = 'FAIL (invalid report)';
    $missing_reports++;
    $failed_jobs++;
    push @jobs, \%entry;
    next;
  }

  $total_tests += $entry{tests};
  $total_failed += $entry{failed};
  $total_warnings += $entry{warnings};
  if ($entry{failed}) {
    $entry{result} = 'FAIL';
    $failed_jobs++;
  } elsif ($entry{warnings}) {
    $entry{result} = 'WARN';
    $warning_jobs++;
  } else {
    $entry{result} = 'PASS';
  }
  push @jobs, \%entry;
}

if (!@jobs) {
  $missing_reports++;
}

my $overall = $workflow_result eq 'cancelled'
  ? 'CANCELLED'
  : $workflow_result eq 'failure' || $total_failed || $missing_reports
    ? 'FAIL'
    : $total_warnings || $warning_jobs
      ? 'WARN'
      : 'PASS';
my $artifact_url = "https://github.com/$repository/actions/runs/$run_id";

print "# Fragment testbed overview\n\n";
print "**Overall: $overall** — ";
print scalar(@jobs), " jobs; $total_tests project/fragment test groups; ";
print "$total_failed failed; $total_warnings with warnings.\n\n";
print "| Job | bnd CLI | Java | Test groups | Failed | Warnings | Result |\n";
print "|---|---|---|---:|---:|---:|---|\n";
for my $job (@jobs) {
  my $name = md($job->{job});
  print "| $name | `$job->{bnd}` | `$job->{java}` | $job->{tests} | ";
  print "$job->{failed} | $job->{warnings} | **$job->{result}** |\n";
}

print "\n## Fragment outcomes across jobs\n\n";
print "| Fragment | Pass | Warn | Fail | Jobs |\n";
print "|---|---:|---:|---:|---:|\n";
for my $fragment (sort keys %fragment_results) {
  my $result = $fragment_results{$fragment};
  print "| ", md($fragment), " | ", ($result->{PASS} // 0), " | ",
    ($result->{WARN} // 0), " | ", ($result->{FAIL} // 0), " | $result->{JOBS} |\n";
}
print "\n";
print "Full per-step reports and logs are available in the [workflow artifacts]($artifact_url).\n";

sub md {
  my ($value) = @_;
  $value //= '';
  $value =~ s/\|/\\|/g;
  $value =~ s/[\r\n]/ /g;
  return $value;
}
