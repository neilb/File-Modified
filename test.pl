#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;

#########################

use Test::More;
use File::Modified;

use vars qw($have_file_temp $have_digest @methods);

BEGIN {
  eval "use Digest;";
  $have_digest = ! $@;

  eval "use File::Temp qw( tempfile )";
  $have_file_temp = ! $@;

  # Now set up a list of all methods that will result in isa($method)
  # without falling back to something else ...
  @methods = qw(mtime Checksum);
  push @methods, ("MD2","MD5","SHA1") if $have_digest;

  plan tests => 5+7 * scalar @methods;
};

#########################

# Our script shouldn't have changed its identity :
for my $method (@methods) {
  ok( ! File::Modified->new(method=>$method,files=>[$0])->changed(), "Checking $method identity for our script");
};

# In fact, no module should have changed its identity :
for my $method (@methods) {
  ok( ! File::Modified->new(method=>$method,files=>[values %INC])->changed(), "Checking $method identity for values of %INC");
};

# Let's see that adding returns the right kind and number of things
for my $method (@methods) {
  my $m = File::Modified->new(method=>$method);
  my @sigs = $m->addfile($0);
  is(@sigs, 1, "$method: One file added");
  @sigs = $m->addfile($0,$0,$0,$0,$0,$0);
  is(@sigs, 6, "$method: Six files added");
  isa_ok($sigs[0], "File::Signature::$method", "File::Modified->new(method=>$method)");
};

# Test that a signature can be stored and loaded :
for my $method (@methods) {
  my $m = File::Modified->new(method=>$method);
  my @f = $m->addfile($0);
  my $persistent = $f[0]->as_scalar();
  isa_ok(File::Signature->from_scalar($persistent),ref $f[0],"Loading back $method");
};

# Now test the fallback to checksums whenever Digest:: is not available
SKIP: {
  skip "Digest:: is not installed", 1 unless $have_digest;
  is( $File::Signature::Digest::fallback, undef, "Checksum fallback for MD5 correctly disabled" );
};
SKIP: {
  skip "Digest:: is installed", 2 unless ! $have_digest;
  is( $File::Signature::Digest::fallback, 1, "Checksum fallback for Digest::xx correctly enabled" );
  my $m = File::Modified->new(method=>"MD5");
  my $s = $m->add($0,'MD5');
  isa_ok($s,"File::Signature::Checksum","Digest::xx fallback");
};

SKIP: {
  skip "File::Temp is not installed", (scalar @methods)*2 unless $have_file_temp;

  my %d;

  my ($fh, $filename);
  eval {
    ($fh,$filename) = tempfile();
    close $fh;
    open F, "> $filename" or die "couldn't write to tempfile '$filename'\n";
    print F "foo";
    close F;

    sleep 3;
    
    for my $method (@methods) {
      $d{$method} = File::Modified->new(method=>$method,files=>[$filename]);
    };

    open F, "> $filename" or die "couldn't write to tempfile '$filename'\n";
    print F "bar";
    close F;
  };
  diag $@ if $@;
  for my $method (@methods) {
    ok($d{$method}->changed(), "Detecting changed file via $method");
  };

  # Clean up the tempfile
  if ($filename) {
    unlink($filename) or diag "Couldn't remove tempfile $filename : $!\n";
  };
};

# Now test the handling of nonexisting signature methods :
my $d = File::Modified->new( method => 'DoesNotExist' );
is( $d->add( 'foo' ), undef, "Nonexistent File::Signature:: classes correctly fail");

TODO: {
  local $TODO = "Deep comparision of structures not yet implemented";

  {
    package File::Signature::Complicated;

    sub signature {
      my ($self) = @_;
      my $result = [$self->{Filename}];
      return $result;
    };
  };

  my $d = File::Modified->new(method => 'Complex',files => ['does_not_need_to_exist']);

  ok(! $d->changed);
};