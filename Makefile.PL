use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

# Nice-to-have prerequisites :
foreach (qw(Digest::MD5)) {
  warn "File::Modified likes to have $_, but doesn't require it.\n"
    unless eval "require $_; 1";
};

WriteMakefile(
    'NAME'    => 'File::Modified',
    'VERSION_FROM'  => 'Modified.pm', # finds $VERSION
    'PREREQ_PM'    => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Modified.pm', # retrieve abstract from module
       AUTHOR     => 'Max Maischein <corion@cpan.org>') : ()),
);