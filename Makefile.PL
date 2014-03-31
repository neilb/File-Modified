use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $mm_ver = $ExtUtils::MakeMaker::VERSION;
if ($mm_ver =~ /_/) {
    $mm_ver = eval $mm_ver;
    die $@ if $@;
}

# Nice-to-have prerequisites :
foreach (qw(Digest Digest::MD5)) {
  warn "File::Modified likes to have $_, but doesn't require it.\n"
    unless eval "require $_; 1";
};

WriteMakefile(
    'NAME'          => 'File::Modified',
    'VERSION_FROM'  => 'lib/File/Modified.pm',

    'PREREQ_PM'    => {},

    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'lib/File/Modified.pm',
       AUTHOR     => 'Max Maischein <corion@cpan.org>') : ()),

    ($mm_ver >= 6.48
        ? (MIN_PERL_VERSION => 5.006)
        : ()
    ),

    ($mm_ver >= 6.31
        ? (LICENSE => 'perl')
        : ()
    ),

);
