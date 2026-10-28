#!/usr/bin/env perl
# Parse index.bnd and emit either a TSV of bndtools fragments or a rewritten
# index whose ids point to local zip files.
#
#   index.pl tsv   <index.bnd>
#       slug \t path \t name \t archived(0|1) \t require-slugs(comma)
#   index.pl local <index.bnd> <zip-dir-file-uri>
#       prints -workspace-templates with file:<zip-dir>/<slug>.zip ids
use strict;
use warnings;

my ($mode, $index, $ziproot) = @ARGV;
die "usage: index.pl tsv|local <index.bnd> [zip-dir-uri]\n"
  unless defined $mode && defined $index && ($mode eq 'tsv' || ($mode eq 'local' && defined $ziproot));

my $PREFIX = 'bndtools/workspace-templates/';

open my $fh, '<', $index or die "cannot read $index: $!\n";
my $text = do { local $/; <$fh> };
close $fh;

$text =~ s/\r\n/\n/g;
$text =~ s/^\s*#.*$//mg;
$text =~ s/\\\n//g;                       # join continuations
$text =~ s/^\s*-workspace-templates\s*:?\s*//s or die "no -workspace-templates in $index\n";

# split on commas outside quotes
my @clauses;
my $buf = '';
my $q = 0;
for my $c (split //, $text) {
  if ($c eq '"') { $q = !$q; }
  if ($c eq ',' && !$q) { push @clauses, $buf; $buf = ''; next; }
  $buf .= $c;
}
push @clauses, $buf;

my @entries;
for my $clause (@clauses) {
  $clause =~ s/^\s+|\s+$//g;
  next if $clause eq '';
  my @parts;
  $buf = ''; $q = 0;
  for my $c (split //, $clause) {
    if ($c eq '"') { $q = !$q; }
    if ($c eq ';' && !$q) { push @parts, $buf; $buf = ''; next; }
    $buf .= $c;
  }
  push @parts, $buf;
  my $id = shift @parts;
  $id =~ s/^\s+|\s+$//g;
  my %attrs;
  for my $p (@parts) {
    $p =~ s/^\s+|\s+$//g;
    next if $p eq '';
    my ($k, $v) = $p =~ /^([^=]+?)\s*=\s*(.*)$/s or next;
    $v =~ s/^"(.*)"$/$1/s;
    $attrs{$k} = $v;
  }
  push @entries, { id => $id, attrs => \%attrs };
}

sub slug_of {
  my ($id) = @_;
  $id =~ s/#.*$//;
  $id =~ s{/+$}{};
  return undef unless index($id, $PREFIX) == 0;
  my $path = substr($id, length $PREFIX);
  (my $slug = $path) =~ s{/}{__}g;
  return ($slug, $path);
}

my %slug_by_id;
for my $e (@entries) {
  my ($slug, $path) = slug_of($e->{id});
  next unless defined $slug;
  $e->{slug} = $slug;
  $e->{path} = $path;
  $slug_by_id{$slug} = $e;
}

if ($mode eq 'tsv') {
  for my $e (@entries) {
    next unless defined $e->{slug};
    my $a = $e->{attrs};
    my $archived = (exists $a->{archived} && ($a->{archived} eq '' || $a->{archived} =~ /^(true|on|yes)$/i)) ? 1 : 0;
    my @req;
    for my $r (split /\s*,\s*/, ($a->{require} // '')) {
      next if $r eq '';
      my ($rs) = slug_of($r);
      push @req, defined $rs ? $rs : "EXTERNAL:$r";
    }
    printf "%s\t%s\t%s\t%d\t%s\n", $e->{slug}, $e->{path}, ($a->{name} // $e->{id}), $archived, join(',', @req);
  }
  exit 0;
}

# local index
print "-workspace-templates: \\\n";
my @lines;
for my $e (@entries) {
  next unless defined $e->{slug};
  my $a = $e->{attrs};
  my @req;
  for my $r (split /\s*,\s*/, ($a->{require} // '')) {
    next if $r eq '';
    my ($rs) = slug_of($r);
    die "require '$r' of $e->{id} is not a bndtools/workspace-templates fragment\n" unless defined $rs;
    push @req, "$ziproot/$rs.zip";
  }
  my $line = sprintf('    %s/%s.zip; name="testbed:%s"', $ziproot, $e->{slug}, $e->{slug});
  $line .= sprintf('; require="%s"', join(',', @req)) if @req;
  $line .= '; archived=true' if exists $a->{archived} && ($a->{archived} eq '' || $a->{archived} =~ /^(true|on|yes)$/i);
  push @lines, $line;
}
print join(", \\\n", @lines), "\n";
