#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use strict;

#########################

use Test::More;
use File::Modified;

use vars qw($have_file_temp $have_digest_md5 @methods);

BEGIN { 
  eval "use Digest::MD5;";
  $have_digest_md5 = ! $@;
  
  eval "use File::Temp qw( tempfile )";
  $have_file_temp = ! $@;
  
  # Now set up a list of all methods that will result in isa($method)
  # without falling back to something else ...
  @methods = qw(mtime);
  push @methods, "MD5" if $have_digest_md5;

  plan tests => 16 + scalar @methods;
};

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

# Our script shouldn't have changed its timestamp
ok( ! File::Modified->new(method=>'mtime',files=>[$0])->changed(), "Checking timestamp identity for our script");
# Our script shouldn't have changed its MD5
ok( ! File::Modified->new(method=>'MD5',files=>[$0])->changed(), "Checking MD5 identity for our script");
# In fact, no module should have changed its timestamp :
ok( ! File::Modified->new(method=>'mtime',files=>[values %INC])->changed(), "Checking timestamp identity for values of %INC");
# and the MD5 as well :
ok( ! File::Modified->new(method=>'MD5',files=>[values %INC])->changed(), "Checking MD5 identity for values of %INC");

# Let's see that adding returns the right kind and number of things
my $m = File::Modified->new(method=>'mtime');
my @sigs = $m->addfile($0);
is(@sigs, 1, "One file added");
@sigs = $m->addfile($0,$0,$0,$0,$0,$0);
is(@sigs, 6, "Six files added");
isa_ok($sigs[0], "File::Signature::mtime", "File::Modified->new");

# Test that a signature can be stored and loaded :
for my $method (@methods) {
  $m = File::Modified->new(method=>$method);
  my @f = $m->addfile($0);
  my $persistent = $f[0]->as_scalar();
  isa_ok(File::Signature->from_scalar($persistent),ref $f[0],"Loading back $method");
};

# Now test the fallback to timestamps whenever MD5 is not available
SKIP: {
  skip "Digest::MD5 is not installed", 2 unless $have_digest_md5;
  is( $File::Signature::MD5::fallback, undef, "Timestamp fallback correctly disabled" );
  my @sigs = $m->add($0,"MD5");
  isa_ok($sigs[0], "File::Signature::MD5", "File::Modified->new");
};
SKIP: {
  skip "Digest::MD5 is installed", 2 unless ! $have_digest_md5;
  is( $File::Signature::MD5::fallback, 1, "Timestamp fallback correctly disabled" );
  my $s = $m->add($0,'MD5');
  isa_ok($s,"File::Signature::mtime","Fallback to mtime works");
};

SKIP: {
  skip "File::Temp is not installed", 2 unless $have_file_temp;

  my $d;

  my ($fh, $filename);
  eval {
    ($fh,$filename) = tempfile();
    close $fh;

    sleep 3;

    $d = File::Modified->new(method=>'mtime',files=>[$filename]);

    open F, "> $filename" or die "couldn't write to tempfile '$filename'\n";
    close F;
  };
  diag $@ if $@;
  ok($d->changed(), "Detecting changed timestamp");

  eval {
    open F, "> $filename" or die "couldn't write to tempfile '$filename'\n";
    print F "foo";
    close F;

    $d = File::Modified->new(method=>'MD5');
    my @sigs = $d->addfile($filename);
    my $expected_class = $have_digest_md5 ? "File::Signature::MD5" : "File::Signature::mtime";
    isa_ok($sigs[0],$expected_class,"Fallback test");

    open F, "> $filename" or die "couldn't write to tempfile '$filename'\n";
    print F "bar";
    close F;
  };
  diag $@ if $@;
  ok($d->changed(), "Detecting changed MD5 or timestamp");

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