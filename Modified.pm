package File::Modified;

#use 5.006; # shouldn't be necessary
use strict;
use warnings;

require Exporter;

use vars qw( @ISA $VERSION );

@ISA = qw(Exporter);
$VERSION = '0.01';

sub new {
  my ($class, %args) = @_;

  my $method = $args{method} || "MD5";
  my $files = $args{files} || [];

  my $self = {
    Defaultmethod => $method,
    Files => {},
  };

  bless $self, $class;

  $self->addfile(@$files);

  return $self;
};

sub add {
  my ($self,$filename,$method) = @_;
  $method ||= $self->{Defaultmethod};

  my $signatureclass = "File::Signature::$method";
  my $s = eval { $signatureclass->new($filename) };
  if (! $@) {
    return $self->{Files}->{$filename} = $s;
  } else {
    return undef;
  };
};

sub addfile {
  my ($self,@files) = @_;

  my @result;

  # We only return something if the caller wants it
  if (defined wantarray) {
    push @result, $self->add($_) for @files;
    return @result;
  } else {
    $self->add($_) for @files;
  };
};

sub update {
  my ($self) = @_;

  $_->initialize() for values %{$self->{Files}};
};

sub changed {
  my ($self) = @_;

  return map {$_->{Filename}} grep {$_->changed()} (values %{$self->{Files}});
};

1;

{
  package File::Signature;

  # This is a case where Python would be nicer. With Python, we could have (paraphrased)
  # class File::Signature;
  #       def initialize(self):
  #           self.hash = self.identificate()
  #           return self
  #       def signature(self):
  #           return MD5(self.filename)
  #       def changed(self):
  #           return self.hash != self.signature()
  # and it would work as expected, (almost) regardless of the structure that is returned
  # by self.signature(). This is some DWIMmery that I sometimes miss in Perl.
  # For now, only string comparisions are allowed.

  sub create {
    my ($class,$filename,$signature) = @_;

    my $self = {
      Filename => $filename,
      Signature => $signature,
    };

    bless $self, $class;
  };

  sub new {
    my ($class,$filename) = @_;

    my $self = $class->create($filename);
    $self->initialize();

    return $self;
  };

  sub initialize {
    my ($self) = @_;
    $self->{Signature} = $self->signature();
    return $self;
  };
  
  sub from_scalar {
    my ($baseclass,$scalar) = @_;
    die "Strange value in from_scalar: $scalar\n" unless $scalar =~ /^([^|]+)\|([^|]+)\|(.+)$/;
    my ($class,$filename,$signature) = ($1,$2,$3);
    return $class->create($filename,$signature);
  };
  
  sub as_scalar {
    my ($self) = @_;
    return ref($self) . "|" . $self->{Filename} . "|" . $self->{Signature};
  };

  sub changed {
    my ($self) = @_;
    my $currsig = $self->signature();

    # FIXME: Deep comparision of the two signatures instead of equality !
    # And what's this about string comparisions anyway ?
    if ((ref $currsig) or (ref $self->{Signature})) {
      die "Implementation error in $self : changed() can't handle references and complex structures (yet) !\n";
      #return $currsig != $self->{Signature};
    } else {
      return $currsig ne $self->{Signature};
    };
  };
};

{
  package File::Signature::mtime;
  use base 'File::Signature';

  sub signature {
    my ($self) = @_;

    my @stat = stat $self->{Filename} or die "Couldn't stat '$self->{Filename}' : $!";

    return $stat[9];
  };
};

{
  package File::Signature::MD5;
  use base 'File::Signature';

  use vars qw( $fallback );

  BEGIN {
    eval "use Digest::MD5";

    if ($@) {
      #print "Falling back on File::Signature::mtime\n";
      $fallback = 1;
    };
  };

  # Fall back on simple mtime check unless MD5 is available :

  sub new {
    my ($class,$filename) = @_;

    if ($fallback) {
      return File::Signature::mtime->new($filename);
    } else {
      return $class->SUPER::new($filename);
    };
  };

  sub signature {
    my ($self) = @_;
    my $result;
    if (-e $self->{Filename} and -r $self->{Filename}) {
      local *F;
      open F, $self->{Filename} or die "Couldn't read from file '$self->{Filename}' : $!";
      $result = Digest::MD5->new()->addfile(*F)->b64digest();
      close F;
    };
    return $result;
  };
};

1;

__END__

=head1 NAME

File::Modified - checks intelligently if files have changed

=head1 SYNOPSIS

  use strict;
  use File::Modified;

  my $d = File::Modified->new(files=>['Import.cfg','Export.cfg']);

  while (1) {
    my (@changes) = $d->changed;

    if (@changes) {
      print "$_ was changed\n" for @changes;
      $d->update();
    };
    sleep 60;
  };

Second example - a script that knows when any of its modules have changed :

  use File::Modified;
  my $files = File::Modified->new(files=>[values %INC, $0]);

  # We want to restart when any module was changed
  exec $0, @ARGV if $files->changed();

=head1 DESCRIPTION

The Modified module is intended as a simple method for programs to detect
whether configuration files (or modules they rely on) have changed. There are
currently two methods of change detection implemented, C<mtime> and C<MD5>.
The C<MD5> method will fall back to use timestamps if the C<Digest::MD5> module
cannot be loaded.

=over 4

=item new %ARGS

Creates a new instance. The C<%ARGS> hash has two possible keys,
C<Method>, which denotes the method used for checking as default,
and C<Files>, which takes an array reference to the filenames to
watch.

=item add filename, method

Adds a new file to watch. C<method> is the method (or rather, the
subclass of C<File::Signature>) to use to determine whether
a file has changed or not. The result is either the C<File::Signature>
subclass or undef if an error occurred.

=item addfile LIST

Adds a list of files to watch. The method used for watching is the
default method as set in the constructor. The result is a list
of C<File::Signature> subclasses.

=item update

Updates all signatures to the current state. All pending changes
are discarded.

=item changed

Returns a list of the filenames whose files did change since
the construction or the last call to C<update> (whichever last
occurred).

=back

=head2 Signatures

The module also creates a new namespace C<File::Signature>, which sometime
will evolve into its own module in its own file. A file signature is most
likely of little interest to you; the only time you might want to access
the signature directly is to store the signature in a file for persistence
and easy comparision whether an index database is current with the actual data.

The interface is settled, there are two methods, C<as_scalar> and C<from_scalar>,
that you use to freeze and thaw the signatures. The implementation of these methods
is very frugal, there are no provisions made against filenames that contain weird 
characters like C<\n> or C<|> (the pipe bar), both will be likely to mess up your
one-line-per-file database. An interesting method could be to URL-encode all filenames,
but I will visit this topic in the next release. Also, complex (that is, non-scalar) 
signatures are handled rather ungraceful at the moment.

=head2 Adding new methods for signatures

Adding a new signature method is as simple as creating a new subclass
of C<File::Signature>. See C<File::Signature::MD5> for a simple
example. There is one point of laziness in the implementation of C<File::Signature>,
the C<check> method can only compare strings instead of arbitrary structures (yes,
there ARE things that are easier in Python than in Perl).

=head2 TODO

* Extract the C<File::Signature> subclasses out into their own file.

* Allow complex structures for the signatures.

* Make the simple persistence solution for the signatures better.

* Document C<File::Signature> or put it down into another namespace.

=head2 EXPORT

None by default.

=head2 COPYRIGHT AND LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

Copyright (C) 2002 Max Maischein

=head1 AUTHOR

Max Maischein, E<lt>corion@cpan.orgE<gt>

=head1 SEE ALSO

L<perl>,L<Digest::MD5>.

=cut